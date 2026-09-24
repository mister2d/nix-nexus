# Flake assembly: packages.print-server-image. OCI image for the CUPS print
# server (lib/print-server/image.nix). x86_64-linux only: the fleet's Nomad
# LAN host is x86_64.
{ lib, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      packages = lib.optionalAttrs (system == "x86_64-linux") {
        print-server-image = import ../../lib/print-server/image.nix { inherit pkgs; };
      };
    };
}
