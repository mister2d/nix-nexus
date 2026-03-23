#!/usr/bin/env bash
# ==============================================================================
# Vault Seeding Script — avina (Matrix 2.0)
# ==============================================================================
# Idempotent helper to:
#   1. Enable AppRole auth method.
#   2. Create/Update the 'avina-policy'.
#   3. Configure the 'avina' AppRole.
#   4. Interactively seed KV-v2 secrets for the Matrix stack.
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${GREEN}[VAULT] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }

[[ -z "${VAULT_ADDR:-}" ]] && error "VAULT_ADDR is not set."
[[ -z "${VAULT_TOKEN:-}" ]] && error "VAULT_TOKEN is not set."

POLICY_NAME="avina-policy"
APPROLE_NAME="avina"
KV_BASE="infrastructure/matrix/avina"
LE_CERT_PATH="letsencrypt/certificates/live/novuscotia.com"
SMTP_PATH="infrastructure/smtp"

# ── 1. Enable AppRole ────────────────────────────────────────────────────────
if ! vault auth list | grep -q "approle/"; then
    log "Enabling AppRole auth method..."
    vault auth enable approle
else
    log "AppRole auth method already enabled."
fi

# ── 2. Create Policy ─────────────────────────────────────────────────────────
log "Creating policy: $POLICY_NAME..."
vault policy write "$POLICY_NAME" - <<EOF
# Read access to SSL/TLS certificates
path "kv-v2/data/$LE_CERT_PATH" {
  capabilities = ["read"]
}

# Read access to existing SMTP credentials
path "kv-v2/data/$SMTP_PATH" {
  capabilities = ["read"]
}

# Full read access to Avina stack secrets
path "kv-v2/data/$KV_BASE/*" {
  capabilities = ["read"]
}

# Allow token renewal (needed by consul-template/vault-agent)
path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF

# ── 3. Configure AppRole ─────────────────────────────────────────────────────
log "Configuring AppRole: $APPROLE_NAME..."
vault write "auth/approle/role/$APPROLE_NAME" \
    token_policies="$POLICY_NAME" \
    token_ttl="1h" \
    token_max_ttl="4h"

# ── 4. Seed Secrets (Interactive) ───────────────────────────────────────────
echo -e "\n${BLUE}=== Interactive Secret Seeding ===${NC}"
echo "This will populate paths under: kv-v2/$KV_BASE/"

# A. Synapse Secrets
echo -e "\n[Synapse & Shared Secrets]"
read -rp "  macaroon_secret_key: " MACAROON
read -rp "  form_secret: " FORM
read -rp "  registration_shared_secret: " REG
read -rp "  turn_shared_secret: " TURN
read -rp "  mas_shared_secret (Internal API): " MAS_SHARED

vault kv put "kv-v2/$KV_BASE/synapse" \
    macaroon_secret_key="$MACAROON" \
    form_secret="$FORM" \
    registration_shared_secret="$REG" \
    turn_shared_secret="$TURN" \
    mas_shared_secret="$MAS_SHARED"

# B. MAS Secrets
echo -e "\n[Matrix Authentication Service]"
read -rp "  encryption_key (64 char hex): " MAS_ENC
read -rp "  oidc_issuer (e.g. Keycloak URL): " MAS_ISS
read -rp "  oidc_client_id: " MAS_OIDC_ID
read -rp "  oidc_client_secret: " MAS_OIDC_SECRET
read -rp "  matrix_domain (e.g. matrix.example.com): " MAT_DOM

vault kv put "kv-v2/$KV_BASE/mas" \
    encryption_key="$MAS_ENC" \
    oidc_issuer="$MAS_ISS" \
    oidc_client_id="$MAS_OIDC_ID" \
    oidc_client_secret="$MAS_OIDC_SECRET" \
    matrix_domain="$MAT_DOM" \
    mas_shared_secret="$MAS_SHARED"

# C. Cloudflared Secrets
echo -e "\n[Cloudflare Tunnel]"
read -rp "  account_id: " CF_ACC
read -rp "  tunnel_id: " CF_TUN
read -rp "  tunnel_secret: " CF_SEC

vault kv put "kv-v2/$KV_BASE/cloudflared" \
    account_id="$CF_ACC" \
    tunnel_id="$CF_TUN" \
    tunnel_secret="$CF_SEC"

log "SUCCESS — Vault is seeded and AppRole '$APPROLE_NAME' is ready."
echo -e "\n${BLUE}Option A: Obtain credentials for automated AppRole installation:${NC}"
echo "Role-ID:   \$(vault read -field=role_id auth/approle/role/$APPROLE_NAME/role-id)"
echo "Secret-ID: \$(vault write -f -field=secret_id auth/approle/role/$APPROLE_NAME/secret-id)"

echo -e "\n${BLUE}Option B: Generate a renewable orphan token (96h period):${NC}"
echo "vault token create -policy=\"$POLICY_NAME\" -orphan -renewable=true -period=\"96h\""
