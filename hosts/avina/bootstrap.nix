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
  ];

  networking.hostName = "avina-bootstrap";
  networking.hostId = "a6b7c8d9";

  # Enable SSH for Stage 2 remote deployment if needed
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
  };

  # Use stable kernel for ZFS
  boot.kernelPackages =
    lib.mkDefault
      (import inputs.nixpkgs { system = "x86_64-linux"; }).linuxPackages;

  system.stateVersion = "25.11";
}
