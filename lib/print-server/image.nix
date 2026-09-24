# OCI image for a CUPS print server exposing one shared IPP Everywhere
# queue. Modeled on nixpkgs nixos/modules/services/printing/cupsd.nix
# (bindir buildEnv, cups-files.conf layout). Runs as root (uid 0) but is
# meant to be started with all Linux capabilities dropped except CHOWN,
# SETUID, SETGID, DAC_OVERRIDE, FOWNER, and NET_BIND_SERVICE, which cupsd
# needs to bind :631 and drop privilege to the `cups`/`lp` filter identity.
{ pkgs }:
let
  # Server binaries + filters cupsd looks up via ServerBin/DataDir. No SMB
  # backend, gutenprint, or cups-browsed: the queue is a single driverless
  # (-m everywhere) proxy to a remote IPP Everywhere printer.
  bindir = pkgs.buildEnv {
    name = "cups-progs";
    paths = [
      pkgs.cups.out
      pkgs.libcupsfilters
      pkgs.cups-filters
      pkgs.ghostscript
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
    docroot = "${pkgs.cups.out}/share/doc/cups";
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
in
pkgs.dockerTools.buildLayeredImage {
  name = "print-server";
  tag = "latest";
  contents = [
    bindir
    configFiles
    entrypoint
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.gnused
    fakeNss
    pkgs.dockerTools.binSh
    pkgs.dockerTools.caCertificates
  ];
  extraCommands = ''
    mkdir -p data tmp
  '';
  config = {
    Entrypoint = [ "/entrypoint.sh" ];
    Env = [
      "PATH=${bindir}/bin:${bindir}/sbin:${pkgs.coreutils}/bin:${pkgs.gnused}/bin:${pkgs.bashInteractive}/bin"
    ];
    ExposedPorts = {
      "631/tcp" = { };
    };
  };
}
