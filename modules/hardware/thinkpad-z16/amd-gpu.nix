# Merged into: flake.modules.nixos.hardware-z16
# Configures: AMD graphics drivers, GPU power limits, and the hybrid GPU launcher.
# Imported by: hosts/sweet16/default.nix (sweet16-default).
_: {
  flake.modules.nixos.hardware-z16 =
    { pkgs, ... }:
    {
      # Graphics
      hardware.graphics = {
        enable = true;
        enable32Bit = true; # Required for some meeting/web effects and game compatibility
        extraPackages = with pkgs; [
          rocmPackages.clr.icd
        ];
      };

      services = {
        xserver.videoDrivers = [ "amdgpu" ];

        # GPU Switching
        supergfxd.enable = false;

        # GPU Power Management
        # The ThinkPad Z16 Gen 1 (Radeon 6500M / 680M) has a VBIOS-enforced 30W power limit.
        udev.extraRules = ''
          SUBSYSTEM=="hwmon", DRIVER=="amdgpu", ATTR{power1_cap_max}!="", ATTR{power1_cap}="$attr{power1_cap_max}"
        '';
      };

      environment.systemPackages = with pkgs; [
        supergfxctl
        nvtopPackages.amd
        pkgs.amdgpu_top
        clinfo
        rocmPackages.rocminfo
        (pkgs.writeShellScriptBin "gpu-launch" ''
          # GPU Selector for Hybrid AMD Systems
          # Usage: gpu-launch <command> [args...]

          if [ $# -eq 0 ]; then
              exit 1
          fi

          # Ensure we can find system binaries
          export PATH="$PATH:/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin"

          # Prompt user for GPU choice
          CHOICE=$(printf "Integrated\nDiscrete" | ${pkgs.wofi}/bin/wofi --dmenu -p "Select GPU" -H 150 -W 300)

          # If user cancelled (Escape/Closed wofi), default to Integrated
          if [ -z "$CHOICE" ] || [[ "$CHOICE" == *"Integrated"* ]]; then
              exec "$@"
          elif [[ "$CHOICE" == *"Discrete"* ]]; then
              # Use standard DRI_PRIME=1 for the discrete GPU
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
        # ROCm RDNA2 Override (gfx1030/1031 support)
        HSA_OVERRIDE_GFX_VERSION = "10.3.0";
      };
    };
}
