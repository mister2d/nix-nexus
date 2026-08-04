_: {
  # NixOS-side companion to desktop-noctalia-home. The shell itself is a Home
  # Manager concern; only the binary cache has to be declared system-wide.
  flake.modules.nixos.desktop-default =
    { lib, ... }:
    {
      # Declared here rather than relying on the flake's nixConfig. A flake's
      # nixConfig needs interactive per-user acceptance (cached in
      # ~/.local/share/nix/trusted-settings.json), so a non-interactive deploy
      # over ssh silently drops it and rebuilds noctalia from source.
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
