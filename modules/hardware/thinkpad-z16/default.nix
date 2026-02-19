{
  lib,
  ...
}:

{
  # Boot-time optimizations for Ryzen 6000 and AMD hardware
  boot = {
    kernelParams = [
      "amdgpu.sg_display=0" # Fix for white flickering on Ryzen 6000 + OLED
      "amdgpu.dcdebugmask=0x10" # Fix for some RDNA2 display/PM timeouts
      "snd_pci_acp6x.dmic_config=1" # Ensure Digital Mic is detected on Rembrandt
      "amd_pstate=active" # Use active P-States for better power/performance on Ryzen 6000
    ];

    # Hardware Modprobe Options
    extraModprobeConfig = ''
      options snd_pci_acp6x dmic_acp_check=1
      options snd_sof_amd_rembrandt dmic_acp_check=1
      # Fix for WiFi firmware crashes (Qualcomm WCN6855)
      options ath11k_pci disable_aspm=1
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
        # AMD P-State Driver optimization
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

        # Z16 Specific: Limit charging to extend battery health (ThinkPad classic)
        START_CHARGE_THRESH_BAT0 = 75;
        STOP_CHARGE_THRESH_BAT0 = 80;

        # Discrete GPU (Radeon 6500M) power management
        # Ensure the dGPU can power down when not in use (DRI_PRIME=1)
        PCIE_ASPM_ON_BAT = "powersave";
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
