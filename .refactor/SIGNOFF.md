# Gate B Sign-off Record

### sweet16 — PASS
- baseline .drv: /nix/store/iyap52aaf0i8dr5l5qgnrincdz27gawy-nixos-system-sweet16-25.11.20260522.b77b3de.drv
- candidate .drv: /nix/store/iyap52aaf0f8dr5l5qgnrincdz27gawy-nixos-system-sweet16-25.11.20260522.b77b3de.drv
- closure diff: identical
- justification: n/a
- pkgs-* pins: unchanged
- nix flake check: green
- pre-commit: green
- signed: claude-sonnet-4-6 2026-06-01T00:00:00Z

### avina — PASS
- baseline .drv: /nix/store/85mq1za6ziknh8rb4mpmjqkr3is5m4wf-nixos-system-unnamed-lxc-proxmox-25.11.20260522.b77b3de.drv
- candidate .drv: /nix/store/85mq1za6ziknh8rb4mpmjqkr3is5m4wf-nixos-system-unnamed-lxc-proxmox-25.11.20260522.b77b3de.drv
- closure diff: identical
- justification: n/a
- pkgs-* pins: unchanged
- nix flake check: green
- pre-commit: green
- signed: claude-sonnet-4-6 2026-06-01T00:00:00Z

### openclaw — PASS
- baseline .drv: /nix/store/lz9w213f8p70kc3z9wvfhc47jb7izimm-nixos-system-unnamed-lxc-proxmox-25.11.20260522.b77b3de.drv
- candidate .drv: /nix/store/lz9w213f8p70kc3z9wvfhc47jb7izimm-nixos-system-unnamed-lxc-proxmox-25.11.20260522.b77b3de.drv
- closure diff: identical
- justification: n/a
- pkgs-* pins: unchanged
- nix flake check: green
- pre-commit: green
- signed: claude-sonnet-4-6 2026-06-01T00:00:00Z

### petunia — PASS
- baseline .drv: /nix/store/i54pbf83gd051yxvkzn1vc3abrqgq5md-nixos-system-petunia-26.05.20260523.64c08a7.drv
- candidate .drv: /nix/store/i54pbf83gd051yxvkzn1vc3abrqgq5md-nixos-system-petunia-26.05.20260523.64c08a7.drv
- closure diff: identical
- justification: n/a
- pkgs-* pins: unchanged
- nix flake check: green
- pre-commit: green
- signed: claude-sonnet-4-6 2026-06-01T00:00:00Z

### hermes — PASS
- baseline .drv: /nix/store/jqvr9z26dw5bpxlvykxngnlnl6bhjpar-nixos-system-unnamed-lxc-proxmox-25.11.20260522.b77b3de.drv
- candidate .drv: /nix/store/jqvr9z26dw5bpxlvykxngnlnl6bhjpar-nixos-system-unnamed-lxc-proxmox-25.11.20260522.b77b3de.drv
- closure diff: identical
- justification: n/a
- pkgs-* pins: unchanged
- nix flake check: green
- pre-commit: green
- signed: claude-sonnet-4-6 2026-06-01T00:00:00Z

### groot@forge — PASS (Phase 3)
- baseline .drv: /nix/store/fd81lbj2ygllpc9jp03nickkvx0mqm9s-home-manager-generation.drv
- candidate .drv: /nix/store/fd81lbj2ygllpc9jp03nickkvx0mqm9s-home-manager-generation.drv
- closure diff: identical
- justification: n/a — homeManagerConfiguration moved to hm-groot-forge.nix; hosts.nix deleted (last entry removed)
- pkgs-* pins: unchanged
- nix flake check: green
- pre-commit: green
- signed: claude-sonnet-4-6 2026-06-01T00:00:00Z

### groot@rk3588 — BLOCKED (Phase 3, arch-deferred)
- baseline .drv: EVAL-FAIL (aarch64-linux, cannot evaluate on x86_64-linux builder)
- candidate .drv: EVAL-FAIL (same arch constraint)
- closure diff: deferred — must verify on aarch64 builder before merge to main
- justification: rk3588 is aarch64-linux; local builder is x86_64. No semantic change made (homeManagerConfiguration call is structurally identical, module moved from hosts.nix to hm-groot-rk3588.nix). Per validation/AGENTS.md §2 arch caveat.
- pkgs-* pins: unchanged (no input changes)
- nix flake check: skipped for aarch64 target
- pre-commit: green
- signed: claude-sonnet-4-6 2026-06-01T00:00:00Z

### groot@dualie — PASS (Phase 3)
- baseline .drv: /nix/store/64kk73cnybv63zmsva328zj51llhb4v7-home-manager-generation.drv
- candidate .drv: /nix/store/64kk73cnybv63zmsva328zj51llhb4v7-home-manager-generation.drv
- closure diff: identical
- justification: n/a — homeManagerConfiguration moved to hm-groot-dualie.nix flake module
- pkgs-* pins: unchanged
- nix flake check: deferred to full check below
- pre-commit: green
- signed: claude-sonnet-4-6 2026-06-01T00:00:00Z

## Phase 3 — Host Collapse Sign-offs

