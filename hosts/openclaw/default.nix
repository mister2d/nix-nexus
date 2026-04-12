{
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ../../profiles/server
    ./vault-secrets.nix
  ];

  proxmoxLXC = {
    privileged = false;
    manageNetwork = false;
  };

  # Let Proxmox manage IP assignment, NixOS systemd-networkd handles DHCP locally.
  networking = {
    hostName = "openclaw";
    networkmanager.enable = false;
    firewall.enable = false;
  };

  systemd.network = {
    enable = true;
    networks."10-eth0" = {
      matchConfig.Name = "eth0";
      networkConfig.DHCP = "yes";
    };
  };

  # Host-level User configurations
  users.users.groot = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGQp6H/n2JPSt1VxCAupTC1OTh7R3eu7wO0ZtCNbAkd7"
    ];
  };

  services = {
    resolved = {
      enable = true;
      extraConfig = ''
        Cache=true
        CacheFromLocalhost=true
      '';
    };

    fstrim.enable = false;

    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = lib.mkForce false;
        KbdInteractiveAuthentication = lib.mkForce false;
        PermitRootLogin = lib.mkForce "prohibit-password";
        TrustedUserCAKeys = toString ../../certs/trusted_ssh_ca.pub;
      };
    };

    tailscale = {
      enable = true;
      authKeyFile = "/run/secrets/tailscale.key";
    };
  };

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

  nixpkgs.config.permittedInsecurePackages = [
    "openclaw-2026.4.2"
  ];

  system.stateVersion = "25.11";
}
