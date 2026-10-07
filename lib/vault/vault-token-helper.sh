#!/usr/bin/env bash
# Vault token helper: keep the token on tmpfs ($XDG_RUNTIME_DIR), not in ~/.vault-token.
# Wired up through `token_helper = "<this path>"` in ~/.vault.
# Contract: https://developer.hashicorp.com/vault/docs/commands/token-helper

set -euo pipefail

token_file="${VAULT_TOKEN_FILE:-${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}/vault/token}"

case "${1:-}" in
    get)
        [ -r "$token_file" ] && cat "$token_file"
        exit 0
        ;;
    store)
        umask 077
        # shellcheck disable=SC2174
        mkdir -p -m 700 "$(dirname "$token_file")"
        tmp="$(mktemp "$token_file.XXXXXX")"
        cat >"$tmp"
        mv -f "$tmp" "$token_file"
        ;;
    erase)
        rm -f "$token_file"
        ;;
    *)
        echo "usage: vault-token-helper get|store|erase" >&2
        exit 1
        ;;
esac
