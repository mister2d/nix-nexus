# Read-only policy: avina-matrix AppRole — router external IP
#
# Grants vault-agent on avina read access to the router's WAN IP.
# Used by coturn's preStart to inject `external-ip=<WAN_IP>` into the
# runtime config so TURN relay allocations advertise a reachable address.
#
# Apply to the existing avina-matrix AppRole policy:
#
#   vault policy write avina-matrix-router-read vault/policies/avina-matrix-router-read.hcl
#   vault write auth/approle/role/avina-matrix \
#     token_policies="avina-matrix,avina-matrix-router-read"
#
# KV-v2 secret layout:
#   Path:  kv-v2/infrastructure/router
#   Field: external_ip  (string — the WAN IPv4 address of the router)

path "kv-v2/data/infrastructure/router" {
  capabilities = ["read"]
}
