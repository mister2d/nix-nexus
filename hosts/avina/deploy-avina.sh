#!/usr/bin/env bash
# ==============================================================================
# Avina Deployment Wrapper (Stage 2)
# ==============================================================================
# This script automates the full Matrix 2.0 deployment after the initial
# bootstrap and reboot. It handles:
#   1. Interactive Vault Seeding (idempotent)
#   2. AppRole Master Key Provisioning
#   3. Final NixOS Rebuild/Switch
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
echo "Repo: $REPO_ROOT"
echo

# --- 1. Vault Authentication ---
if [[ -z "${VAULT_ADDR:-}" ]]; then
    read -rp "  Enter Vault Address (e.g. https://vault.example.com): " VAULT_ADDR
fi
export VAULT_ADDR

if [[ -z "${VAULT_TOKEN:-}" ]]; then
    read -rsp "  Enter Vault Administrative Token: " VAULT_TOKEN; echo
fi
export VAULT_TOKEN

# --- 2. Vault Seeding (Idempotent) ---
POLICY_NAME="avina-policy"
APPROLE_NAME="avina"
KV_BASE="infrastructure/matrix/avina"
LE_CERT_PATH="letsencrypt/certificates/live/novuscotia.com"
SMTP_PATH="infrastructure/smtp"

log "Ensuring Vault AppRole and Policies are configured..."

if ! vault auth list | grep -q "approle/"; then
    vault auth enable approle
fi

vault policy write "$POLICY_NAME" - <<EOF
path "kv-v2/data/$LE_CERT_PATH" { capabilities = ["read"] }
path "kv-v2/data/$SMTP_PATH"    { capabilities = ["read"] }
path "kv-v2/data/$KV_BASE/*"    { capabilities = ["read"] }
path "auth/token/renew-self"    { capabilities = ["update"] }
EOF

vault write "auth/approle/role/$APPROLE_NAME" \
    token_policies="$POLICY_NAME" \
    token_ttl="1h" \
    token_max_ttl="4h"

# Check if secrets already exist before prompting
if vault kv get "kv-v2/$KV_BASE/synapse" &>/dev/null; then
    read -rp "Secrets detected in Vault. Re-seed interactively? (y/N): " reseed
else
    reseed="y"
fi

if [[ "$reseed" =~ ^[Yy]$ ]]; then
    echo -e "\n${BLUE}--- Interactive Secret Seeding ---${NC}"
    read -rp "  Synapse macaroon_secret_key: " MACAROON
    read -rp "  Synapse form_secret: " FORM
    read -rp "  Synapse registration_shared_secret: " REG
    read -rp "  Synapse turn_shared_secret: " TURN
    read -rp "  MAS mas_shared_secret (Internal API): " MAS_SHARED
    read -rp "  MAS encryption_key (64 char hex): " MAS_ENC
    read -rp "  MAS oidc_issuer (e.g. Keycloak URL): " MAS_ISS
    read -rp "  MAS oidc_client_id: " MAS_OIDC_ID
    read -rp "  MAS oidc_client_secret: " MAS_OIDC_SECRET
    read -rp "  Matrix Domain (e.g. matrix.example.com): " MAT_DOM
    read -rp "  Cloudflare account_id: " CF_ACC
    read -rp "  Cloudflare tunnel_id: " CF_TUN
    read -rp "  Cloudflare tunnel_secret: " CF_SEC

    vault kv put "kv-v2/$KV_BASE/synapse" \
        macaroon_secret_key="$MACAROON" form_secret="$FORM" \
        registration_shared_secret="$REG" turn_shared_secret="$TURN" \
        mas_shared_secret="$MAS_SHARED"

    vault kv put "kv-v2/$KV_BASE/mas" \
        encryption_key="$MAS_ENC" oidc_issuer="$MAS_ISS" \
        oidc_client_id="$MAS_OIDC_ID" oidc_client_secret="$MAS_OIDC_SECRET" \
        matrix_domain="$MAT_DOM" mas_shared_secret="$MAS_SHARED"

    vault kv put "kv-v2/$KV_BASE/cloudflared" \
        account_id="$CF_ACC" tunnel_id="$CF_TUN" tunnel_secret="$CF_SEC"
fi

# --- 3. Master Key Provisioning ---
log "Generating fresh AppRole credentials and provisioning /var/lib/secrets..."
mkdir -p /var/lib/secrets
chmod 700 /var/lib/secrets

vault read -field=role_id "auth/approle/role/$APPROLE_NAME/role-id" > /var/lib/secrets/vault-role-id
vault write -f -field=secret_id "auth/approle/role/$APPROLE_NAME/secret-id" > /var/lib/secrets/vault-secret-id

chmod 600 /var/lib/secrets/*
log "Master Key provisioned to persistent storage."

# --- 4. Final Rebuild ---
log "Executing final nixos-rebuild switch to the full Avina flake..."
# Clear admin token from environment before rebuild
unset VAULT_TOKEN

if nixos-rebuild switch --flake "$REPO_ROOT#$TARGET_HOSTNAME"; then
    log "SUCCESS — Avina Matrix 2.0 server is fully deployed."
    log "The system will now bootstrap its own runtime secrets from Vault."
else
    error "nixos-rebuild failed. Check logs above."
fi
