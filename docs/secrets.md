# Secrets management

nix-nexus manages secrets across three surfaces with three different tools. They are not
alternatives to one another — each covers a case the others cannot.

| Surface | Tool | Decrypted where | Needs network? |
|---|---|---|---|
| System / service secrets on NixOS hosts | **sops-nix** | activation time → `/run/secrets` (tmpfs) | no |
| Developer / CI / user-runtime secrets | **secretspec** | process launch, in-memory | depends on provider |
| Short-TTL and renewed credentials on avina | **Vault + vault-agent** | `/run/secrets`, `/run/certs` | yes |

## Which tool for a new secret

1. **Does a systemd system service read it from a file?** → sops-nix.
2. **Does a developer, the dev shell, or CI need it?** → secretspec.
3. **Does it expire and need renewal (LE certs, short-TTL tokens)?** → Vault, via vault-agent
   templates on avina.
4. **Is it a user-level file under `$HOME` on a NixOS host?** → sops-nix Home Manager module.

Vault deliberately stays narrow. Hosts must boot and run with Vault down, so nothing in the
activation path depends on it. Vault's jobs are: the SSH CA for deploys, LE certificate
distribution, and short-TTL renewal on avina.

## Layer 1 — sops-nix

Secrets are decrypted at activation into `/run/secrets`, which is tmpfs, so nothing lands on disk.
There is no daemon, no network call, and no bootstrap credential.

**Host identity is the SSH host key.** `core-sops` sets
`sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]`, so each host decrypts with an age key
derived from a key it already has. Onboarding a host means adding one recipient line, not
distributing new key material.

### Files

- `.sops.yaml` — recipients and creation rules. Not secret.
- `secrets/<hostname>.yaml` — encrypted, committed. Safe to commit; only the listed recipients can
  decrypt it.
- `modules/core/sops.nix` — registry key `core-sops`. Declares
  `nix-nexus.secrets.sops.hostFile` and the fleet-wide sops policy.

`hostFile` defaults to `null`, which leaves sops-nix completely inert. A host that declares no
secrets is byte-identical to one without the module.

### Adding a secret to a host

```bash
# 1. Point the host at its secrets file (once per host), in hosts/<host>/default.nix:
#      nix-nexus.secrets.sops.hostFile = ../../secrets/<host>.yaml;

# 2. Create or edit the encrypted file. sops picks recipients from .sops.yaml.
sops secrets/<host>.yaml

# 3. Declare the secret, in hosts/<host>/default.nix:
#      sops.secrets.my-secret = {
#        owner = "someuser";
#        group = "somegroup";
#        mode  = "0400";
#      };
#    It appears at /run/secrets/my-secret.

# 4. Order any consumer after secret installation:
#      systemd.services.myservice.after = [ "sops-install-secrets.service" ];
```

`sops-install-secrets.service` is a `oneshot` in `sysinit.target` with `RemainAfterExit = true`, so
ordering after it is safe for the whole boot.

### Onboarding a host

```bash
# Derive the host's age recipient from its public SSH host key — no host access needed.
ssh-keyscan -t ed25519 <host>.home.lan | cut -d' ' -f2- | ssh-to-age
```

Add the result to `.sops.yaml` under `keys:` and reference it in a `creation_rules` entry. Then
`sops updatekeys secrets/<host>.yaml` to re-encrypt existing files to the new recipient.

### Rotating

- **A secret's value**: `sops secrets/<host>.yaml`, edit, redeploy.
- **A host's key** (reinstall, or host key regenerated): re-derive the recipient, update
  `.sops.yaml`, run `sops updatekeys` on every file that host reads, redeploy.
- **The admin key**: update `.sops.yaml`, `sops updatekeys` across `secrets/`, commit.

## Layer 2 — secretspec

`secretspec.toml` at the repo root declares **what** secrets exist; the provider decides **where**
they live. The same declaration serves a workstation (keyring), a headless host (Vault), and CI.

### Version constraints — important

The devshell ships secretspec from `nixpkgs-unstable`. Measured against the built binary:

| | |
|---|---|
| Version | **0.13.0** (stable channel has 0.10.1) |
| Providers available | `vault`, `keyring`, `dotenv`, `env` |
| Providers **not** available | `sops`, `age`, `systemd-credential` — 0.17-only, report `Provider backend not found` |
| `[scopes]` | 0.17-only, unavailable |
| `require_reason` policy | **active** — every read needs `--reason "<why>"` or `SECRETSPEC_REASON` |

`github:cachix/secretspec` publishes no `flake.nix`, and no nixpkgs commit carries 0.17 yet, so 0.17
features cannot be adopted without vendoring a Rust build. Revisit when nixpkgs catches up.

### Provider choice by host

- **sweet16, petunia** — `keyring`. A Secret Service daemon is running (gnome-keyring, via
  `modules/core/security.nix`).
- **hermes, forge, rk3588, CI** — `vault`. No keyring daemon on these.

### Usage

Load secrets at process launch, not into the shell environment:

```bash
secretspec run --reason "why you need them" -- your-command
```

Note that eval-time injection (`config.secretspec.secrets` in devenv) is **unavailable here**:
devenv asserts `!(secretspec.enable && devenv.flakesIntegration)`, and nix-nexus consumes devenv via
`inputs.devenv.flakeModule`. Runtime loading is the only option, and is the upstream-recommended
practice regardless.

### What is wired today

The Claude Code Stop hook (`.claude/hooks/langfuse_hook.py`, declared in
`modules/flake/checks.nix`) runs under `secretspec run`, so its Langfuse credentials reach that
process only and never enter the shell environment.

All three of its secrets are declared **optional** and **keyring-only**, both deliberately:

