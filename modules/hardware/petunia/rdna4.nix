# Merged into: flake.modules.nixos.hardware-petunia
# Configures: dual RDNA4 R9700 graphics and ROCm compute via nix-rdna4.
# Imported by: hosts/petunia/default.nix (petunia-default).
{ inputs, ... }:
{
  flake.modules.nixos.hardware-petunia = {
    # Dual R9700 (RDNA4, gfx1201) graphics + ROCm compute wiring.
    #
    # nix-rdna4 supplies the amdgpu driver and early KMS, kernel params, the
    # Mesa/RADV and ROCm CLR graphics stack, the /opt/rocm sysroot, render/kfd
    # udev rules, LACT with overdrive, ROCm session variables, and GPU
    # diagnostics packages.
    #   rdna4-full  base, rocm, power, build-env (opt-in, left disabled), limits
    #   rdna4-dual  both GPUs visible to HSA, pcie_bus_config=performance
    #
    # ROCm 7.x recognizes gfx1201 natively. HSA_OVERRIDE_GFX_VERSION forces
    # the wrong ISA at the HSA runtime level and causes wrong code
    # generation. This module leaves it unset.
    #
    # The system closure excludes the HIP/Vulkan build toolchain. Inference
    # projects consume github:tenarches/nix-rdna4 devShells (llama-rocm /
    # llama-vulkan) directly.
    imports = [
      inputs.rdna4.nixosModules.rdna4-full
      inputs.rdna4.nixosModules.rdna4-dual
    ];

    # The rocm-sysroot overlay backs the /opt/rocm symlink.
    nixpkgs.overlays = [ inputs.rdna4.overlays.rocm-sysroot ];

    rdna4 = {
      dualGpu.enable = true;
      # memlock unlimited and nofile 65536 for render/video, plus
      # vm.max_map_count for large model mappings.
      limits.enable = true;
    };
  };
}
