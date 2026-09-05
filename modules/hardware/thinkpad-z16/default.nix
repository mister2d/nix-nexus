# Merged into: flake.modules.nixos.hardware-z16
# Configures: kernel packages, boot parameters, fingerprint auth, and battery thresholds.
# Imported by: hosts/sweet16/default.nix (sweet16-default).
_: {
  flake.modules.nixos.hardware-z16 =
    {
      lib,
      pkgs,
      ...
    }:
    {
      # Boot configuration for Ryzen 6000 and AMD hardware.
      boot = {
        # Kernel 6.12 (LTS) carries the AMDGPU fixes this hardware needs and
        # meets the 6.6+ ZFS requirement.
        kernelPackages = lib.mkOverride 900 pkgs.linuxPackages_6_12;

        kernelParams = [
          "amdgpu.sg_display=0" # Prevents white flickering on Ryzen 6000 OLED panels
          "amdgpu.dcdebugmask=0x410" # Stabilizes RDNA2 display and power-management timeouts
          "amdgpu.gpu_recovery=1" # Enables GPU soft recovery after a reset
          "amdgpu.lockup_timeout=10000" # 10s lockup timeout avoids false resets during VA-API video encode
          "amdgpu.gttsize=8192" # Reserves 8GB GTT for video conferencing headroom
          "iommu=pt" # Improves GPU memory stability via passthrough mode
          "snd_pci_acp6x.dmic_config=1" # Enables detection of the digital mic on Rembrandt
          "initcall_blacklist=acpi_cpufreq_init" # Blocks acpi_cpufreq so P-State handles frequency scaling
          "mem_sleep_default=s2idle" # Enables Modern Standby (S0ix) for the Rembrandt APU
        ];

        # Modprobe options for audio, WiFi, and GPU stability.
        extraModprobeConfig = ''
          options snd_pci_acp6x dmic_acp_check=1
          options snd_sof_amd_rembrandt dmic_acp_check=1
          # Fix for WiFi firmware crashes (Qualcomm WCN6855)
          options ath11k_pci disable_aspm=1
          # GPU stability: Disable retry on page faults
          options amdgpu noretry=0
        '';

        # Loads the ThinkPad ACPI kernel module.
        kernelModules = [ "thinkpad_acpi" ];
      };

      # Power management and hardware services.
      services = {
        # power-profiles-daemon handles ACPI power profiles natively via AMD P-State.
        power-profiles-daemon.enable = true;
        tlp.enable = false;

        # libinput drives the ForcePad's ELAN trackpoint. Sway configures the
        # clickfinger method separately.
        libinput.enable = true;

        # lenovo-thinkpad-z already enables fprintd. mkDefault keeps this
        # explicit without overriding host settings.
        fprintd.enable = lib.mkDefault true;

        # Firmware updates via fwupd.
        fwupd.enable = true;

        udev.extraRules = ''
          # Set battery charge thresholds to 75% start / 80% stop
          SUBSYSTEM=="power_supply", KERNEL=="BAT0", ATTR{charge_control_start_threshold}="75", ATTR{charge_control_end_threshold}="80"

          # Mic mute LED: force off at boot and allow audio group to sync it at runtime.
          # thinkpad_acpi initialises brightness=1. GROUP/MODE on the device node
          # does not propagate to sysfs attribute files, so RUN+= explicitly sets
          # group ownership and mode on the brightness file for mic-mute-led-sync.
          ACTION=="add", SUBSYSTEM=="leds", KERNEL=="platform::micmute", ATTR{brightness}="0", RUN+="${pkgs.coreutils}/bin/chown :audio /sys/class/leds/platform::micmute/brightness", RUN+="${pkgs.coreutils}/bin/chmod 0664 /sys/class/leds/platform::micmute/brightness"
        '';
      };

      # PAM services request fingerprint authentication.
      security.pam.services = {
        sudo.fprintAuth = true;
        login.fprintAuth = true;
        polkit-1.fprintAuth = true;
      };

      # Enables all firmware and AMD CPU microcode updates.
      hardware = {
        enableAllFirmware = true;
        enableRedistributableFirmware = true;
        cpu.amd.updateMicrocode = true;
      };

      # The Z16 WiFi device is named wlp4s0.
      networking.interfaces.wlp4s0.useDHCP = lib.mkDefault true;

      environment.systemPackages = [
        (pkgs.writeShellScriptBin "battery-travel-mode" ''
          #!/usr/bin/env bash
          # Battery Travel Mode Override
          # Temporarily allow the battery to charge to 100% until next reboot.

          BATTERY="/sys/class/power_supply/BAT0"

          if [ ! -d "$BATTERY" ]; then
            echo "Error: Battery BAT0 not found."
            exit 1
          fi

          echo "Current thresholds:"
          echo "  Start: $(cat $BATTERY/charge_control_start_threshold)%"
          echo "  Stop:  $(cat $BATTERY/charge_control_end_threshold)%"

          if [ "$1" == "--reset" ]; then
            echo "Resetting to persistent NixOS thresholds (75/80)..."
            echo 75 | sudo tee $BATTERY/charge_control_start_threshold > /dev/null
            echo 80 | sudo tee $BATTERY/charge_control_end_threshold > /dev/null
          else
            echo "Enabling travel mode (charging to 100%)..."
            echo 0 | sudo tee $BATTERY/charge_control_start_threshold > /dev/null
            echo 100 | sudo tee $BATTERY/charge_control_end_threshold > /dev/null
          fi

          echo "New thresholds:"
          echo "  Start: $(cat $BATTERY/charge_control_start_threshold)%"
          echo "  Stop:  $(cat $BATTERY/charge_control_end_threshold)%"
        '')
      ];
    };
}