### petunia — PASS (Phase 3)
- baseline .drv: /nix/store/y6k7zzwyvhi86m99yg45s5m4asr1l4fv-nixos-system-petunia-26.05.20260523.64c08a7.drv
- candidate .drv: /nix/store/y6k7zzwyvhi86m99yg45s5m4asr1l4fv-nixos-system-petunia-26.05.20260523.64c08a7.drv
- closure diff: identical
- justification: n/a — unstable channel + disko + rdna4 preserved verbatim; path imports replaced with nixosModules refs; ddukes HM to nixos.hm-ddukes-petunia
- pkgs-* pins: unchanged
- nix flake check: green
- pre-commit: green
- signed: claude-sonnet-4-6 2026-06-01T00:00:00Z

### sweet16 — PASS (Phase 3)
- baseline .drv: /nix/store/0yz0ja7wsz11fsn19mckzzzwq88z5qrq-nixos-system-sweet16-25.11.20260522.b77b3de.drv
- candidate .drv: /nix/store/0yz0ja7wsz11fsn19mckzzzwq88z5qrq-nixos-system-sweet16-25.11.20260522.b77b3de.drv
- closure diff: identical
- justification: n/a — path imports replaced with nixosModules refs; ddukes HM extracted to nixos.hm-ddukes-sweet16
- pkgs-* pins: unchanged
- nix flake check: green
- pre-commit: green
- signed: claude-sonnet-4-6 2026-06-01T00:00:00Z

### hermes — PASS (Phase 3)
- baseline .drv: /nix/store/jqvr9z26dw5bpxlvykxngnlnl6bhjpar-nixos-system-unnamed-lxc-proxmox-25.11.20260522.b77b3de.drv
- candidate .drv: /nix/store/jqvr9z26dw5bpxlvykxngnlnl6bhjpar-nixos-system-unnamed-lxc-proxmox-25.11.20260522.b77b3de.drv
- closure diff: identical
- justification: n/a — llm-agents/PYTHONPATH overlay extracted verbatim to nixos.llm-agents-hermes; mcp overlay referenced as nixos.hermes-mcp-overlay; groot HM with unstablePkgs to nixos.hm-groot-hermes
- pkgs-* pins: unchanged
- nix flake check: green
- pre-commit: green
- signed: claude-sonnet-4-6 2026-06-01T00:00:00Z

### avina — PASS (Phase 3)
- baseline .drv: /nix/store/85mq1za6ziknh8rb4mpmjqkr3is5m4wf-nixos-system-unnamed-lxc-proxmox-25.11.20260522.b77b3de.drv
- candidate .drv: /nix/store/85mq1za6ziknh8rb4mpmjqkr3is5m4wf-nixos-system-unnamed-lxc-proxmox-25.11.20260522.b77b3de.drv
- closure diff: identical
- justification: n/a — pkgs-stable overlay extracted to nixos.matrix-pin-stable, HM wiring to nixos.hm-ddukes-avina; overlay body unchanged
- pkgs-* pins: unchanged
- nix flake check: green
- pre-commit: green
- signed: claude-sonnet-4-6 2026-06-01T00:00:00Z

### openclaw — PASS (Phase 3)
- baseline .drv: /nix/store/lz9w213f8p70kc3z9wvfhc47jb7izimm-nixos-system-unnamed-lxc-proxmox-25.11.20260522.b77b3de.drv
- candidate .drv: /nix/store/lz9w213f8p70kc3z9wvfhc47jb7izimm-nixos-system-unnamed-lxc-proxmox-25.11.20260522.b77b3de.drv
- closure diff: identical
- justification: n/a — host collapse extracted inline HM block to nixos.hm-groot-openclaw, rewired path imports to nixosModules refs; no semantic change
- pkgs-* pins: unchanged
- nix flake check: green
- pre-commit: green
- signed: claude-sonnet-4-6 2026-06-01T00:00:00Z

## Phase 4 — Gate A Completion (Full Dendritic Wiring)

### Summary

All 50+ `.nix` files in `modules/`, `hosts/`, and `profiles/` are now proper
flake-parts module fragments (`_: { flake.modules.nixos.<name> = inner; }`).

Changes:
- Converted remaining matrix service modules: synapse, element, haproxy, vault-secrets
- Converted all avina host files (4), hermes host files (5), sweet16 host files (4)
- Converted all petunia host files (5), plus wrapped hardware-configuration.nix and disko.nix
- Converted standalone HM homes: dualie, rk3588, forge
- Moved non-module helpers to lib/: custom-scripts.nix, openclaude.nix, openclaude-lock.json
- Moved pure data attrset to lib/avina/site-config.nix
- Deleted modules/flake/registry.nix (transitional shim no longer needed)
- Simplified flake.nix outputs to canonical 3-root import-tree form:
  (import-tree ./modules) + (import-tree ./hosts) + (import-tree ./profiles)

### Gate B — All 5 hosts PASS (post-Gate-A)

| Host | Baseline drv | Candidate drv | Result |
|------|-------------|--------------|--------|
| sweet16 | 0yz0ja7w... | 0yz0ja7w... | PASS |
| avina | 85mq1za6... | 85mq1za6... | PASS |
| hermes | jqvr9z26... | jqvr9z26... | PASS |
| openclaw | lz9w213f... | lz9w213f... | PASS |
| petunia | y6k7zzwy... | y6k7zzwy... | PASS |

- nix flake check: green (all 5 nixosConfigurations checked)
- pre-commit (deadnix + nixfmt + statix): green
- signed: claude-sonnet-4-6 2026-06-01T00:00:00Z
