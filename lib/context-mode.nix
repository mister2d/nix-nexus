# Helper: builds the context-mode npm package.
# Called by: hosts/hermes/groot-hm.nix.
{ pkgs, lib }:

let
  version = "1.0.169";
in
pkgs.buildNpmPackage {
  pname = "context-mode";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/context-mode/-/context-mode-${version}.tgz";
    hash = "sha512-94JIaFuLjF9SO2BsGTrbGtyT44K95+9OC8BdbaL/UT76xOkanJLfUR5CzmNw+GELXZQqH4nBrKg9wjBnSFkVnQ==";
  };

  # The published tarball ships no lockfile. Use the one generated out-of-band.
  postPatch = ''
    cp ${./context-mode-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-VNeQeINN0B5BXUDM2/H5IDT6ySWCLmuC8HG7Pvdsp40=";

  # scripts.postinstall hard-exits on Linux + Node <22.5 and shells out to
  # prebuild-install/npm against the network. Skip all lifecycle scripts.
  npmFlags = [ "--ignore-scripts" ];

  # --ignore-scripts also skips better-sqlite3's own install script, so let
  # npmRebuild build the native addon from source instead.
  nativeBuildInputs = [
    pkgs.python3
    pkgs.node-gyp
    pkgs.makeWrapper
  ];

  # The package ships prebuilt cli.bundle.mjs / server.bundle.mjs.
  buildPhase = "true";

  # The bundles mark better-sqlite3, turndown, turndown-plugin-gfm, and
  # @mixmark-io/domino as external. node_modules must ship alongside the
  # bundle rather than installing cli.bundle.mjs on its own.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/node_modules/context-mode
    cp -r . $out/lib/node_modules/context-mode

    makeWrapper ${pkgs.nodejs_24}/bin/node $out/bin/context-mode \
      --add-flags $out/lib/node_modules/context-mode/cli.bundle.mjs \
      --prefix PATH : ${lib.makeBinPath [ pkgs.nodejs_24 ]}

    runHook postInstall
  '';

  meta = {
    description = "MCP plugin that reduces agent context window usage via a sandboxed, FTS5-backed knowledge base";
    homepage = "https://github.com/mksglu/context-mode";
    license = lib.licenses.elastic20;
    platforms = lib.platforms.all;
    mainProgram = "context-mode";
  };
}
