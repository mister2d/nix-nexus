{
  matrixDomain = "matrix.novuscotia.com";
  elementDomain = "element.novuscotia.com";
  masDomain = "mas.novuscotia.com";
  callDomain = "call.novuscotia.com";
  coturnRealm = "turn.novuscotia.com";
  vaultAddr = "https://vault.service.consul:8200";
  # Root domain under which the TLS cert is stored in Vault KV.
  # Must match LE_CERT_PATH in deploy-avina.sh.
  certDomain = "novuscotia.com";
}
