{
  inputs,
  lib,
  ...
}:
{
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./hardware-configuration.nix
    ../../profiles/core # Core system policies (ZFS, networking, security, internal CA)
    ../../modules/user/neovim-home.nix # Common Nixvim configuration
  ];

  time.timeZone = "America/New_York";

  networking = {
    hostName = "avina-bootstrap";
    hostId = "a6b7c8d9";
    firewall.allowedTCPPorts = [ 22 ];
  };

  _module.args = {
    vaultAddr = "https://vault.service.consul:8200";
    cloudflaredTunnelId = "bootstrap-placeholder";
  };

  # ZFS Performance Tuning (Optimized for 12GB RAM)
  nix-nexus.zfs = {
    arcMax = 2147483648; # 2 GB ARC limit to prevent OOM
    arcMin = 536870912;
    arcSysFree = 3221225472; # Ensure 3GB for system/app overhead
  };

  # Secure Remote Access (Stage 1):
  # Certificate-based authentication via repository-managed SSH CA.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = lib.mkForce false;
      KbdInteractiveAuthentication = lib.mkForce false;
      PermitRootLogin = lib.mkForce "prohibit-password";
      TrustedUserCAKeys = toString ../../certs/trusted_ssh_ca.pub;
    };
  };

  # Background Persistence & Multiplexing:
  # Tools required to background the Stage 2 deployment process.
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

  programs.screen.enable = true;

  # Serial Console:
  # Merged with hardware-configuration.nix (zfsforce=1) and any params
  # added by NixOS modules. No mkForce — list concatenation is correct here.
  boot.kernelParams = [
    "console=tty0"
    "console=ttyS0,115200n8"
  ];

  # Serial Login:
  # Provides an interactive login prompt on ttyS0 for Proxmox serial console
  # access during Stage 1 before SSH is available or if it fails.
  systemd.services."serial-getty@ttyS0" = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Restart = "always";
  };

  # Use stable kernel for ZFS
  boot.kernelPackages =
    lib.mkDefault
      (import inputs.nixpkgs { system = "x86_64-linux"; }).linuxPackages;

  # Nix Configuration (Alignment)
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # Boost resource limits for large builds
    max-jobs = lib.mkForce 2;
    cores = lib.mkForce 2;
  };

  environment.variables.NIXPKGS_ALLOW_UNFREE = "1";

  system.stateVersion = "25.11";
}
