_: {
  flake.modules.homeManager.sweet16-home =
    { pkgs, homeManagerModules, ... }:

    {
      imports = [
        # ── Shared user profile ─────────────────────────────────────────
        homeManagerModules.user-home

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
