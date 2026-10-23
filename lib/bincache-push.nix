# Post-build hook that signs a build's closure with the common builder key and pushes it to bincache.
# Imported by relative path from modules/core/nix-signing.nix and modules/user/bincache-home.nix.
{
  pkgs,
  lib,
  nix,
  keyFile,
}:
let
  bincache = import ./bincache.nix;
in
pkgs.writeShellScript "bincache-push" ''
  set -u
  [ -n "''${OUT_PATHS:-}" ] || exit 0
  # ncps accepts only paths signed with a trusted upload key, and the closure of an
  # output includes dependencies that carry only upstream signatures. Sign the closure first.
  # A failed push never fails the build.
  {
    ${nix}/bin/nix store sign \
      --key-file ${keyFile} --recursive $OUT_PATHS \
    && ${pkgs.coreutils}/bin/timeout 600 \
      ${nix}/bin/nix copy --option http-connections 4 \
        --to ${lib.escapeShellArg bincache.pushUrl} $OUT_PATHS
  } || echo "bincache-push: push failed, continuing" >&2
  exit 0
''
