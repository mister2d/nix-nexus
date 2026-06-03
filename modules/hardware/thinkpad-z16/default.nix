_: {
  flake.modules.nixos.hardware-z16 =
    {
      lib,
      pkgs,
      ...
    }:
    {
      # Boot-time optimizations for Ryzen 6000 and AMD hardware
      boot = {
        # The Z16 benefits greatly from modern kernels for AMDGPU fixes.
        # We pin to 6.12 (LTS) for maximum stability with ZFS while meeting the 6.6+ requirement.
        kernelPackages = lib.mkOverride 900 pkgs.linuxPackages_6_12;

        kernelParams = [
          "amdgpu.sg_display=0" # Fix for white flickering on Ryzen 6000 + OLED
          "amdgpu.dcdebugmask=0x410" # Fix for RDNA2 display/PM timeouts + stability
          "amdgpu.gpu_recovery=1" # Enable soft-recovery for GPU resets
          "amdgpu.lockup_timeout=10000" # Default 10s timeout; 1s was too aggressive and triggered false resets during VA-API video encode
          "amdgpu.gttsize=8192" # Allow 8GB GTT for video conferencing headroom while still reserving RAM for apps
          "iommu=pt" # Passthrough mode for better GPU memory stability on Ryzen
          "snd_pci_acp6x.dmic_config=1" # Ensure Digital Mic is detected on Rembrandt
          "initcall_blacklist=acpi_cpufreq_init" # Prevent legacy driver from competing with P-State
          "mem_sleep_default=s2idle" # Modern Standby (S0ix) is required for the Z16's Rembrandt APU
        ];

        # Hardware Modprobe Options
        extraModprobeConfig = ''
          options snd_pci_acp6x dmic_acp_check=1
          options snd_sof_amd_rembrandt dmic_acp_check=1
          # Fix for WiFi firmware crashes (Qualcomm WCN6855)
          options ath11k_pci disable_aspm=1
          # GPU stability: Disable retry on page faults
          options amdgpu noretry=0
        '';

        # Correct ThinkPad ACPI options
        kernelModules = [ "thinkpad_acpi" ];
      };

      # Services and Power Management
      services = {
        # 1. Power Management: TLP vs Power Profiles
        # The Z16 benefits significantly from modern AMD P-State negotiation.
        # We use power-profiles-daemon for native ACPI profile handling.
        power-profiles-daemon.enable = true;
        tlp.enable = false;

        # The Z16 has a haptic "ForcePad". The 'lenovo-thinkpad-z' base handles the
        # ELAN trackpoint, but we ensure the libinput settings are optimal.
        # (Sway config handles the 'clickfinger' method)
        libinput.enable = true;

        # 4. Fingerprint Support
        # The 'z' base enables fprintd. we just ensure it's here.
        fprintd.enable = lib.mkDefault true;

        # 5. Firmware Updates
        fwupd.enable = true;

        udev.extraRules = ''
          # Set battery charge thresholds to 75% start / 80% stop
          SUBSYSTEM=="power_supply", KERNEL=="BAT0", ATTR{charge_control_start_threshold}="75", ATTR{charge_control_end_threshold}="80"

          # Mic mute LED: force off at boot and allow audio group to sync it at runtime.
          # thinkpad_acpi initialises brightness=1; GROUP+MODE lets the
          # mic-mute-led-sync user service update it without elevated privileges.
          ACTION=="add", SUBSYSTEM=="leds", KERNEL=="platform::micmute", GROUP="audio", MODE="0664", ATTR{brightness}="0"
        '';
      };

      # Fingerprint Support for PAM services (Hardware-Specific)
      security.pam.services = {
        sudo.fprintAuth = true;
        login.fprintAuth = true;
        polkit-1.fprintAuth = true;
      };

      # 2. Audio Quirks (Z16 Audio & Mic)
      # The Z16 uses AMD ACP (Audio Coprocessor) for DMIC and Cirrus Amps for speakers.
      hardware = {
        enableAllFirmware = true;
        enableRedistributableFirmware = true;
        cpu.amd.updateMicrocode = true;
      };

      # 6. Machine-Specific Networking
      # The Z16 WiFi device is specifically named 'wlp4s0'.
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
