#!/usr/bin/env bash
# Log in to Vault (userpass) over the HTTP API and store the token on tmpfs.
#
# Usage: vault-login [-path=<mount>] [-no-store] [-format=json]
#
# Credentials come from pass (vault/auth/{username,password}). The token is
# written to $VAULT_TOKEN_FILE, default $XDG_RUNTIME_DIR/vault/token, which
# vault-token-helper (via ~/.vault) shares with the vault CLI.

set -euo pipefail

mount=userpass
store=1
format=text

for arg in "$@"; do
    case "$arg" in
        -path=*) mount="${arg#-path=}" ;;
        -no-store) store=0 ;;
        -format=json) format=json ;;
        -format=*) echo "vault-login: only -format=json is supported" >&2; exit 2 ;;
        *) echo "usage: vault-login [-path=<mount>] [-no-store] [-format=json]" >&2; exit 2 ;;
    esac
done

: "${VAULT_ADDR:?VAULT_ADDR is not set}"
for cmd in curl jq pass; do
    command -v "$cmd" >/dev/null || { echo "vault-login: $cmd not found" >&2; exit 1; }
done

if [ "$store" = 1 ]; then
    token_file="${VAULT_TOKEN_FILE:-${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set; refusing to persist the token to disk}/vault/token}"
fi

curl_opts=(-sS --connect-timeout 10 -X POST -H 'Content-Type: application/json' --data @-)
[ -n "${VAULT_NAMESPACE:-}" ] && curl_opts+=(-H "X-Vault-Namespace: $VAULT_NAMESPACE")
[ -n "${VAULT_CACERT:-}" ] && curl_opts+=(--cacert "$VAULT_CACERT")
[ -n "${VAULT_SKIP_VERIFY:-}" ] && curl_opts+=(-k)

user="$(pass vault/auth/username)"
user_enc="$(jq -rn --arg u "$user" '$u | @uri')"
mount_enc="${mount#/}"
mount_enc="${mount_enc%/}"
url="${VAULT_ADDR%/}/v1/auth/${mount_enc}/login/${user_enc}"

# The password travels only through pipes, never argv.
response="$(
    pass vault/auth/password | head -n1 | tr -d '\n' \
        | jq -Rs '{password: .}' \
        | curl "${curl_opts[@]}" -w '\n%{http_code}' "$url"
)"
status="${response##*$'\n'}"
body="${response%$'\n'*}"

if [ "$status" != 200 ]; then
    echo "vault-login: HTTP $status from $url" >&2
    printf '%s' "$body" | jq -r '.errors[]? | "  " + .' >&2 2>/dev/null || true
    exit 1
fi

if [ "$(printf '%s' "$body" | jq -r '.auth.mfa_requirement != null')" = true ]; then
    echo "vault-login: login MFA is enforced; not supported by this script" >&2
    exit 1
fi

token="$(printf '%s' "$body" | jq -r '.auth.client_token // empty')"
if [ -z "$token" ]; then
    echo "vault-login: response contained no client_token" >&2
    exit 1
fi

if [ "$store" = 1 ]; then
    umask 077
    # shellcheck disable=SC2174
    mkdir -p -m 700 "$(dirname "$token_file")"
    tmp="$(mktemp "$token_file.XXXXXX")"
    printf '%s' "$token" >"$tmp"
    mv -f "$tmp" "$token_file"
fi

if [ "$format" = json ]; then
    printf '%s\n' "$body"
else
    printf '%s' "$body" | jq -r '
        .auth | "Success! Logged in as \(.metadata.username // "unknown")",
        "policies:  \(.policies | join(", "))",
        "ttl:       \(.lease_duration)s (renewable: \(.renewable))"'
    [ "$store" = 1 ] && echo "token stored in $token_file"
fi
