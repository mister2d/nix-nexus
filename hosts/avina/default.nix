{
  inputs,
  lib,
  ...
}:
let
  # ── OPERATOR: set all values before deploying ────────────────────────────
  matrixDomain = "matrix.example.com";
  elementDomain = "element.example.com";
  masDomain = "auth.example.com";
  callDomain = "call.example.com";
  coturnRealm = "turn.example.com";

  # Federated Posture:
  # Least-privilege model. Add domains of external homeservers you wish to
  # federate with. Always includes matrixDomain automatically.
  federatedDomains = [
    # "matrix.org"
    # "trusted-partner.com"
  ];
  # ─────────────────────────────────────────────────────────────────────────
in
{
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./hardware-configuration.nix
    ../../profiles/core # Core system policies (ZFS, networking, security)
    ../../modules/services/matrix # Matrix 2.0 communications suite
    ../../modules/services/edge/cloudflared.nix # Secure edge ingress
  ];

  _module.args = {
    inherit
      matrixDomain
      elementDomain
      masDomain
      callDomain
      coturnRealm
      federatedDomains
      ;
  };

  networking = {
    hostName = "avina";
    hostId = "a6b7c8d9";

    # Public Network Exposure Model:
    # Only Coturn and SSH are exposed directly. All HTTP/S traffic enters via Cloudflare Tunnel.
    # This configuration overrides core networking policies to ensure a minimal attack surface.
    firewall = lib.mkForce {
      enable = true;
      trustedInterfaces = [ ];
      allowedTCPPorts = [
        22
        5349
        8404
      ]; # SSH + Coturn (TURNS) + HAProxy stats
      allowedUDPPorts = [
        3478
        5349
      ]; # Coturn (STUN/TURN)
      allowedUDPPortRanges = [
        {
          from = 49000;
          to = 49999;
        }
      ]; # Coturn dynamic relay range
      allowedTCPPortRanges = [
        {
          from = 3478;
          to = 3478;
        }
      ];
    };
  };

  # ZFS Performance Tuning:
  # Optimized for a Matrix workload on a memory-constrained VM (12GB RAM).
  nix-nexus.zfs = {
    arcMax = 2147483648; # 2 GB ARC limit to prevent OOM
    arcMin = 536870912;
    arcSysFree = 3221225472; # Ensure 3GB for system/app overhead
    metaLimitPercent = 75;
    dnodeLimitPercent = 10;
  };

  services = {
    # VPN Policy:
    # Tailscale is disabled in favour of future Headscale integration.
    tailscale.enable = lib.mkForce false;

    # Secure Remote Access:
    # Certificate-based authentication via repository-managed SSH CA.
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = lib.mkForce false;
        KbdInteractiveAuthentication = lib.mkForce false;
        PermitRootLogin = lib.mkForce "prohibit-password";
        TrustedUserCAKeys = toString ../../certs/trusted_ssh_ca.pub;
      };
    };

    # Hypervisor Integration:
    qemuGuest.enable = true;
  };

  systemd.services.tailscale-autoconnect.enable = lib.mkForce false;

  system.stateVersion = "25.11";
}
