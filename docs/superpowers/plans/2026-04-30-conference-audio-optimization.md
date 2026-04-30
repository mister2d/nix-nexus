# Conference Audio Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate audio dropouts during video conferencing on the ThinkPad Z16 by reducing EasyEffects processing depth, removing redundant ML noise suppression, and tuning PipeWire real-time scheduling.

**Architecture:** Two new EasyEffects JSON presets (input + output) purpose-built for conferencing, plus PipeWire quantum and WirePlumber suspend-timeout tuning in the existing `sound.nix` module. No changes to existing presets or the `audio-effects.nix` mapping — the `mapFiles` helper auto-discovers new files from the `assets/audio/presets/` directories.

**Tech Stack:** EasyEffects 8.x JSON presets, NixOS/Nix modules, PipeWire, WirePlumber

**Spec:** `docs/superpowers/specs/2026-04-30-conference-audio-optimization-design.md`

---

### Task 1: Create Conference Input Preset

**Files:**
- Create: `assets/audio/presets/input/Z16-Conference-Mic.json`

This preset is derived from `assets/audio/presets/input/Masc_NPR_Voice_plus_NR.json`. It keeps the `deepfilternet#0`, `equalizer#0`, `compressor#0`, and `limiter#0` plugin definitions verbatim, removes `rnnoise#0`, `gate#0`, and `deesser#0` definitions, and updates `plugins_order` to the 4-plugin chain.

- [ ] **Step 1: Create the preset file**

Write `assets/audio/presets/input/Z16-Conference-Mic.json` with this exact content:

```json
{
    "input": {
        "blocklist": [],
        "deepfilternet#0": {
            "attenuation-limit": 100.0,
            "bypass": false,
            "input-gain": 0.0,
            "max-df-processing-threshold": 20.0,
            "max-erb-processing-threshold": 30.0,
            "min-processing-buffer": 0,
            "min-processing-threshold": 5.0,
            "output-gain": 0.0,
            "post-filter-beta": 0.019999999552965164
        },
        "equalizer#0": {
            "balance": 0.1,
            "bypass": false,
            "input-gain": 0.0,
            "left": {
                "band0": {
                    "frequency": 80.0,
                    "gain": 0.0,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 0.7,
                    "slope": "x2",
                    "solo": false,
                    "type": "Hi-pass",
                    "width": 4.0
                },
                "band1": {
                    "frequency": 220.0,
                    "gain": -2.0,
                    "mode": "RLC (MT)",
                    "mute": false,
                    "q": 0.7,
                    "slope": "x1",
                    "solo": false,
                    "type": "Bell",
                    "width": 4.0
                },
                "band2": {
                    "frequency": 350.0,
                    "gain": -2.0,
                    "mode": "BWC (MT)",
                    "mute": false,
                    "q": 1.2,
                    "slope": "x2",
                    "solo": false,
                    "type": "Bell",
                    "width": 4.0
                },
                "band3": {
                    "frequency": 3500.0,
                    "gain": 2.0,
                    "mode": "BWC (BT)",
                    "mute": false,
                    "q": 0.9,
                    "slope": "x2",
                    "solo": false,
                    "type": "Bell",
                    "width": 4.0
                },
                "band4": {
                    "frequency": 10000.0,
                    "gain": 2.0,
                    "mode": "LRX (MT)",
                    "mute": false,
                    "q": 0.7,
                    "slope": "x1",
                    "solo": false,
                    "type": "Hi-shelf",
                    "width": 4.0
                }
            },
            "mode": "IIR",
            "num-bands": 5,
            "output-gain": 0.0,
            "pitch-left": 0.0,
            "pitch-right": 0.0,
            "right": {
                "band0": {
                    "frequency": 80.0,
                    "gain": 0.0,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 0.7,
                    "slope": "x2",
                    "solo": false,
                    "type": "Hi-pass",
                    "width": 4.0
                },
                "band1": {
                    "frequency": 220.0,
                    "gain": -2.0,
                    "mode": "RLC (MT)",
                    "mute": false,
                    "q": 0.7,
                    "slope": "x1",
                    "solo": false,
                    "type": "Bell",
                    "width": 4.0
                },
                "band2": {
                    "frequency": 350.0,
                    "gain": -2.0,
                    "mode": "BWC (MT)",
                    "mute": false,
                    "q": 1.2,
                    "slope": "x2",
                    "solo": false,
                    "type": "Bell",
                    "width": 4.0
                },
                "band3": {
                    "frequency": 3500.0,
                    "gain": 2.0,
                    "mode": "BWC (BT)",
                    "mute": false,
                    "q": 0.9,
                    "slope": "x2",
                    "solo": false,
                    "type": "Bell",
                    "width": 4.0
                },
                "band4": {
                    "frequency": 10000.0,
                    "gain": 2.0,
                    "mode": "LRX (MT)",
                    "mute": false,
                    "q": 0.7,
                    "slope": "x1",
                    "solo": false,
                    "type": "Hi-shelf",
                    "width": 4.0
                }
            },
            "split-channels": false
        },
        "compressor#0": {
            "attack": 15.0,
            "boost-amount": 0.0,
            "boost-threshold": -72.0,
            "bypass": false,
            "dry": -80.01,
            "hpf-frequency": 10.0,
            "hpf-mode": "Off",
            "input-gain": 0.0,
            "input-to-link": 0.0,
            "input-to-sidechain": 0.0,
            "knee": -6.0,
            "link-to-input": 0.0,
            "link-to-sidechain": 0.0,
            "lpf-frequency": 20000.0,
            "lpf-mode": "Off",
            "makeup": 3.0,
            "mode": "Downward",
            "output-gain": 0.0,
            "ratio": 3.0,
            "release": 200.0,
            "release-threshold": -40.0,
            "sidechain": {
                "lookahead": 0.0,
                "mode": "RMS",
                "preamp": 0.0,
                "reactivity": 10.0,
                "source": "Middle",
                "stereo-split-source": "Left/Right",
                "type": "Feed-forward"
            },
            "sidechain-to-input": 0.0,
            "sidechain-to-link": 0.0,
            "stereo-split": false,
            "threshold": -18.0,
            "wet": 0.0
        },
        "limiter#0": {
            "alr": false,
            "alr-attack": 5.0,
            "alr-release": 50.0,
            "attack": 2.0,
            "bypass": false,
            "dithering": "16bit",
            "gain-boost": false,
            "input-gain": 0.0,
            "input-to-link": 0.0,
            "input-to-sidechain": 0.0,
            "link-to-input": 0.0,
            "link-to-sidechain": 0.0,
            "lookahead": 2.0,
            "mode": "Herm Wide",
            "output-gain": 0.0,
            "oversampling": "None",
            "release": 5.0,
            "sidechain-preamp": 0.0,
            "sidechain-to-input": 0.0,
            "sidechain-to-link": 0.0,
            "sidechain-type": "Internal",
            "stereo-link": 100.0,
            "threshold": -1.5
        },
        "plugins_order": [
            "deepfilternet#0",
            "equalizer#0",
            "compressor#0",
            "limiter#0"
        ]
    }
}
```

