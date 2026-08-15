_: {
  flake.modules.homeManager.petunia-home =
    { homeManagerModules, ... }:

    {
      imports = [
        homeManagerModules.user-home

        # TPM-sealed SSH keys. Host-gated: requires a TPM and membership in
        # nix-nexus.tpm2.users.
        homeManagerModules.user-ssh-tpm-agent

        # Desktop Environments & Customization
        homeManagerModules.desktop-noctalia-home
        homeManagerModules.hardware-petunia-hypr-home
        homeManagerModules.desktop-hyprland-home
        homeManagerModules.desktop-theme-home
      ];

      # Resource Monitor (amdgpu_top provides detailed AMD metrics; btop for process view)
      programs.btop.enable = true;
    };
}
