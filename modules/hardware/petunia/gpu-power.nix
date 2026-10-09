# Merged into: flake.modules.nixos.hardware-petunia
# Configures: R9700 power profile (230 W cap, -75 mV) via LACT, and the gpu-profile helper.
# Imported by: hosts/petunia/default.nix (petunia-default).
_: {
  flake.modules.nixos.hardware-petunia =
    { pkgs, ... }:
    let
      # LACT GPU ids: vendor:device-subvendor:subdevice-pci_slot (see `lact cli list`).
      gpuIds = [
        "1002:7551-1DA2:E499-0000:0e:00.0"
        "1002:7551-1DA2:E499-0000:11:00.0"
      ];
      tuned = {
        power_cap = 230.0;
        voltage_offset = -75;
      };
    in
    {
      # The top-level gpus map is LACT's default profile (current_profile unset).
      # lactd re-applies it on every start and GPU reload.
      services.lact.settings = {
        version = 7;
        daemon = {
          log_level = "info";
          admin_group = "wheel";
        };
        apply_settings_timer = 5;
        gpus = builtins.listToAttrs (
          map (id: {
            name = id;
            value = tuned;
          }) gpuIds
        );
      };

      # gpu-profile {status|default|stock|custom ...}: stock and custom values
      # go through sysfs with lactd stopped; default hands control back to lactd.
      environment.systemPackages = [
        (pkgs.writeShellApplication {
          name = "gpu-profile";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.gawk
            pkgs.gnugrep
            pkgs.systemd
            pkgs.util-linux
          ];
          text = builtins.readFile ../../../lib/petunia/gpu-profile.sh;
        })
      ];
    };
}
