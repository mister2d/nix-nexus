# Helper: returns avina's Matrix deployment domains and Vault address.
# Called by: hosts/avina/default.nix.
{
  matrixDomain = "matrix.novuscotia.com";
  elementDomain = "element.novuscotia.com";
  masDomain = "mas.novuscotia.com";
  rtcDomain = "matrix-rtc.novuscotia.com";
  vaultAddr = "https://vault.service.consul:8200";
  certDomain = "novuscotia.com";
}
