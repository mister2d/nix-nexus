#!/usr/bin/env bash
# ==============================================================================
# Avina Deployment Wrapper (Stage 2)
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${GREEN}[DEPLOY] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }

[[ $EUID -ne 0 ]] && error "Must be run as root."

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET_HOSTNAME="avina"

# --- Dependency Check ---
for cmd in vault jq nixos-rebuild; do
    if ! command -v "$cmd" &>/dev/null; then
        error "Required command '$cmd' not found in PATH."
    fi
done

echo -e "${BLUE}=== Avina Matrix 2.0 Full Deployment ===${NC}"

# --- 1. Vault Authentication ---
if [[ -z "${VAULT_ADDR:-}" ]]; then
    read -rp "  Enter Vault Address (default: https://vault.service.consul:8200): " VAULT_ADDR
    VAULT_ADDR="${VAULT_ADDR:-https://vault.service.consul:8200}"
fi
export VAULT_ADDR

if [[ -z "${VAULT_TOKEN:-}" ]]; then
    read -rsp "  Enter Vault Administrative Token: " VAULT_TOKEN; echo
fi
export VAULT_TOKEN

# --- 2. Vault Policy & AppRole (Three-Tier Alignment) ---
POLICY_NAME="avina-policy"
APPROLE_NAME="avina"
KV_BASE="infrastructure/matrix/avina"
LE_CERT_PATH="letsencrypt/certificates/live/novuscotia.com"
SMTP_PATH="infrastructure/smtp"

log "Configuring Vault Policy for Three-Tier structure..."

vault policy write "$POLICY_NAME" - <<EOF
path "kv-v2/data/$LE_CERT_PATH" { capabilities = ["read"] }
path "kv-v2/data/$SMTP_PATH"    { capabilities = ["read"] }
path "kv-v2/data/$KV_BASE/*"    { capabilities = ["read"] }
path "auth/token/renew-self"    { capabilities = ["update"] }
EOF

if ! vault auth list | grep -q "approle/"; then
    vault auth enable approle
fi

vault write "auth/approle/role/$APPROLE_NAME" \
    token_policies="$POLICY_NAME" \
    token_ttl="1h" \
    token_max_ttl="4h"

# --- 3. Interactive Seeding (Three-Tier Logic) ---
check_keys() {
    local path=$1
    shift
    local keys=("$@")
    local secret_json
    secret_json=$(vault kv get -format=json "kv-v2/$path" 2>/dev/null) || return 1
    for key in "${keys[@]}"; do
        if [[ $(echo "$secret_json" | jq -r ".data.data.$key") == "null" ]]; then
            return 1
        fi
    done
    return 0
}

reseed="n"
if ! check_keys "$KV_BASE/config" matrix_domain auth_domain || \
   ! check_keys "$KV_BASE/synapse" macaroon_secret_key || \
   ! check_keys "$KV_BASE/mas" encryption_key; then
    log "Missing keys in Three-Tier Vault structure. Forcing re-seed..."
    reseed="y"
else
    read -rp "Three-Tier Vault secrets valid. Re-seed anyway? (y/N): " choice
    [[ "$choice" =~ ^[Yy]$ ]] && reseed="y"
fi

if [[ "$reseed" == "y" ]]; then
    echo -e "\n${BLUE}--- Three-Tier Secret Seeding ---${NC}"
    # Tier 1: Config
    read -rp "  Matrix Domain Namespace (e.g. matrix.novuscotia.com): " MATRIX_DOMAIN
    read -rp "  Auth Portal Domain (e.g. mas.novuscotia.com): " AUTH_DOMAIN
    
    # Tier 2: Synapse
    read -rp "  Synapse macaroon_secret_key: " MACAROON
    read -rp "  Synapse form_secret: " FORM
    read -rp "  Synapse registration_shared_secret: " REG
    read -rp "  Synapse turn_shared_secret: " TURN
    read -rp "  MAS shared_secret (Internal API): " MAS_SHARED
    
    # Tier 3: MAS
    read -rp "  MAS encryption_key (64 char hex): " MAS_ENC
    read -rp "  MAS oidc_issuer (Upstream IDP): " MAS_ISS
    read -rp "  MAS oidc_client_id: " MAS_OIDC_ID
    read -rp "  MAS oidc_client_secret: " MAS_OIDC_SECRET

    vault kv put "kv-v2/$KV_BASE/config" \
        matrix_domain="$MATRIX_DOMAIN" \
        auth_domain="$AUTH_DOMAIN"

    vault kv put "kv-v2/$KV_BASE/synapse" \
        macaroon_secret_key="$MACAROON" \
        form_secret="$FORM" \
        registration_shared_secret="$REG" \
        turn_shared_secret="$TURN" \
        mas_shared_secret="$MAS_SHARED"

    vault kv put "kv-v2/$KV_BASE/mas" \
        encryption_key="$MAS_ENC" \
        oidc_issuer="$MAS_ISS" \
        oidc_client_id="$MAS_OIDC_ID" \
        oidc_client_secret="$MAS_OIDC_SECRET" \
        mas_shared_secret="$MAS_SHARED"
fi

# --- 4. Master Key Provisioning ---
log "Generating fresh AppRole credentials..."
mkdir -p /var/lib/secrets
chmod 700 /var/lib/secrets
vault read -field=role_id "auth/approle/role/$APPROLE_NAME/role-id" > /var/lib/secrets/vault-role-id
vault write -f -field=secret_id "auth/approle/role/$APPROLE_NAME/secret-id" > /var/lib/secrets/vault-secret-id
chmod 600 /var/lib/secrets/*

# --- 5. Final Build & Switch ---
unset VAULT_TOKEN
nixos-rebuild switch --flake "$REPO_ROOT#$TARGET_HOSTNAME" --impure
