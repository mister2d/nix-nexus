# Internal binary cache: pass-through to upstream caches, plus the store for paths we push.
# Imported by relative path from modules/core/nix.nix and modules/core/nix-signing.nix.
{
  url = "https://bincache.service.internal.novuscotia.com";

  # ncps accepts PUT only under /upload/; the root URL serves GET, HEAD and DELETE.
  pushUrl = "https://bincache.service.internal.novuscotia.com/upload?compression=zstd";

  publicKeys = [
    "bincache.service.internal.novuscotia.com-1:IfblfHmVT0hAl2tniKiPPlXO8qOTP2mqP5LoHSSXyeQ="
    "builder-1:Ks4W6vv/Y3yZz5d/0D5SUTM3zarq1XRBjoUrB7pV5oM="
  ];
}
