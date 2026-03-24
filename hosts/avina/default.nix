{
  inputs,
  lib,
  ...
}:
let
  # ── Deployment values (gitignored — see site-config.nix.example) ─────────
  # Copy hosts/avina/site-config.nix.example → hosts/avina/site-config.nix
  # and fill in real values before building. Never commit site-config.nix.
  site = import ./site-config.nix;
  inherit (site) matrixDomain elementDomain masDomain callDomain coturnRealm vaultAddr;

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
    ../../modules/core/virtualization.nix # Hypervisor guest tools
  ];

  time.timeZone = "America/New_York";

  _module.args = {
    inherit
      matrixDomain
      elementDomain
      masDomain
      callDomain
      coturnRealm
      federatedDomains
      vaultAddr
      ;
  };

  networking = {
    hostName = "avina";
    hostId = "a6b7c8d9";

    # Server Networking Policy:
    # NetworkManager is a workstation/mobile tool; disable it in favour of
    # systemd-networkd, which is appropriate for a headless server.
    networkmanager.enable = lib.mkForce false;
    useNetworkd = true;
    useDHCP = false; # explicit per-interface config below

    # Interface Configuration:
    # ens18 is the virtio NIC on the Proxmox host. DHCP only on this interface.
    interfaces.ens18.useDHCP = true;

    # Public Network Exposure Model:
    # Direct ingress on 443 (HAProxy) and 22 (SSH).
    firewall = lib.mkForce {
      enable = true;
      trustedInterfaces = [ ];
      allowedTCPPorts = [
        22
        443
        5349
        8404
      ]; # SSH + HTTPS + Coturn (TURNS) + HAProxy stats
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

  # Boot Policy:
  # No LUKS on avina — ZFS sits directly on the second GPT partition (VM, no
  # full-disk encryption layer). Clear the LUKS device map that modules/core/boot.nix
  # sets by default so initrd does not block on a non-existent crypto device.
  boot.initrd.luks.devices = lib.mkForce { };

  # ZFS Performance Tuning:
  # Optimized for a Matrix workload on a memory-constrained VM (12GB RAM).
  nix-nexus.zfs = {
    arcMax = 2147483648; # 2 GB ARC limit to prevent OOM
    arcMin = 536870912;
    arcSysFree = 3221225472; # Ensure 3GB for system/app overhead
    metaLimitPercent = 75;
    dnodeLimitPercent = 10;
  };

  # Virtualization Integration:
  # Standardized guest agent and VM optimizations.
  nix-nexus.virtualization.guestAgent.enable = true;

  services = {
    # VPN Policy:
    # Tailscale is disabled in favour of future Headscale integration.
    tailscale.enable = lib.mkForce false;

    # Secure Remote Access:
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = lib.mkForce false;
        KbdInteractiveAuthentication = lib.mkForce false;
        PermitRootLogin = lib.mkForce "prohibit-password";
        TrustedUserCAKeys = toString ../../certs/trusted_ssh_ca.pub;
      };
    };
  };

  systemd.services.tailscale-autoconnect.enable = lib.mkForce false;

  # Session Multiplexer:
  # Matches bootstrap.nix config so operators get a consistent tmux environment
  # across both the initial install phase and runtime.
  programs.tmux = {
    enable = true;
    shortcut = "a";
    baseIndex = 1;
    escapeTime = 0;
    keyMode = "vi";
    terminal = "tmux-256color";
    extraConfig = ''
      set -g status-style bg=black,fg=cyan
      set -g status-left "#[fg=cyan,bold] #S #[default]| "
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
    '';
  };

  system.stateVersion = "25.11";
}
