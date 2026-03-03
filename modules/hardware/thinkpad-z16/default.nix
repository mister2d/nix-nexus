{
  lib,
  ...
}:

{
  # Boot-time optimizations for Ryzen 6000 and AMD hardware
  boot = {
    kernelParams = [
      "amdgpu.sg_display=0" # Fix for white flickering on Ryzen 6000 + OLED
      "amdgpu.dcdebugmask=0x410" # Fix for RDNA2 display/PM timeouts + stability
      "amdgpu.gpu_recovery=1" # Enable soft-recovery for GPU resets
      "amdgpu.lockup_timeout=1000" # Increase timeout threshold for stability
      "amdgpu.gttsize=8192" # Increase iGPU dynamic memory (GTT) to 8GB (Note: Set UMA in BIOS for dedicated VRAM)
      "iommu=pt" # Passthrough mode for better GPU memory stability on Ryzen
      "snd_pci_acp6x.dmic_config=1" # Ensure Digital Mic is detected on Rembrandt
      "amd_pstate=active" # Use active P-States for better power/performance on Ryzen 6000
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
    # The Z16 benefits significantly from TLP tuning due to the dGPU.
    # We disable power-profiles-daemon to avoid conflicts with TLP.
    power-profiles-daemon.enable = false;

    tlp = {
      enable = true;
      settings = {
        # --- CPU & Performance ---
        # AMD P-State EPP (Active Mode) optimization for Ryzen 6000 (Rembrandt)
        # We use 'balance_performance' instead of 'performance' on AC to reduce
        # aggressive clock boosting for short tasks, lowering chassis heat.
        CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";

        # Scaling Governor for P-State Driver
        # In 'active' mode, the EPP (above) is the primary driver.
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

        # --- Platform & Thermal Management ---
        # Lenovo Platform Profiles: Lowers the EC thermal ceiling on battery.
        # This reduces fan noise and improves endurance while allowing CPU spikes.
        PLATFORM_PROFILE_ON_BAT = "low-power";
        PLATFORM_PROFILE_ON_AC = "performance";

        # --- Battery Health ---
        # Z16 Specific: Limit charging to extend battery health (ThinkPad classic)
        START_CHARGE_THRESH_BAT0 = 20;
        STOP_CHARGE_THRESH_BAT0 = 80;

        # --- GPU & PCIe Management ---
        # Discrete GPU (Radeon 6500M) power management
        # Ensure the dGPU can power down completely (D3Cold) when not in use (DRI_PRIME=1)
        # 'powersupersave' enables the deepest possible PCIe link states (L1.1/L1.2).
        PCIE_ASPM_ON_AC = "performance";
        PCIE_ASPM_ON_BAT = "powersupersave";

        # Runtime PM for NVMe and other PCIe devices.
        # We use 'on' instead of 'auto' on battery to prevent the haptic ForcePad
        # and internal bridge from entering unrecoverable sleep states.
        RUNTIME_PM_ON_AC = "on";
        RUNTIME_PM_ON_BAT = "on";

        # --- Connectivity & Peripherals ---
        # Put WiFi into power saving, but disable USB autosuspend as it
        # causes issues with the Z16's haptic sensors and cameras.
        WIFI_PWR_ON_BAT = "on";
        USB_AUTOSUSPEND = 0;

        # Enable Audio power saving for the AMD ACP (Audio Coprocessor)
        SOUND_QUERY_CHIPS = "false";
        RST_PHASE_1 = 1;
      };
    };

    # The Z16 has a haptic "ForcePad". The 'lenovo-thinkpad-z' base handles the
    # ELAN trackpoint, but we ensure the libinput settings are optimal.
    # (Sway config handles the 'clickfinger' method)
    libinput.enable = true;

    # 4. Fingerprint Support
    # The 'z' base enables fprintd. we just ensure it's here.
    fprintd.enable = lib.mkDefault true;

    # 5. Firmware Updates
    fwupd.enable = true;
  };

  # Fingerprint Support for PAM services (Hardware-Specific)
  security.pam.services = {
    sudo.fprintAuth = true;
    login.fprintAuth = true;
    polkit-1.fprintAuth = true;
  };

  # 2. Audio Quirks (Z16 Audio & Mic)
  # The Z16 uses AMD ACP (Audio Coprocessor) for DMIC and Cirrus Amps for speakers.
  hardware.enableAllFirmware = true;

  # Fix for Mic LED: Link it to the kernel's audio-micmute trigger
  systemd.tmpfiles.rules = [
    "w /sys/class/leds/platform::micmute/trigger - - - - audio-micmute"
  ];

  # 6. Machine-Specific Networking
  # The Z16 WiFi device is specifically named 'wlp4s0'.
  networking.interfaces.wlp4s0.useDHCP = lib.mkDefault true;
}
