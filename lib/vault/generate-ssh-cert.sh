#!/usr/bin/env bash
# Sign the TPM-backed SSH public key with Vault's ssh-client-signer and load it.
#
# Token: $VAULT_TOKEN, else the tmpfs token written by vault-login
# ($VAULT_TOKEN_FILE, default $XDG_RUNTIME_DIR/vault/token).
set -euo pipefail

SSH_USER=root
ROLE=adminrole
#SSH_USER=groot
#ROLE=userrole
TTL=8h
PUBLIC_KEY_FILE=${HOME}/.ssh/tpm/id_ecdsa_personal.pub
SSH_USER_CERT=${HOME}/.ssh/id_ecdsa-cert.pub
VAULT_ADDR=${VAULT_ADDR:-"https://active.vault.service.consul:8200"}

for cmd in curl jq; do
    command -v "$cmd" >/dev/null || { echo "generate-ssh-cert: $cmd not found" >&2; exit 1; }
done

if [ -z "${VAULT_TOKEN:-}" ]; then
    token_file="${VAULT_TOKEN_FILE:-${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}/vault/token}"
    [ -r "$token_file" ] || { echo "generate-ssh-cert: no Vault token; run vault-login" >&2; exit 1; }
    VAULT_TOKEN="$(cat "$token_file")"
fi

curl_opts=(-sS --connect-timeout 10 -X POST --config -)
[ -n "${VAULT_NAMESPACE:-}" ] && curl_opts+=(-H "X-Vault-Namespace: $VAULT_NAMESPACE")
[ -n "${VAULT_CACERT:-}" ] && curl_opts+=(--cacert "$VAULT_CACERT")
[ -n "${VAULT_SKIP_VERIFY:-}" ] && curl_opts+=(-k)

payload="$(jq -cn --rawfile key "$PUBLIC_KEY_FILE" --arg principals "$SSH_USER" --arg ttl "$TTL" \
    '{public_key: $key, valid_principals: $principals, ttl: $ttl}')"

# The token and request body go through curl's stdin config, never argv.
response="$(
    printf 'header = "X-Vault-Token: %s"\ndata = %s\n' "$VAULT_TOKEN" "$(jq -Rn --arg p "$payload" '$p')" \
        | curl "${curl_opts[@]}" -w '\n%{http_code}' "${VAULT_ADDR%/}/v1/ssh-client-signer/sign/${ROLE}"
)"
status="${response##*$'\n'}"
body="${response%$'\n'*}"

if [ "$status" != 200 ]; then
    echo "generate-ssh-cert: HTTP $status from ssh-client-signer/sign/${ROLE}" >&2
    printf '%s' "$body" | jq -r '.errors[]? | "  " + .' >&2 2>/dev/null || true
    exit 1
fi

cert="$(printf '%s' "$body" | jq -r '.data.signed_key // empty')"
[ -n "$cert" ] || { echo "generate-ssh-cert: response contained no signed_key" >&2; exit 1; }

tmp="$(mktemp "$SSH_USER_CERT.XXXXXX")"
printf '%s' "$cert" >"$tmp"
chmod 644 "$tmp"
mv -f "$tmp" "$SSH_USER_CERT"

echo "Your signed public key: $(head -c 50 "$SSH_USER_CERT") ..."

ssh-add || true
