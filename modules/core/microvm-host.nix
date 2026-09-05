# Registry key: flake.modules.nixos.core-microvm-host
# Configures: the bridge, NAT, and nested-virt policy for permafrost microvm guests.
# Imported by: hosts/sweet16/default.nix (sweet16-default).
# Options: nix-nexus.virtualization.microvm.*
# The permafrost runner attaches taps to the bridge at runtime.
_: {
  flake.modules.nixos.core-microvm-host =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.nix-nexus.virtualization.microvm;

      nestedCheck = pkgs.writeShellScript "microvm-host-nested-check" ''
        test "$(cat /sys/module/kvm_amd/parameters/nested)" = 0 || ${pkgs.util-linux}/bin/logger -p daemon.warning -t microvm-host "nested virtualization is enabled. Set kvm_amd nested=0"
      '';
    in
    {
      options.nix-nexus.virtualization.microvm = {
        enable = lib.mkEnableOption "the host side of the permafrost microvm sandbox";

        bridge = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "microbr";
            description = "Name of the bridge interface that carries permafrost guest taps.";
          };

          address = lib.mkOption {
            type = lib.types.str;
            default = "192.168.33.1";
            description = "IPv4 address the host holds on the microvm bridge.";
          };

          prefixLength = lib.mkOption {
            type = lib.types.int;
            default = 24;
            description = "Prefix length of the microvm bridge subnet.";
          };
        };

        tapPattern = lib.mkOption {
          type = lib.types.str;
          default = "microvm*";
          description = "NetworkManager device-spec glob that matches the tap interfaces the permafrost runner creates.";
        };

        externalInterface = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = ''
            Uplink interface for NAT masquerade. A null value lets NAT
            masquerade on whichever interface carries the default route, so
            WiFi and a docked Ethernet both work.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        networking = {
          bridges.${cfg.bridge.name}.interfaces = [ ];

          # The permafrost runner attaches taps at runtime with
          # `ip link set <tap> master <bridge>`.
          interfaces.${cfg.bridge.name}.ipv4.addresses = [
            {
              address = cfg.bridge.address;
              prefixLength = cfg.bridge.prefixLength;
            }
          ];

          networkmanager.unmanaged = [
            "interface-name:${cfg.bridge.name}"
            "interface-name:${cfg.tapPattern}"
          ];

          nat = {
            enable = true;
            internalInterfaces = [ cfg.bridge.name ];
            inherit (cfg) externalInterface;
          };
        };

        # The kernel reads the kvm_amd nested parameter only at module load.
        # The sysfs file is read-only, so modprobe options set the policy.
        boot.extraModprobeConfig = "options kvm_amd nested=0";

        # The second rule checks the nested policy at device creation. It
        # cannot change the parameter.
        services.udev.extraRules = ''
          KERNEL=="kvm", GROUP="kvm", MODE="0660", OPTIONS+="static_node=kvm"
          ACTION=="add", KERNEL=="kvm", RUN+="${nestedCheck}"
        '';

        environment.systemPackages = [
          pkgs.virtiofsd
          pkgs.bridge-utils
          pkgs.waypipe
        ];
      };
    };
}