- *Optional* — the hook is elective telemetry. Marking them required would make `secretspec run`
  exit non-zero and skip the hook on every turn for anyone who has not configured Langfuse.
- *Keyring-only* — the hook fires on every Stop. A provider list falling back to Vault would mean a
  network round-trip per turn whenever the keyring misses.

### Storing a value

```bash
secretspec set LANGFUSE_SECRET_KEY                     # prompts, writes to the keyring
secretspec check --reason "audit"                      # declaration status
secretspec run --reason "why" -- env | grep LANGFUSE   # confirm resolution
```

`--reason` is mandatory: 0.13 enforces a `require_reason` policy (it defaults to `agents`; set
`require_reason = false` under `[project]` to disable). It applies to `check` and `get` too, not just
`run`.

Note `secretspec check` reports optional secrets as `optional` **without probing whether they
resolve** — "0 found, 0 missing, 3 optional" does not mean they are unset. Use `run` to test actual
resolution.

To use Vault instead of the keyring for a given secret — required on headless hosts, which have no
Secret Service daemon — set `providers = ["home_vault"]` on that secret. Values land at
`kv-v2/secretspec/{project}/{profile}/{key}` under field `value`.

### Verifying a rendered secret without exposing it

Never `cat` a rendered secret or a decrypted sops value to check it. Error
paths leak too: `sops decrypt` prints the offending plaintext scalar when a
value fails to parse, so route stderr away or test the exit status alone.

To confirm a rendered file matches its source, compare hashes on both ends:

```bash
# on the host
grep -m1 '^VAR=' file | cut -d= -f2- | tr -d '\n' | sha256sum | cut -c1-12
# locally
sops decrypt --extract '["section"]["key"]' secrets/<host>.yaml | tr -d '\n' | sha256sum | cut -c1-12
```

Counting variables or checking file permissions verifies *structure*, not
*content* — a wrong value passes both. Only the hash comparison proves the
rendered value is correct.

### hermes gateway env files

`sops.templates` renders `~/.hermes/.env` and
`~/.hermes/profiles/coding-local/.env`, because hermes-agent loads
`$HERMES_HOME/.env` itself with `override=True` and outranks anything
systemd injects. Only sensitive values are encrypted; endpoints and toggles
stay readable in `hosts/hermes/secrets.nix`.

Both gateways are **user** units, so `restartUnits` (system units only) does
not reach them. After rotating any of these secrets:

```bash
systemctl --user restart hermes-gateway hermes-gateway-coding-local
```

Rotating `MATRIX_ACCESS_TOKEN` additionally requires wiping the crypto store
— see `docs/hermes.md`. Historical E2EE messages become permanently
undecryptable; that is inherent to `kill-sessions`, not a fault.

## Layer 3 — TPM2 and disk encryption

The sops age key is the SSH host key, which lives on the root filesystem. So **whatever protects the
root disk transitively protects every sops secret at rest.** There is deliberately no bespoke
TPM-sealing of the age key: sops-nix has no supported TPM path, PCR values change on firmware
updates, and sealing would forfeit remote re-keying.

### petunia — plain TPM2 auto-unseal (accepted risk)

petunia enrolls LUKS2 against **PCR 0 only**, because Secure Boot is inactive and PCR 7 is therefore
meaningless. PCR 0 measures firmware but **not** the kernel, initrd, or cmdline, so a modified initrd
on the same hardware would still unseal.

This is a **consciously accepted risk**, not an oversight: petunia is a physically-controlled desktop
where the threat model is remote compromise, not device theft. See `docs/petunia.md` for the
enrollment and re-enrollment procedure.

### sweet16 — TPM2 with PIN, mandatory

> **sweet16 must never use plain TPM2 auto-unseal.**

sweet16 is a laptop and its threat model is physical theft. Plain auto-unseal means power-on equals
unlocked disk — including the SSH host key, the sops age key, and everything in `/run/secrets`. The
only sanctioned enrollment form is:

```bash
systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0 --tpm2-with-pin=yes <device>
```

The PIN is what closes the theft gap. A short PIN is safe here because the TPM rate-limits guesses
(anti-hammering) — unlike a passphrase, which an attacker brute-forces offline against the LUKS KDF.
Keyslot 0 remains a passphrase fallback.

**This flag must survive re-enrollment.** sweet16's PCR 0 keyslot breaks on every firmware update,
which Lenovo ships frequently via fwupd, and the re-enroll is hand-typed. The failure mode is copying
petunia's command and silently dropping `--tpm2-with-pin=yes`.

Device paths differ between the two hosts. sweet16 uses `/dev/disk/by-partlabel/DISK_LUKS`. petunia
must use `/dev/nvme0n1p2` because disko labels its partition `disk-main-DISK_LUKS`, so
`by-partlabel/DISK_LUKS` does not resolve there. Confirm with `lsblk -o NAME,PARTLABEL` before
enrolling.

Verify an enrollment carries the PIN:

```bash
cryptsetup token export --token-id 0 /dev/disk/by-partlabel/DISK_LUKS
```

`"tpm2-pin": true` and `"tpm2-pcrs": [0]` are the fields that matter. A token without `tpm2-pin`
auto-unseals on power-on and must be removed with `systemd-cryptenroll --wipe-slot=tpm2` and redone.

### Hosts without a TPM

avina and hermes are Proxmox LXC; dualie, forge, and rk3588 are non-NixOS. They lose nothing
architecturally — their sops key is protected by whatever protects their storage. Same model, weaker
at-rest floor, no configuration difference.

### Emulated TPM (VM / microvm)

An emulated TPM's state lives on the host, so it is a **test harness for the mechanism, not a
security boundary**. Use `virtualisation.tpm.enable` in a NixOS VM test to exercise enroll and unseal
logic; never treat it as protecting a real secret.
