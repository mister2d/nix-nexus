{ pkgs, lib }:

let
  version = "0.4.0";
in
pkgs.buildNpmPackage {
  pname = "openclaude";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@gitlawb/openclaude/-/openclaude-${version}.tgz";
    hash = "sha512-H+lvKQNCQPaUeAwSTktvndM72zLK1bYfbj1m3WhQVh9HiCYZWUsbjAlcENa/GqIiXyj8HtcDmedHQx974HJgUA==";
  };

  # Use the generated lock file
  postPatch = ''
    cp ${./openclaude-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-vdAuPPeG2xlIjT4mNf3fs/czW/s8X890a1bcSHKcxgc=";

  npmFlags = [ "--legacy-peer-deps" ];

  nativeBuildInputs = with pkgs; [
    makeWrapper
  ];

  # Force skipping the build phase entirely by overriding the standard phase
  buildPhase = "true";

  # We will handle installation manually in a custom installPhase
  installPhase = ''
    runHook preInstall

    # Ensure the target directory exists
    mkdir -p $out/lib/node_modules/@gitlawb/openclaude

    # Copy the package files
    cp -r . $out/lib/node_modules/@gitlawb/openclaude

    # Wrap the actual entry point
    makeWrapper $out/lib/node_modules/@gitlawb/openclaude/bin/openclaude $out/bin/openclaude \
      --prefix PATH : ${
        lib.makeBinPath [
          pkgs.nodejs_24
          pkgs.ripgrep
        ]
      }

    runHook postInstall
  '';

  meta = {
    description = "Open-source coding-agent CLI (Claude Code alternative)";
    homepage = "https://github.com/Gitlawb/openclaude";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
    mainProgram = "openclaude";
  };
}
