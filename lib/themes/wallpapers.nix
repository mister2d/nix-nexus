# Per-theme wallpaper packs, pinned to omacom/omarchy rev
# b686ed892d9c3020c3336203f6d34cc75b544e2b (MIT-licensed repo; images carry
# no separate license statement).
{ pkgs }:
let
  rev = "b686ed892d9c3020c3336203f6d34cc75b544e2b";
  base = "https://raw.githubusercontent.com/omacom/omarchy/${rev}/themes";

  mkPack =
    theme: files:
    pkgs.linkFarm "omarchy-wallpapers-${theme}" (
      map (f: {
        inherit (f) name;
        path = pkgs.fetchurl {
          url = "${base}/${theme}/backgrounds/${f.name}";
          inherit (f) hash;
        };
      }) files
    );
in
{
  matte-black = mkPack "matte-black" [
    {
      name = "0-ship-at-sea.jpg";
      hash = "sha256-VfppGt/T+4qRArgmoo2N5nmTjwSHl5naSZuKzi/gOaw=";
    }
    {
      name = "1-dark-waters.webp";
      hash = "sha256-MX72w57t3pdsWabrTHgoN6ZhqRCJq3hXUWNo3JLQSBs=";
    }
    {
      name = "2-dot-hands.webp";
      hash = "sha256-pR4NxUBtBU3f4W3HMq2kBhxzOp5vmFo/93O6HoA606A=";
    }
    {
      name = "omarchy.webp";
      hash = "sha256-uGe6ddwpsHP0PiIXCkio+ANlk5sWSBpUVBGEqxPZjOw=";
    }
  ];

  osaka-jade = mkPack "osaka-jade" [
    {
      name = "1-glowing-city.webp";
      hash = "sha256-0jTEp8jGXaMHxfzGY5b37Qpc/0NEEA4CdyxMxM6KWUY=";
    }
    {
      name = "2-shaded-entrance.webp";
      hash = "sha256-CspLHo1RTd84i2t6nbXmx6F24Gz9YVtKPJmKg9ZUZ/s=";
    }
    {
      name = "3-mountain-moon.webp";
      hash = "sha256-nS+hvnMQaWJ7aPmWVu759m0lX8DYx84TK05IaPvkL78=";
    }
    {
      name = "omarchy.webp";
      hash = "sha256-w9EwDY/nDeetmOahLl49F52GLiqUS1NKO8g9vH8Hmk4=";
    }
  ];

  ristretto = mkPack "ristretto" [
    {
      name = "0-launch.webp";
      hash = "sha256-QtOnv+XL82Nh6MAVLJ/KLG4zAud5aQrtWi1uoKuYUEQ=";
    }
    {
      name = "1-color-curves.webp";
      hash = "sha256-nywQQ9w2kB8vWXmtOf2tWxEc29OJJ+gzLoLyjPf4F1Q=";
    }
    {
      name = "2-coffee-beans.jpg";
      hash = "sha256-otZ9hgRACfx8cGb0x75VxkcatfJRekCypKbTuhoMwM0=";
    }
    {
      name = "3-industrial-moon.webp";
      hash = "sha256-g7pcVWTMw5r/ho4D/FcEttoUYSDFXrKL3Ksifh1RDC0=";
    }
    {
      name = "omarchy.webp";
      hash = "sha256-0tuQf/wGVcc7v7KefRd5Y0HY07361y16PDtAix6ZZYI=";
    }
  ];
}
