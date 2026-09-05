# Registry key: flake.modules.nixos.services-openrgb
# Configures: OpenRGB, its udev group rules, and the dedicated service user.
# Imported by: hosts/petunia/default.nix (petunia-default).
_: {
  flake.modules.nixos.services-openrgb =
    { pkgs, ... }:
    let
      # OpenRGB's shipped udev rules tag matching devices with
      # TAG+="uaccess", granting access to the seated logind user. That
      # covers ddukes at a console but grants nothing to the headless SDK
      # server, which runs as a dedicated system user (see below). This
      # rewrites the rules to grant the openrgb group access instead, scoped
      # to exactly the OpenRGB-supported device list. The rules do not grant
      # blanket hidraw access. A blanket hidraw grant would expose keyboard
      # HID traffic from unrelated devices.
      #
      # /dev/port (Super I/O controllers) requires CAP_SYS_RAWIO at open
      # time regardless of file permissions. Those specific controllers
      # remain inaccessible to the unprivileged service user. SMBus
      # motherboard RGB (/dev/i2c-*) and USB/hidraw controllers work.
      openrgbGroupRules = pkgs.runCommand "openrgb-group-udev-rules" { } ''
        mkdir -p $out/lib/udev/rules.d
        sed 's/TAG+="uaccess"/GROUP="openrgb", MODE="0660"/' \
          ${pkgs.openrgb}/lib/udev/rules.d/60-openrgb.rules \
          > $out/lib/udev/rules.d/61-openrgb-group.rules
      '';
    in
    {
      # motherboard is left unset; it auto-defaults per host from
      # hardware.cpu.{intel,amd}.updateMicrocode.
      services.hardware.openrgb.enable = true;

      services.udev.packages = [ openrgbGroupRules ];

      users.groups.openrgb = { };
      users.users.openrgb = {
        isSystemUser = true;
        group = "openrgb";
      };

      systemd.services.openrgb.serviceConfig = {
        User = "openrgb";
        Group = "openrgb";
        # OpenRGB derives its config directory from $HOME. The openrgb
        # system user's default home is /var/empty, which is unwritable, so
        # HOME must be pointed at the service's StateDirectory instead.
        Environment = "HOME=/var/lib/OpenRGB";
      };
    };
}
