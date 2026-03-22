{
  coturnRealm,
  ...
}:
{
  services.coturn = {
    enable = true;
    no-cli = true;
    no-tcp-relay = true;
    min-port = 49000;
    max-port = 49999;
    use-auth-secret = true;
    realm = coturnRealm;

    # TLS Configuration:
    # Certificates are provisioned via Vault and rendered to runtime paths
    # by the consul-template module.
    cert = "/run/certs/coturn-fullchain.pem";
    pkey = "/run/certs/coturn.key";

    static-auth-secret-file = "/run/secrets/coturn-secret";

    # Security Policy:
    # Prevent SSRF by explicitly denying access to internal network ranges.
    extraConfig = ''
      no-multicast-peers
      denied-peer-ip=0.0.0.0-0.255.255.255
      denied-peer-ip=10.0.0.0-10.255.255.255
      denied-peer-ip=100.64.0.0-100.127.255.255
      denied-peer-ip=127.0.0.0-127.255.255.255
      denied-peer-ip=169.254.0.0-169.254.255.255
      denied-peer-ip=172.16.0.0-172.31.255.255
      denied-peer-ip=192.168.0.0-192.168.255.255
      denied-peer-ip=::1
      denied-peer-ip=fc00::-fdff:ffff:ffff:ffff:ffff:ffff:ffff:ffff
    '';
  };
}
