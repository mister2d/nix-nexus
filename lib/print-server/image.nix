# OCI image for a CUPS print server exposing one shared IPP Everywhere
# queue. Modeled on nixpkgs nixos/modules/services/printing/cupsd.nix
# (bindir buildEnv, cups-files.conf layout). Runs as root (uid 0) but is
# meant to be started with all Linux capabilities dropped except CHOWN,
# SETUID, SETGID, DAC_OVERRIDE, FOWNER, and NET_BIND_SERVICE, which cupsd
# needs to bind :631 and drop privilege to the `cups`/`lp` filter identity.
#
# `pkgs` supplies every build-time helper (dockerTools, buildEnv, runCommand,
# replaceVars): these derivations run on the machine doing the build.
# `targetPkgs` supplies everything that executes inside the container (cups,
# bash, coreutils, cacert, ...): these are only ever substituted from the
# binary cache for a foreign target system, never built locally. This split
# lets an x86_64 builder with no aarch64 build capability assemble an
# aarch64 image, since dockerTools.buildLayeredImage only copies and tars
# `contents` — it never executes them.
{
  pkgs,
  targetPkgs ? pkgs,
}:
let
  # Server binaries + filters cupsd looks up via ServerBin/DataDir. No SMB
  # backend, gutenprint, or cups-browsed: the queue is a single driverless
  # (-m everywhere) proxy to a remote IPP Everywhere printer.
  bindir = pkgs.buildEnv {
    name = "cups-progs";
    paths = [
      targetPkgs.cups.out
      targetPkgs.libcupsfilters
      targetPkgs.cups-filters
      targetPkgs.ghostscript
    ];
    pathsToLink = [
      "/bin"
      "/sbin"
      "/lib"
      "/share/cups"
    ];
    ignoreCollisions = true;
  };

  cupsFilesConf = pkgs.replaceVars ./cups-files.conf {
    bindir = "${bindir}";
    docroot = "${targetPkgs.cups.out}/share/doc/cups";
  };

  configFiles = pkgs.runCommand "print-server-config" { } ''
    mkdir -p $out/etc/print-server
    cp ${./cupsd.conf} $out/etc/print-server/cupsd.conf
    cp ${cupsFilesConf} $out/etc/print-server/cups-files.conf
  '';

  entrypoint = pkgs.runCommand "print-server-entrypoint" { } ''
    install -Dm755 ${./entrypoint.sh} $out/entrypoint.sh
  '';

  fakeNss = pkgs.dockerTools.fakeNss.override {
    extraPasswdLines = [ "cups:x:200:200:CUPS print scheduler:/var/empty:/bin/sh" ];
    extraGroupLines = [
      "lp:x:7:"
      "cups:x:200:"
      "lpadmin:x:201:"
    ];
  };

  # dockerTools.binSh/caCertificates close over the `bash`/`cacert` of
  # whichever pkgs instantiated dockerTools. Taking them from targetPkgs
  # would make the wrapping derivation itself a target-system derivation,
  # which cache.nixos.org does not carry (it is not a Hydra-tracked
  # package). Rebuilding the same two symlink derivations from pkgs
  # (host-buildable) that point at targetPkgs' bash/cacert keeps the build
  # local while the symlink targets are still the target architecture.
  targetBinSh = pkgs.runCommand "print-server-bin-sh" { } ''
    mkdir -p $out/bin
    ln -s ${targetPkgs.bashInteractive}/bin/bash $out/bin/sh
  '';

  targetCaCertificates = pkgs.runCommand "print-server-ca-certificates" { } ''
    mkdir -p $out/etc/ssl/certs $out/etc/pki/tls/certs
    ln -s ${targetPkgs.cacert}/etc/ssl/certs/ca-bundle.crt $out/etc/ssl/certs/ca-bundle.crt
    ln -s ${targetPkgs.cacert}/etc/ssl/certs/ca-bundle.crt $out/etc/ssl/certs/ca-certificates.crt
    ln -s ${targetPkgs.cacert}/etc/ssl/certs/ca-bundle.crt $out/etc/pki/tls/certs/ca-bundle.crt
  '';
in
pkgs.dockerTools.buildLayeredImage {
  name = "print-server";
  tag = "latest";
  # dockerTools defaults `architecture` to the GOARCH of the pkgs that
  # instantiated it, i.e. the host (pkgs), not the target. Set it
  # explicitly from targetPkgs so a cross target is labelled correctly.
  architecture = targetPkgs.go.GOARCH;
  contents = [
    bindir
    configFiles
    entrypoint
    targetPkgs.bashInteractive
    targetPkgs.coreutils
    targetPkgs.gnused
    fakeNss
    targetBinSh
    targetCaCertificates
  ];
  extraCommands = ''
    mkdir -p data tmp
  '';
  config = {
    Entrypoint = [ "/entrypoint.sh" ];
    Env = [
      "PATH=${bindir}/bin:${bindir}/sbin:${targetPkgs.coreutils}/bin:${targetPkgs.gnused}/bin:${targetPkgs.bashInteractive}/bin"
    ];
    ExposedPorts = {
      "631/tcp" = { };
    };
  };
}
