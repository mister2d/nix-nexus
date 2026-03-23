#!/usr/bin/env bash
# ==============================================================================
# NixOS Install Script — avina (VM Matrix 2.0 Server)
# ==============================================================================
# Features:
#   - Interactive Vault AppRole bootstrap
#   - Pinned package versions via nix-shell
#   - Automated secret rendering into /run/secrets
#   - Memory-optimized build for 12GB RAM / 4 Cores
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${GREEN}[BOOTSTRAP] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }

cleanup() {
    log "Cleaning up temporary installer files..."
    rm -f /tmp/ct-install.hcl /tmp/*.ctmpl
    unset VAULT_TOKEN
}
trap cleanup EXIT

[[ $EUID -ne 0 ]] && error "Must be run as root."

TARGET_HOSTNAME="$(basename "$(cd "$(dirname "$0")" && pwd)")"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Pin disko and packages from flake.lock / inputs
log "Identifying pinned versions from flake inputs..."
DISKO_REV=$(nix --extra-experimental-features "nix-command flakes" eval --raw --impure \
  --expr "(builtins.fromJSON (builtins.readFile \"$REPO_ROOT/flake.lock\")).nodes.disko.locked.rev")

# --- Interactive Confirmation ---
if zpool list "$TARGET_HOSTNAME" >/dev/null 2>&1; then
    RESUME_MODE=true
    DISKO_MODE="mount"
else
    RESUME_MODE=false
    DISKO_MODE="disko"
fi

echo -e "${BLUE}=== NixOS ${TARGET_HOSTNAME^} Interactive Install ===${NC}"
echo "Hostname:  $TARGET_HOSTNAME"
echo "Repo:      $REPO_ROOT"
echo

if [ "$RESUME_MODE" = true ]; then
    log "Existing ZFS pool detected. Resuming installation..."
    read -rp "Proceed with resume? (type 'yes'): " confirm
else
    echo -e "${RED}DANGER: No active pool found. This will DESTROY all data on /dev/sda.${NC}"
    read -rp "Proceed with FRESH installation? (type 'yes'): " confirm
fi
[[ "$confirm" != "yes" ]] && error "Aborted."

# --- Vault & Secrets Phase ---
echo -e "\n${BLUE}=== Vault Secret Bootstrap ===${NC}"
log "Fetching runtime secrets from Vault to validate configuration."

if [[ -z "${VAULT_ADDR:-}" ]]; then
    read -rp "  Enter Vault Address (e.g. https://vault.example.com): " VAULT_ADDR
fi
export VAULT_ADDR

if [[ -z "${VAULT_TOKEN:-}" ]]; then
    read -rsp "  Enter Vault Token (Administrative): " VAULT_TOKEN; echo
fi
export VAULT_TOKEN

read -rp "  Enter AppRole Role-ID for this host: " ROLE_ID
read -rsp "  Enter AppRole Secret-ID for this host: " SECRET_ID; echo

# --- Partitioning & Mounting (Disko) ---
log "Executing Disko ($DISKO_MODE)..."
nix --extra-experimental-features "nix-command flakes" \
    run "github:nix-community/disko/$DISKO_REV" -- \
    --mode "$DISKO_MODE" \
    "$REPO_ROOT/hosts/$TARGET_HOSTNAME/disko.nix"

# --- Master Key Provisioning ---
log "Provisioning persistent Master Key to /mnt/var/lib/secrets..."
mkdir -p /mnt/var/lib/secrets
echo "$ROLE_ID"   > /mnt/var/lib/secrets/vault-role-id
echo "$SECRET_ID" > /mnt/var/lib/secrets/vault-secret-id
chmod 700 /mnt/var/lib/secrets
chmod 600 /mnt/var/lib/secrets/*

# --- Runtime Secret Rendering (nix shell) ---
log "Rendering runtime secrets into /run/secrets using pinned consul-template..."
mkdir -p /run/secrets /run/certs
chmod 700 /run/secrets

# Paths must match modules/services/matrix/consul-template-secrets.nix
kvPath="kv-v2/letsencrypt/certificates/live/novuscotia.com"
matrixKvPath="kv-v2/infrastructure/matrix/avina"
smtpKvPath="kv-v2/infrastructure/smtp"

cat <<EOF > /tmp/ct-install.hcl
vault { address = "$VAULT_ADDR" }

template { source = "/tmp/haproxy.ctmpl" destination = "/run/certs/haproxy.pem" }
template { source = "/tmp/synapse.ctmpl" destination = "/run/secrets/synapse-secrets.yaml" }
template { source = "/tmp/mas.ctmpl"     destination = "/run/secrets/mas-config.yaml" }
template { source = "/tmp/cf.ctmpl"      destination = "/run/secrets/cloudflared-creds.json" }
template { source = "/tmp/email.ctmpl"   destination = "/run/secrets/synapse-email.yaml" }
template { source = "/tmp/turn.ctmpl"    destination = "/run/secrets/coturn-secret" }
template { source = "/tmp/turnenv.ctmpl" destination = "/run/secrets/coturn-secret-env" }
EOF

echo "{{ with secret \"$kvPath\" }}{{ .Data.data.fullchain }}{{ .Data.data.privkey }}{{ end }}" > /tmp/haproxy.ctmpl
echo "{{ with secret \"$matrixKvPath/synapse\" }}
macaroon_secret_key: \"{{ .Data.data.macaroon_secret_key }}\"
form_secret: \"{{ .Data.data.form_secret }}\"
registration_shared_secret: \"{{ .Data.data.registration_shared_secret }}\"
turn_shared_secret: \"{{ .Data.data.turn_shared_secret }}\"
matrix_authentication_service:
  secret: \"{{ .Data.data.mas_shared_secret }}\"
{{ end }}" > /tmp/synapse.ctmpl

echo "{{ with secret \"$matrixKvPath/mas\" }}
http:
  listeners:
    - name: web
      resources: [discovery, human, oauth, compat, graphql, assets]
      binds: [{ host: \"127.0.0.1\", port: 8181 }]
database:
  host: \"/run/postgresql\"
  database: \"matrix-authentication-service\"
  username: \"matrix-authentication-service\"
secrets:
  encryption: \"{{ .Data.data.encryption_key }}\"
upstream_oauth2:
  providers:
    - id: keycloak
      issuer: \"{{ .Data.data.oidc_issuer }}\"
      client_id: \"{{ .Data.data.oidc_client_id }}\"
      client_secret: \"{{ .Data.data.oidc_client_secret }}\"
matrix:
  kind: synapse
  homeserver: \"{{ .Data.data.matrix_domain }}\"
  secret: \"{{ .Data.data.mas_shared_secret }}\"
  endpoint: \"http://127.0.0.1:8008\"
{{ end }}" > /tmp/mas.ctmpl

echo "{{ with secret \"$matrixKvPath/cloudflared\" }}
{
  \"AccountTag\": \"{{ .Data.data.account_id }}\",
  \"TunnelID\": \"{{ .Data.data.tunnel_id }}\",
  \"TunnelName\": \"avina-tunnel\",
  \"TunnelSecret\": \"{{ .Data.data.tunnel_secret }}\"
}
{{ end }}" > /tmp/cf.ctmpl

echo "{{ with secret \"$smtpKvPath\" }}
email:
  smtp_pass: \"{{ .Data.data.smtp_password }}\"
{{ end }}" > /tmp/email.ctmpl

echo "{{ with secret \"$matrixKvPath/synapse\" }}{{ .Data.data.turn_shared_secret }}{{ end }}" > /tmp/turn.ctmpl
echo "{{ with secret \"$matrixKvPath/synapse\" }}LIVEKIT_TURN_SHARED_SECRET={{ .Data.data.turn_shared_secret }}{{ end }}" > /tmp/turnenv.ctmpl

# Execute consul-template once to render
# Uses the package exposed in the local flake outputs
nix --extra-experimental-features "nix-command flakes" \
    run "$REPO_ROOT#consul-template" -- -config /tmp/ct-install.hcl -once

log "Secrets rendered successfully to /run/secrets."
chmod 600 /run/secrets/*

# Clear token from environment immediately
unset VAULT_TOKEN

# --- Resource Pressure Mitigation (12GB RAM) ---
log "Throttling ZFS ARC to 1GB to preserve RAM for Nix daemon..."
echo 1073741824 > /sys/module/zfs/parameters/zfs_arc_max || true

# --- Step 1: Build system closure into /mnt ---
log "Step 1/3: Building system closure into target store..."
export NIXPKGS_ALLOW_UNFREE=1

BUILD_FLAKE=".#nixosConfigurations.$TARGET_HOSTNAME.config.system.build.toplevel"
for attempt in 1 2 3; do
    log "Step 1/3: Build attempt $attempt/3..."
    if nix \
        --extra-experimental-features "nix-command flakes" \
        build \
        --store /mnt \
        --eval-store auto \
        --impure \
        --max-jobs 2 \
        --option max-substitution-jobs 4 \
        --option require-sigs false \
        "$REPO_ROOT/$BUILD_FLAKE" \
        --out-link /tmp/nixos-toplevel; then
        break
    fi
    [[ $attempt -eq 3 ]] && error "Build failed after 3 attempts."
    log "Retrying build..."
done

# --- Step 2: Bridge the store gap ---
log "Step 2/3: Registering /mnt store paths..."
nix-store --load-db < <(nix-store --store /mnt --dump-db)

# --- Step 3: Install (profile + bootloader) ---
TOPLEVEL=$(readlink /tmp/nixos-toplevel)
echo -e "\n${BLUE}=== Final Confirmation ===${NC}"
echo "Ready to install system profile: $TOPLEVEL"
echo "All secrets provisioned and Master Key stored."
read -rp "Proceed with final unattended install? (type 'yes'): " final_confirm
[[ "$final_confirm" != "yes" ]] && error "Installation aborted before final stage."

log "Step 3/3: Installing bootloader and system profile..."
if ! nixos-install \
    --system "$TOPLEVEL" \
    --no-root-passwd \
    --no-channel-copy \
    --max-jobs 2; then
    error "nixos-install failed."
fi

log "SUCCESS — ${TARGET_HOSTNAME^} is provisioned. Reboot to enter your new system."
