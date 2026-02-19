{ pkgs, ... }:

{
  # User Account: ddukes
  # This account is the primary user and is granted administrative (wheel)
  # and various hardware access permissions.
  users.users.ddukes = {
    isNormalUser = true;
    description = "ddukes";

    # Password Management
    # Current configuration uses a simple initial password for testing.
    # It is highly recommended to change this post-installation or
    # use mutable users for password persistence across rebuilds.
    password = "nixos";

    # User Groups
    # - networkmanager: WiFi and connectivity management
    # - wheel: Sudo/Administrative access
    # - video/audio: Access to display and sound hardware
    # - docker: Access to the Docker daemon
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "audio"
      "input"
      "docker"
    ];

    # Shell: Bash (standard)
    shell = pkgs.bash;

    # SSH Authorized Keys
    # Allows for secure, passwordless SSH access to this machine.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGQp6H/n2JPSt1VxCAupTC1OTh7R3eu7wO0ZtCNbAkd7"
    ];
  };
}
