# Merged into: flake.modules.nixos.desktop-default
# Configures: the noctalia binary cache substituter for every desktop host.
# Imported by: hosts/sweet16/default.nix (sweet16-default), hosts/petunia/default.nix (petunia-default).
_: {
  # NixOS-side companion to desktop-noctalia-home. The shell itself is a Home
  # Manager concern; only the binary cache has to be declared system-wide.
  flake.modules.nixos.desktop-default =
    { lib, ... }:
    {
      # Upstream noctalia binary cache. Declared in nix.settings so it applies
      # to non-interactive deploys; a flake nixConfig entry would require
      # per-user acceptance that ssh sessions cannot prompt for, and noctalia
      # would build from source on the host.
      # The noctalia input deliberately does not follow nixpkgs, which is what
      # keeps these cache entries valid — see flake.nix.
      nix.settings = {
        substituters = lib.mkAfter [ "https://noctalia.cachix.org" ];
        trusted-public-keys = lib.mkAfter [
          "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
        ];
      };
    };
}
