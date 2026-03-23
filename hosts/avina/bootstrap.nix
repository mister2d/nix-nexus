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
    ../../modules/core/users.nix
    ../../modules/user/neovim-home.nix # Common Nixvim configuration
  ];

  networking.hostName = "avina-bootstrap";
  networking.hostId = "a6b7c8d9";

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

  # Use stable kernel for ZFS
  boot.kernelPackages =
    lib.mkDefault
      (import inputs.nixpkgs { system = "x86_64-linux"; }).linuxPackages;

  system.stateVersion = "25.11";
}
