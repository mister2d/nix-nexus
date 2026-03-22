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
  # ─────────────────────────────────────────────────────────────────────────
in
{
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./hardware-configuration.nix
    ../../profiles/core # imports ZFS, networking, boot, security, users
    ../../modules/services/matrix # Matrix 2.0 stack aggregator
    ../../modules/services/edge/cloudflared.nix
  ];

  _module.args = {
    inherit
      matrixDomain
      elementDomain
      masDomain
      callDomain
      coturnRealm
      ;
  };

  networking = {
    hostName = "avina";
    hostId = "a6b7c8d9"; # Example, should be generated properly by operator

    # ── Firewall: Coturn + SSH directly exposed ──────────────────────────────
    # modules/core/networking.nix sets trustedInterfaces = ["tailscale0"] and
    # allowedUDPPorts that includes config.services.tailscale.port.
    # Override the entire firewall block to eliminate Tailscale references.
    firewall = lib.mkForce {
      enable = true;
      trustedInterfaces = [ ]; # no VPN interface on this host
      allowedTCPPorts = [
        22
        5349
        8404
      ]; # SSH + Coturn TURNS/TLS + HAProxy stats
      allowedUDPPorts = [
        3478
        5349
      ]; # Coturn STUN/TURN + TURNS
      allowedUDPPortRanges = [
        {
          from = 49000;
          to = 49999;
        } # Coturn relay range
      ];
      allowedTCPPortRanges = [
        {
          from = 3478;
          to = 3478;
        } # Coturn STUN/TURN TCP
      ];
      # LiveKit (7881, 50100-50200) NOT exposed; media relayed through Coturn.
    };
  };

  # ── ZFS: conservative for Matrix-only workload ───────────────────────────
  # profiles/core already imports modules/core/zfs.nix; set options here.
  nix-nexus.zfs = {
    arcMax = 2147483648; # 2 GB — scale up if RAM ≥ 16 GB
    arcMin = 536870912; # 512 MB
    arcSysFree = 3221225472; # 3 GB headroom for PostgreSQL, Synapse, MAS, LiveKit
    metaLimitPercent = 75;
    dnodeLimitPercent = 10;
  };

  services = {
    # ── Tailscale: disabled — confirmed present in modules/core/networking.nix ──
    # Future: enroll in self-hosted Headscale when that infrastructure is deployed.
    # The autoconnect service references tailscaled.service; both must be disabled.
    tailscale.enable = lib.mkForce false;

    # ── SSH: cert-based auth; open to all; prohibit-password root ────────────
    # Password auth is disabled globally. Certificate-based authentication is
    # enforced via a trusted SSH CA whose public key lives in the nix-nexus
    # certs/ directory alongside the internal PKI CA (certs/int_cert.crt).
    # Operator manages network-level SSH access restrictions externally.
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = lib.mkForce false;
        KbdInteractiveAuthentication = lib.mkForce false;
        PermitRootLogin = lib.mkForce "prohibit-password";
        # Trust user certificates signed by the fleet SSH CA.
        # Operator places the CA public key at certs/ssh_user_ca.pub.
        # Pattern matches modules/core/security.nix: ../../certs/int_cert.crt
        TrustedUserCAKeys = toString ../../certs/trusted_ssh_ca.pub;
      };
      # No listenAddresses restriction — open to 0.0.0.0/0.
    };

    # ── VM guest tools ───────────────────────────────────────────────────────
    # avina runs as a virtual machine. Install the QEMU guest agent for
    # hypervisor integration (graceful shutdown, time sync, snapshot quiescing).
    qemuGuest.enable = true;
  };

  systemd.services.tailscale-autoconnect.enable = lib.mkForce false;

  system.stateVersion = "25.11";
}
