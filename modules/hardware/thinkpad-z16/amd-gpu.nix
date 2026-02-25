{ pkgs, ... }:

{
  # Graphics
  hardware.graphics = {
    enable = true;
    enable32Bit = false; # Disabled: No Steam/legacy 32-bit apps needed
    extraPackages = with pkgs; [
      rocmPackages.clr.icd
    ];
  };

  services.xserver.videoDrivers = [ "amdgpu" ];

  # GPU Power Management
  # The ThinkPad Z16 Gen 1 (Radeon 6500M / 680M) has a VBIOS-enforced 30W power limit.
  # The amdgpu driver often attempts to set a generic 50W default, leading to
  # "New power limit (50) is out of range [30,30]" errors in dmesg.
  # We declaratively set the power cap to the hardware-reported maximum (30W)
  # to satisfy the driver during initialization and resume.
  services.udev.extraRules = ''
    SUBSYSTEM=="hwmon", DRIVER=="amdgpu", ATTR{power1_cap_max}!="", ATTR{power1_cap}="$attr{power1_cap_max}"
  '';

  environment.systemPackages = with pkgs; [
    nvtopPackages.amd
    amdgpu-top # Specialized AMD monitor that can target specific GPUs
    (pkgs.writeShellScriptBin "monitor-igpu" ''
      # Monitor Integrated GPU (680M) without waking the Discrete GPU (6500M)
      # Generic tools like 'nvtop' scan all PCI devices, causing a dGPU wakeup.
      exec ${pkgs.amdgpu-top}/bin/amdgpu-top -d 0 "$@"
    '')
    (pkgs.writeShellScriptBin "gpu-launch" ''
      # GPU Selector for Hybrid AMD Systems (ThinkPad Z16 Gen 1)
      # Usage: gpu-launch <command> [args...]

      if [ $# -eq 0 ]; then
          exit 1
      fi

      # Ensure we can find system binaries
      export PATH="$PATH:/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin"

      # Prompt user for GPU choice
      CHOICE=$(printf "Integrated (680M)\nDiscrete (6500M)" | ${pkgs.wofi}/bin/wofi --dmenu -p "Select GPU" -H 150 -W 300)

      # If user cancelled (Escape/Closed wofi), default to Integrated
      if [ -z "$CHOICE" ] || [[ "$CHOICE" == *"Integrated"* ]]; then
          exec "$@"
      elif [[ "$CHOICE" == *"Discrete"* ]]; then
          exec env DRI_PRIME=1 "$@"
      else
          # Fallback for unexpected input
          exec "$@"
      fi
    '')
  ];

  # Hardware Acceleration
  environment.variables = {
    # VAAPI / VDPAU
    LIBVA_DRIVER_NAME = "radeonsi";
    VDPAU_DRIVER = "radeonsi";
  };
}