- [ ] **Step 2: Validate JSON syntax**

Run: `jq . assets/audio/presets/input/Z16-Conference-Mic.json > /dev/null`
Expected: Exit 0, no output (valid JSON)

- [ ] **Step 3: Verify plugin chain reduction**

Run: `jq '.input.plugins_order | length' assets/audio/presets/input/Z16-Conference-Mic.json`
Expected: `4`

Run: `jq '.input | keys | map(select(startswith("rnnoise") or startswith("gate") or startswith("deesser")))' assets/audio/presets/input/Z16-Conference-Mic.json`
Expected: `[]` (no removed plugins present)

- [ ] **Step 4: Commit**

```bash
git add assets/audio/presets/input/Z16-Conference-Mic.json
git commit -m "feat(audio): add Z16-Conference-Mic input preset for low-latency conferencing"
```

---

### Task 2: Create Conference Output Preset

**Files:**
- Create: `assets/audio/presets/output/enhanced/Z16-Conference.json`

This preset is derived from `assets/audio/presets/output/enhanced/Z16-Voice-Balanced.json`. It keeps all plugin definitions and `plugins_order` identical, but changes the limiter `oversampling` from `"Half x4(3L)"` to `"None"` and `gain-boost` from `true` to `false`.

- [ ] **Step 1: Create the preset file**

Write `assets/audio/presets/output/enhanced/Z16-Conference.json` with this exact content:

