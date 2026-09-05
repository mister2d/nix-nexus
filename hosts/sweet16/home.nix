# Host: sweet16 (NixOS x86_64 workstation).
# Registry key: flake.modules.homeManager.sweet16-home
# Composes: user-home, user-ssh-tpm-agent, desktop-noctalia-home, hardware-z16-hypr-home, desktop-hyprland-home, desktop-theme-home.
_: {
  flake.modules.homeManager.sweet16-home =
    { pkgs, homeManagerModules, ... }:

    {
      imports = [
        # ── Shared user profile ─────────────────────────────────────────
        homeManagerModules.user-home

        # ── TPM-sealed SSH keys ────────────────────────────────────────
        # Host-gated: requires a TPM and membership in nix-nexus.tpm2.users.
        homeManagerModules.user-ssh-tpm-agent

        # ── Hyprland + Noctalia v5 stack ───────────────────────────────
        # desktop-noctalia-home: compositor-agnostic shell (bar, launcher,
        # notifications, wallpaper, polkit, OSD, screenshots, session).
        # hardware-z16-hypr-home: monitor layout, HDR, workspace assignments.
        homeManagerModules.desktop-noctalia-home
        homeManagerModules.hardware-z16-hypr-home
        homeManagerModules.desktop-hyprland-home
        homeManagerModules.desktop-theme-home
      ];

      programs.btop.package = pkgs.btop.override { rocmSupport = true; };
    };
}
