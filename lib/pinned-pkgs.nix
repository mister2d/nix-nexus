# Helper: instantiate a pinned nixpkgs flake input the way every call site
# does.
#
# Plain Nix, not a flake-parts fragment. Import it by relative path from the
# consuming module.
#
# Called by: modules/user/*.nix, modules/desktop/hyprland-home.nix, hosts/*.
{ pkgs }:
{
  # pinned <input>: nixpkgs from <input> for the host platform, unfree allowed.
  pinned =
    input:
    import input {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    };

  # pinnedWith <overlays> <input>: the same, with overlays applied.
  pinnedWith =
    overlays: input:
    import input {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
      inherit overlays;
    };
}