```json
{
    "output": {
        "blocklist": [],
        "convolver#0": {
            "bypass": false,
            "input-gain": 0.0,
            "output-gain": 0.0,
            "kernel-name": "Dolby-Voice-Balanced",
            "ir-width": 100,
            "autogain": false
        },
        "plugins_order": [
            "convolver#0",
            "equalizer#1",
            "exciter#0",
            "autogain#0",
            "limiter#0"
        ],
        "equalizer#1": {
            "bypass": false,
            "input-gain": 0.0,
            "output-gain": 0.0,
            "mode": "IIR",
            "num-bands": 1,
            "split-channels": false,
            "left": {
                "band0": {
                    "frequency": 2500.0,
                    "gain": 1.12,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 0.7,
                    "slope": "x1",
                    "solo": false,
                    "type": "Bell",
                    "width": 4.0
                }
            },
            "right": {
                "band0": {
                    "frequency": 2500.0,
                    "gain": 1.12,
                    "mode": "RLC (BT)",
                    "mute": false,
                    "q": 0.7,
                    "slope": "x1",
                    "solo": false,
                    "type": "Bell",
                    "width": 4.0
                }
            }
        },
        "limiter#0": {
            "bypass": false,
            "input-gain": 0.0,
            "output-gain": 0.0,
            "mode": "Herm Thin",
            "oversampling": "None",
            "dithering": "None",
            "sidechain-type": "Internal",
            "lookahead": 1.0,
            "attack": 1.0,
            "release": 5.0,
            "threshold": -1.0,
            "gain-boost": false,
            "stereo-link": 100.0,
            "alr": false,
            "sidechain-preamp": 0.0
        },
        "autogain#0": {
            "bypass": false,
            "input-gain": 0.0,
            "output-gain": 0.0,
            "maximum-history": 15,
            "reference": "Geometric Mean (MSI)",
            "silence-threshold": -70.0,
            "target": -14.0
        },
        "exciter#0": {
            "bypass": false,
            "input-gain": -2.0,
            "output-gain": 0.0,
            "amount": 5.0,
            "harmonics": 8.0,
            "scope": 5500.0,
            "ceil": 16000.0,
            "ceil-active": false,
            "blend": 0.0
        }
    }
}
```

- [ ] **Step 2: Validate JSON syntax**

Run: `jq . assets/audio/presets/output/enhanced/Z16-Conference.json > /dev/null`
Expected: Exit 0, no output (valid JSON)

- [ ] **Step 3: Verify limiter changes against source**

Run: `jq '.output."limiter#0" | {oversampling, "gain-boost"}' assets/audio/presets/output/enhanced/Z16-Conference.json`
Expected:
```json
{
  "oversampling": "None",
  "gain-boost": false
}
```

Run: `jq '.output."limiter#0" | {oversampling, "gain-boost"}' assets/audio/presets/output/enhanced/Z16-Voice-Balanced.json`
Expected (confirms difference from source):
```json
{
  "oversampling": "Half x4(3L)",
  "gain-boost": true
}
```

- [ ] **Step 4: Commit**

```bash
git add assets/audio/presets/output/enhanced/Z16-Conference.json
git commit -m "feat(audio): add Z16-Conference output preset with reduced limiter overhead"
```

---

### Task 3: Tune PipeWire Quantum and WirePlumber Suspend Timeout

**Files:**
- Modify: `modules/hardware/thinkpad-z16/sound.nix:52-59` (quantum settings)
- Modify: `modules/hardware/thinkpad-z16/sound.nix:38-44` (internal mic rule)

Two changes to this file: reduce the PipeWire clock quantum from 1024→512 and min-quantum from 512→256, and add `session.suspend-timeout-seconds = 5` to the internal microphone WirePlumber rule.

- [ ] **Step 1: Update PipeWire quantum settings**

In `modules/hardware/thinkpad-z16/sound.nix`, replace the quantum block (lines 52-59):

```nix
    # Speaker-optimized settings (Balanced latency/power)
    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 1024;
        "default.clock.min-quantum" = 512;
        "default.clock.max-quantum" = 8192;
      };
    };
```

with:

```nix
    # Real-time conferencing and playback (tighter deadline for lighter plugin chains)
    extraConfig.pipewire."92-low-latency" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 512;
        "default.clock.min-quantum" = 256;
        "default.clock.max-quantum" = 8192;
      };
    };
```

- [ ] **Step 2: Add suspend timeout to internal mic rule**

In `modules/hardware/thinkpad-z16/sound.nix`, replace the internal mic rule (lines 37-45):

```nix
            {
              # Internal microphones: Fallback priority
              matches = [ [ { "node.name" = "~alsa_input.pci-*"; } ] ];
              actions = {
                update-props = {
                  "priority.session" = 1000;
                  "priority.driver" = 1000;
                };
              };
            }
```

with:

```nix
            {
              # Internal microphones: Fallback priority
              matches = [ [ { "node.name" = "~alsa_input.pci-*"; } ] ];
              actions = {
                update-props = {
                  "priority.session" = 1000;
                  "priority.driver" = 1000;
                  "session.suspend-timeout-seconds" = 5;
                };
              };
            }
```

- [ ] **Step 3: Validate nix syntax**

Run: `nix-instantiate --parse modules/hardware/thinkpad-z16/sound.nix > /dev/null`
Expected: Exit 0, no output (valid nix syntax)

- [ ] **Step 4: Run pre-commit checks**

Run: `nixfmt --check modules/hardware/thinkpad-z16/sound.nix; deadnix --fail modules/hardware/thinkpad-z16/sound.nix; statix check modules/hardware/thinkpad-z16/sound.nix`
Expected: All pass (exit 0)

- [ ] **Step 5: Commit**

```bash
git add modules/hardware/thinkpad-z16/sound.nix
git commit -m "fix(audio): reduce PipeWire quantum and add internal mic suspend timeout"
```
