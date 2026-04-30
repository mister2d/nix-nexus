# Conference Audio Optimization: ThinkPad Z16 Gen 1

This spec addresses audio dropouts (xruns, multi-second input cutouts) during browser-based video conferencing on the ThinkPad Z16. The root cause is excessive real-time DSP load from triple-stacked noise suppression, deep plugin chains, and limiter oversampling competing for PipeWire quantum deadlines.

## Problem Analysis

The current conferencing audio path chains three independent noise suppression engines in series:

| Layer | Engine | Type |
|:---:|:---|:---|
| 1 | RNNoise (`rnnoise#0`) | ML inference (EasyEffects input preset) |
| 2 | DeepFilterNet (`deepfilternet#0`) | ML inference (EasyEffects input preset) |
| 3 | Browser WebRTC NS | ML inference (Google Meet / Teams) |

The `Masc_NPR_Voice_plus_NR` input preset runs a 7-plugin chain (`rnnoise → deepfilternet → gate → EQ → compressor → deesser → limiter`), and the `Z16-Music-Balanced` output preset applies a music-optimized convolver IR with 4x limiter oversampling. Under transient CPU load, DeepFilterNet exhibits [known latency accumulation](https://github.com/wwmm/easyeffects/issues/3851) where the Real-Time Factor climbs above 1.0 and does not recover without a restart.

**Observed symptoms:**
- Brief crackles and pops (xruns from buffer underruns)
- Multi-second input cutouts reported by remote participants (pipeline stalls from RTF > 1.0)
- Symptoms persist across both USB (HyperX SoloCast) and internal microphone paths

## Solution

### 1. Conference Input Preset

**File:** `assets/audio/presets/input/Z16-Conference-Mic.json`

A 4-plugin chain purpose-built for real-time conferencing:

```
deepfilternet#0 → equalizer#0 → compressor#0 → limiter#0
```

| Removed Plugin | Rationale |
|:---|:---|
| `rnnoise#0` | Redundant with DeepFilterNet; stacking causes [xruns](https://github.com/wwmm/easyeffects/issues/1021) and latency accumulation |
| `gate#0` | Browser WebRTC VAD handles silence detection; double-gating clips speech onsets |
| `deesser#0` | Sibilance control is irrelevant at conferencing codec bitrates |

**Retained processing:**
- **DeepFilterNet** — ML noise suppression (100dB attenuation limit, 20/30 ERB/DF thresholds)
- **Equalizer** — 5-band voice shaping (80Hz HPF, -2dB mud cuts at 220/350Hz, +2dB presence at 3.5kHz, +2dB air shelf at 10kHz)
- **Compressor** — dynamics control (3:1 ratio, -18dB threshold, 3dB makeup)
- **Limiter** — safety ceiling with oversampling set to `None` (speech transients do not require anti-aliasing precision)

### 2. Conference Output Preset

**File:** `assets/audio/presets/output/enhanced/Z16-Conference.json`

Derived from `Z16-Voice-Balanced` with conferencing-specific modifications:

```
convolver#0 → equalizer#1 → exciter#0 → autogain#0 → limiter#0
```

| Setting | Voice-Balanced | Conference | Rationale |
|:---|:---|:---|:---|
| Convolver IR | `Dolby-Voice-Balanced` | `Dolby-Voice-Balanced` | Voice-tuned IR (replaces `Dolby-Music-Balanced` previously used during calls) |
| Limiter oversampling | `Half x4(3L)` | `None` | Eliminates 4x CPU cost; speech does not benefit from oversampling |
| Limiter gain-boost | `true` | `false` | Prevents level pumping that conflicts with browser AGC |

### 3. PipeWire Real-Time Tuning

**File:** `modules/hardware/thinkpad-z16/sound.nix`

**Quantum reduction:**

| Parameter | Current | New | Effect |
|:---|:---|:---|:---|
| `default.clock.quantum` | 1024 (21.3ms) | 512 (10.7ms) | Tighter scheduling deadline; lighter chain fits comfortably |
| `default.clock.min-quantum` | 512 | 256 | Allows PipeWire to auto-adapt to lower latency when possible |
| `default.clock.max-quantum` | 8192 | 8192 | Unchanged; safety valve for heavy workloads |

**WirePlumber internal mic suspend timeout:**

The internal microphone rule (`~alsa_input.pci-*`) currently lacks a suspend timeout, using PipeWire's default. This causes rapid suspend/resume cycles that manifest as cold-start dropouts. Adding `session.suspend-timeout-seconds = 5` (matching the HyperX SoloCast rule) prevents this.

### 4. Browser-Side Configuration

With EasyEffects handling noise suppression and dynamics, the browser's redundant processing should be disabled to prevent triple-stacking:

- **Google Meet:** Settings → Audio → disable "Noise cancellation"
- **Microsoft Teams (web):** Settings → Devices → Noise suppression → "Off" or "Low"
- **Echo cancellation:** Leave enabled in both apps. EasyEffects does not provide AEC, and WebRTC's implementation is well-suited for browser-to-speaker feedback loops.

### Usage

1. Before a call, switch EasyEffects presets: input → `Z16-Conference-Mic`, output → `Z16-Conference`
2. Disable browser-side noise cancellation per Section 4
3. After the call, restore preferred presets (`Masc_NPR_Voice_plus_NR` + `Z16-Music-Balanced`) for music and media playback

## Affected Modules

| File | Change |
|:---|:---|
| `assets/audio/presets/input/Z16-Conference-Mic.json` | New file |
| `assets/audio/presets/output/enhanced/Z16-Conference.json` | New file |
| `modules/hardware/thinkpad-z16/sound.nix` | Quantum reduction, internal mic suspend timeout |

No existing presets or configurations are modified. The conference presets are additive.
