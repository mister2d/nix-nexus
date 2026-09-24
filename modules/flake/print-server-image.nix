# Flake assembly: packages.print-server-image-amd64,
# packages.print-server-image-arm64. OCI images for the CUPS print server
# (lib/print-server/image.nix), built for the fleet's x86_64 Nomad LAN host
# and the rk3588 aarch64 Nomad node. Evaluated from x86_64-linux only: the
# builder has no aarch64 build capability, so the arm64 image is assembled
# with x86_64 tooling around aarch64 store paths substituted from
# cache.nixos.org (see lib/print-server/image.nix for the split). The build
# machine cannot host `aarch64-linux` itself (no binfmt, no remote builder,
# extra-platforms is x86 only), so this module does not add an aarch64
# perSystem output.
{ inputs, lib, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      packages = lib.optionalAttrs (system == "x86_64-linux") {
        print-server-image-amd64 = import ../../lib/print-server/image.nix { inherit pkgs; };
        print-server-image-arm64 = import ../../lib/print-server/image.nix {
          inherit pkgs;
          targetPkgs = inputs.nixpkgs.legacyPackages.aarch64-linux;
        };
      };
    };
}
