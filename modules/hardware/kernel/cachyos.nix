_: {
  flake.modules.nixos.hardware-kernel-cachyos =
    {
      inputs,
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.nix-nexus.kernel.cachyos;

      # Canonical attribute name map for BORE-scheduled variants.
      # Source: package tree in upstream README.
      # NOTE: x86_64-v2 variants have no binary cache per upstream README.
      #       "Note that due to build capacity limitations, I do not build
      #        kernel variants with x86_64-v2 CPU optimization."
      # The map covers all cached BORE variants.
      boreVariantAttr = {
        "x86_64-v1" = "linux-cachyos-bore";
        "x86_64-v3" = "linux-cachyos-bore-x86_64-v3";
        "x86_64-v4" = "linux-cachyos-bore-x86_64-v4";
        "zen4" = "linux-cachyos-bore-zen4";
      };

      # The linuxPackages wrapper for the selected BORE variant.
      # e.g. "linux-cachyos-bore-x86_64-v3" → "linuxPackages-cachyos-bore-x86_64-v3"
      linuxPackagesAttr =
        let
          base = boreVariantAttr.${cfg.processorOpt};
        in
        lib.replaceStrings [ "linux-cachyos" ] [ "linuxPackages-cachyos" ] base;

    in
    {
      options.nix-nexus.kernel.cachyos = {

        enable = lib.mkEnableOption "CachyOS kernel (performance-optimized Linux with x86_64 microarch tuning)";

        processorOpt = lib.mkOption {
          type = lib.types.enum [
            "x86_64-v1"
            "x86_64-v3"
            "x86_64-v4"
            "zen4"
          ];
          default = "x86_64-v3";
          description = ''
            Microarchitecture optimization level. Must not exceed the host CPU's feature set.
            x86_64-v2 is intentionally omitted — upstream Hydra does not build it.

              Ryzen 6000 / Zen 3+ (sweet16): x86_64-v3  ← AVX2 max; no AVX-512
              Ryzen 7000 / Zen 4+:           zen4
              Xeon Ice Lake / Sapphire Rapids (verify): x86_64-v4 (has AVX-512)
              Xeon Skylake-SP / Broadwell-EP: x86_64-v3 (no AVX-512)

            For variant = "server" with enableCustomBuild = false, this option is
            ignored — no per-arch server binaries exist upstream.
            Set enableCustomBuild = true to apply this to the server variant.

            Setting a level above the CPU's capability causes an illegal instruction
            boot failure. Verify with: grep -m1 flags /proc/cpuinfo | grep -o "avx512\|avx2"
          '';
        };

        variant = lib.mkOption {
          type = lib.types.enum [
            "bore"
            "server"
          ];
          default = "bore";
          description = ''
            Kernel variant to use.

              bore   — BORE scheduler, 1000Hz, full preemption. Desktop/interactive. (default)
              server — EEVDF scheduler, 300Hz, no preemption. Server/LLM inference.

            When variant = "server" and enableCustomBuild = false, processorOpt is ignored
            (no pre-built per-arch server variants upstream). Set enableCustomBuild = true
            to also apply processorOpt (e.g. x86_64-v3) to the server kernel.
          '';
        };

        enableZfs = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Route boot.zfs.package to config.boot.kernelPackages.zfs_cachyos.
            Must be true on any host where boot.supportedFilesystems.zfs = true.

            This uses ZFS Pattern A (direct attribute access on the pre-built linuxPackages
            attrset). This pattern is safe because boot.kernelPackages is set to a pre-built
            attrset provided by the overlay, not a custom packagesFor result.

            If you later switch to an override-based kernel (enableCustomBuild = true),
            Pattern B is required — see the comment in the config block below.
          '';
        };

        enableCustomBuild = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Apply override-based customizations (bbr3, acpiCall, hugepageMode).

            WARNING: Any override produces a new derivation hash. The result will NOT
            match the Hydra-built binary. Nix will fall back to building the kernel
            from source (~30–60 min on sweet16). Enable only after the binary cache
            configuration is confirmed working and you have time for a local build.

            When enableCustomBuild = true, ZFS wiring switches automatically to
            Pattern B (packagesFor + .extend) to maintain ABI pairing.
          '';
        };

        enableBbr3 = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "BBR3 TCP. Only applied when enableCustomBuild = true.";
        };

        enableAcpiCall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            CachyOS ACPI call patches. Useful on ThinkPads for dGPU power gating and
            ThinkPad-specific EC/charging ACPI method access.
            Only applied when enableCustomBuild = true.
          '';
        };

        hugepageMode = lib.mkOption {
          type = lib.types.enum [
            "always"
            "madvise"
            "never"
          ];
          default = "madvise";
          description = ''
            Transparent Hugepage mode. Only applied when enableCustomBuild = true.
            "madvise" reduces idle memory pressure on a battery-powered laptop while
            still benefiting workloads that call madvise(MADV_HUGEPAGE) — llama.cpp
            does this for weight tensors.
          '';
        };

      };

      config = lib.mkMerge [
        (lib.mkIf cfg.enable {

          assertions = [
            {
              assertion = pkgs.stdenv.hostPlatform.isx86_64;
              message =
                "nix-nexus.kernel.cachyos: CachyOS kernels are x86_64 only. "
                + "Do not import this module on rk3588 or other aarch64 hosts.";
            }
            {
              assertion = cfg.variant != "bore" || cfg.processorOpt != "x86_64-v2";
              message =
                "nix-nexus.kernel.cachyos: x86_64-v2 has no binary cache for bore variant. "
                + "Use x86_64-v1 (generic) or x86_64-v3 (if CPU supports AVX2).";
            }
          ];

          # -------------------------------------------------------------------------
          # Overlay.
          # overlays.pinned: locks kernel to the exact version built by upstream Hydra CI,
          # guaranteeing the store hash matches the binary cache entry.
          # -------------------------------------------------------------------------
          nixpkgs.overlays = [
            inputs.nix-cachyos-kernel.overlays.pinned
          ];

          # -------------------------------------------------------------------------
          # Kernel selection — four paths across variant × enableCustomBuild.
          # boot.kernelPackages is types.unspecified; its apply function calls
          # .extend on the value directly. lib.mkMerge is NOT safe here because
          # mergeDefaultOption passes the merge-marker attrset straight to apply.
          # Use if/then/else so the value is the actual linuxPackages scope.
          # -------------------------------------------------------------------------
          # hardware-z16 sets boot.kernelPackages with mkOverride 900 to pin
          # linuxPackages_6_12. mkForce wins on hosts that import both modules.
          boot.kernelPackages = lib.mkForce (
            if cfg.variant == "server" && !cfg.enableCustomBuild then
              # SERVER PATH A: pre-built server kernel from overlay. No per-arch
              # linuxPackages-cachyos-server exists, so packagesFor wraps it.
              let
                baseKernel = pkgs.cachyosKernels.linux-cachyos-server;
              in
              (pkgs.linuxKernel.packagesFor baseKernel).extend (
                _final: _prev:
                lib.optionalAttrs cfg.enableZfs {
                  zfs_cachyos = pkgs.cachyosKernels.zfs-cachyos.override { kernel = baseKernel; };
                }
              )
            else if cfg.variant == "server" && cfg.enableCustomBuild then
              # SERVER PATH B: server kernel with CPU arch override → local build.
              let
                baseKernel = pkgs.cachyosKernels.linux-cachyos-server.override {
                  inherit (cfg) processorOpt;
                };
              in
              (pkgs.linuxKernel.packagesFor baseKernel).extend (
                _final: _prev:
                lib.optionalAttrs cfg.enableZfs {
                  zfs_cachyos = pkgs.cachyosKernels.zfs-cachyos.override { kernel = baseKernel; };
                }
              )
            else if !cfg.enableCustomBuild then
              # BORE PATH A: pre-built attrset from overlay; binary cache hit guaranteed.
              pkgs.cachyosKernels.${linuxPackagesAttr}
            else
              # BORE PATH B: override-based build; produces a new hash → local build required.
              let
                baseKernel = pkgs.cachyosKernels.${boreVariantAttr.${cfg.processorOpt}}.override {
                  bbr3 = cfg.enableBbr3;
                  acpiCall = cfg.enableAcpiCall;
                  hugepage = cfg.hugepageMode;
                };
              in
              (pkgs.linuxKernel.packagesFor baseKernel).extend (
                _final: _prev: {
                  zfs_cachyos = lib.mkIf cfg.enableZfs (
                    pkgs.cachyosKernels.zfs-cachyos.override { kernel = baseKernel; }
                  );
                }
              )
          );

          # -------------------------------------------------------------------------
          # ZFS wiring.
          # -------------------------------------------------------------------------
          boot.zfs.package = lib.mkIf cfg.enableZfs config.boot.kernelPackages.zfs_cachyos;

        })

        # -------------------------------------------------------------------------
        # Binary cache substituter (unconditional).
        # Outside the mkIf block so the cache is configured before the kernel is
        # enabled — first nixos-rebuild always hits the cache regardless of enable state.
        #
        # Upstream publishes exactly one cache, fed by the same Hydra CI that builds
        # the kernels and the ABI-paired zfs_cachyos:
        # https://github.com/xddxdd/nix-cachyos-kernel#binary-cache
        # -------------------------------------------------------------------------
        {
          nix.settings = {
            substituters = lib.mkAfter [
              "https://attic.xuyh0120.win/lantian"
            ];
            trusted-public-keys = lib.mkAfter [
              "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
            ];
          };
        }
      ];
    };
}
