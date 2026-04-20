{ pkgs, lib }:

pkgs.buildNpmPackage rec {
  pname = "openclaude";
  version = "0.4.0";

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@gitlawb/openclaude/-/openclaude-${version}.tgz";
    hash = "sha512-H+lvKQNCQPaUeAwSTktvndM72zLK1bYfbj1m3WhQVh9HiCYZWUsbjAlcENa/GqIiXyj8HtcDmedHQx974HJgUA==";
  };

  # Use the generated lock file
  postPatch = ''
    cp ${./openclaude-lock.json} package-lock.json
    
    # Add a dummy build script to avoid running Bun
    # buildNpmPackage defaults to 'npm run build' if dontBuild is not respected
    # and some versions of nixpkgs might ignore dontBuild in buildNpmPackage
    jq '.scripts.build = "true"' package.json > package.json.tmp && mv package.json.tmp package.json
  '';

  npmDepsHash = "sha256-vdAuPPeG2xlIjT4mNf3fs/czW/s8X890a1bcSHKcxgc=";

  npmFlags = [ "--legacy-peer-deps" ];

  nativeBuildInputs = with pkgs; [
    makeWrapper
    jq
  ];

  # Force skipping the build phase
  dontBuild = true;

  # Ensure sharp and other native deps are handled
  makeCacheWritable = true;

  postInstall = ''
    # Ensure the target directory exists
    mkdir -p $out/lib/node_modules/@gitlawb/openclaude
    
    # Remove the default symlink created by buildNpmPackage if it exists
    rm -f $out/bin/openclaude
    
    # Wrap the actual entry point
    makeWrapper $out/lib/node_modules/@gitlawb/openclaude/bin/openclaude $out/bin/openclaude \
      --prefix PATH : ${lib.makeBinPath [ pkgs.nodejs_24 pkgs.ripgrep ]}
  '';

  meta = with lib; {
    description = "Open-source coding-agent CLI (Claude Code alternative)";
    homepage = "https://github.com/Gitlawb/openclaude";
    license = licenses.mit;
    platforms = platforms.all;
    mainProgram = "openclaude";
  };
}
