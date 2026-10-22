# Internal binary cache: pass-through to upstream caches, plus the store for paths we push.
# Imported by relative path from modules/core/nix.nix and modules/core/nix-signing.nix.
{
  url = "https://bincache.service.internal.novuscotia.com";

  # Public signing keys, one `name:base64` string each: the contents of
  # .secrets/cache.pub (keys the cache re-signs pass-through paths with) and
  # .secrets/builder.pub (keys our fleet signs pushed paths with).
  publicKeys = [ ];
}
