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

  environment.systemPackages = with pkgs; [
    nvtopPackages.amd
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
