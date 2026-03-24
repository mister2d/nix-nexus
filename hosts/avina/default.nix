{
  lib,
  ...
}:
let
  # ── Deployment values (gitignored — see site-config.nix.example) ─────────
  # Copy hosts/avina/site-config.nix.example → hosts/avina/site-config.nix
  # and fill in real values before building. Never commit site-config.nix.
  site = import ./site-config.nix;
  inherit (site)
    matrixDomain
    elementDomain
    masDomain
    callDomain
    coturnRealm
    vaultAddr
    certDomain
    ;

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
    ../../profiles/server # Base: security, sysctl, users, DNS — no ZFS, no boot, no NM
    ../../modules/services/matrix # Matrix 2.0 communications suite
  ];

  # Container Policy:
  # avina runs as a Proxmox LXC container. No bootloader, no kernel config,
  # no filesystem management — the hypervisor handles all of that.
  boot.isContainer = true;

  _module.args = {
    inherit
      matrixDomain
      elementDomain
      masDomain
      callDomain
      coturnRealm
      federatedDomains
      vaultAddr
      certDomain
      ;
  };

  # Allow HAProxy to bind to port 443 as the haproxy user (non-root).
  # net.ipv4.ip_unprivileged_port_start is namespace-scoped and settable in
  # unprivileged LXC containers; lowering it to 443 permits binding to 443/8404.
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 443;

  networking = {
    hostName = "avina";

    # Firewall Policy:
    # Proxmox is configured wide-open at the hypervisor level; NixOS owns the
    # firewall inside the container. Only the ports required by the Matrix stack
    # and operator access are opened.
    firewall = {
      enable = true;
      trustedInterfaces = [ ];
      allowedTCPPorts = [
        22 # SSH
        443 # HAProxy (HTTP/S + Matrix federation)
        5349 # Coturn TURNS/TLS
        8404 # HAProxy stats (operator access)
      ];
      allowedUDPPorts = [
        3478 # Coturn STUN/TURN
        5349 # Coturn TURNS/DTLS
      ];
      allowedUDPPortRanges = [
        {
          from = 49000;
          to = 49999;
        } # Coturn dynamic relay range
      ];
      allowedTCPPortRanges = [
        {
          from = 3478;
          to = 3478;
        }
      ];
    };
  };

  services = {
    # Secure Remote Access:
    # Certificate-based auth via repository-managed SSH CA. Password auth
    # disabled. Root login permitted as prohibit-password (cert/key only).
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

  # Session Multiplexer:
  # Persistent sessions for long-running deploys and maintenance.
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
