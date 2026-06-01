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

## Phase 3 — Host Collapse Sign-offs

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
