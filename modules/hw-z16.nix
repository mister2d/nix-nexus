{
  inputs,
  lib,
  ...
}:
{
  # ============================================================================

  den.aspects.hw-z16-aspect = lib.mkForce {
    nixos =
      { pkgs, lib, ... }:
      {
        imports = [
          inputs.nixos-hardware.nixosModules.lenovo-thinkpad-z
          inputs.nixos-hardware.nixosModules.common-cpu-amd
          inputs.nixos-hardware.nixosModules.common-gpu-amd
          inputs.nixos-hardware.nixosModules.common-pc-ssd
        ];

        boot = {
          kernelPackages = lib.mkForce pkgs.linuxPackages_6_12;
          kernelParams = [
            "amdgpu.sg_display=0"
            "amdgpu.dcdebugmask=0x410"
            "amdgpu.gpu_recovery=1"
            "amdgpu.lockup_timeout=1000"
            "amdgpu.gttsize=4096"
            "iommu=pt"
            "snd_pci_acp6x.dmic_config=1"
            "amd_pstate=active"
            "initcall_blacklist=acpi_cpufreq_init"
            "mem_sleep_default=s2idle"
          ];
          extraModprobeConfig = ''
            options snd_pci_acp6x dmic_acp_check=1
            options snd_sof_amd_rembrandt dmic_acp_check=1
            options ath11k_pci disable_aspm=1
            options amdgpu noretry=0
          '';
          kernelModules = [ "thinkpad_acpi" ];
        };

        services = {
          power-profiles-daemon.enable = true;
          tlp.enable = false;
          libinput.enable = true;
          fprintd.enable = lib.mkDefault true;
          fwupd.enable = true;
          udev.extraRules = ''
            SUBSYSTEM=="power_supply", KERNEL=="BAT0", ATTR{charge_control_start_threshold}="75", ATTR{charge_control_end_threshold}="80"
            ACTION=="add", SUBSYSTEM=="leds", KERNEL=="platform::micmute", ATTR{brightness}="0"
            SUBSYSTEM=="hwmon", DRIVER=="amdgpu", ATTR{power1_cap_max}!="", ATTR{power1_cap}="$attr{power1_cap_max}"
          '';
        };

        security.pam.services = {
          sudo.fprintAuth = true;
          login.fprintAuth = true;
          polkit-1.fprintAuth = true;
        };

        hardware = {
          enableAllFirmware = true;
          enableRedistributableFirmware = true;
          cpu.amd.updateMicrocode = true;
          bluetooth = {
            enable = true;
            powerOnBoot = true;
            settings.General.Enable = "Source,Sink,Media,Socket";
          };
          graphics = {
            enable = true;
            enable32Bit = true;
            extraPackages = [ pkgs.rocmPackages.clr.icd ];
          };
        };

        services.blueman.enable = true;
        services.pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
          jack.enable = true;
          wireplumber = {
            enable = true;
            extraConfig."10-libcamera"."wireplumber.profiles".main = "optional";
            extraConfig."51-source-routing"."monitor.alsa.rules" = [
              {
                matches = [ [ { "node.name" = "alsa_input.usb-HP__Inc_HyperX_SoloCast-00.HiFi__Mic__source"; } ] ];
                actions.update-props = {
                  "priority.session" = 2500;
                  "priority.driver" = 2500;
                  "session.suspend-timeout-seconds" = 0;
                  "node.pause-on-idle" = false;
                };
              }
              {
                matches = [ [ { "node.name" = "~alsa_input.pci-*"; } ] ];
                actions.update-props = {
                  "priority.session" = 1000;
                  "priority.driver" = 1000;
                };
              }
            ];
          };
          extraConfig.pipewire."92-low-latency"."context.properties" = {
            "default.clock.rate" = 48000;
            "default.clock.quantum" = 1024;
            "default.clock.min-quantum" = 512;
            "default.clock.max-quantum" = 8192;
          };
        };

        networking.interfaces.wlp4s0.useDHCP = lib.mkDefault true;

        environment.systemPackages = with pkgs; [
          nvtopPackages.amd
          amdgpu_top
          clinfo
          rocmPackages.rocminfo
          (pkgs.writeShellScriptBin "battery-travel-mode" ''
            #!/usr/bin/env bash
            BATTERY="/sys/class/power_supply/BAT0"
            if [ ! -d "$BATTERY" ]; then echo "Error: Battery BAT0 not found."; exit 1; fi
            if [ "$1" == "--reset" ]; then
              echo 75 | sudo tee $BATTERY/charge_control_start_threshold > /dev/null
              echo 80 | sudo tee $BATTERY/charge_control_end_threshold > /dev/null
            else
              echo 0 | sudo tee $BATTERY/charge_control_start_threshold > /dev/null
              echo 100 | sudo tee $BATTERY/charge_control_end_threshold > /dev/null
            fi
          '')
          (pkgs.writeShellScriptBin "gpu-launch" ''
            # GPU Selector for Hybrid AMD Systems
            if [ $# -eq 0 ]; then exit 1; fi
            export PATH="$PATH:/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin"
            CHOICE=$(printf "Integrated\nDiscrete" | ${pkgs.wofi}/bin/wofi --dmenu -p "Select GPU" -H 150 -W 300)
            if [ -z "$CHOICE" ] || [[ "$CHOICE" == *"Integrated"* ]]; then exec "$@";
            elif [[ "$CHOICE" == *"Discrete"* ]]; then exec env DRI_PRIME=1 "$@";
            else exec "$@"; fi
          '')
        ];

        environment.variables = {
          LIBVA_DRIVER_NAME = "radeonsi";
          VDPAU_DRIVER = "radeonsi";
          HSA_OVERRIDE_GFX_VERSION = "10.3.0";
        };
      };
  };
}
