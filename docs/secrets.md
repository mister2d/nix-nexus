# Secrets management

nix-nexus manages secrets across three surfaces. It uses three different
tools. The tools are not alternatives to one another. Each tool covers a
case the other tools cannot cover.

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

Vault stays narrow, by design. Hosts must boot and run when Vault is down.
Nothing in the activation path depends on Vault. Vault has three jobs: it
is the SSH CA for deploys, it distributes LE certificates, and it renews
short-TTL credentials on avina.

## Layer 1 — sops-nix

sops-nix decrypts secrets at activation time into `/run/secrets`, which is
tmpfs. Nothing lands on disk. sops-nix runs no daemon, makes no network
call, and needs no bootstrap credential.

**Host identity is the SSH host key.** `core-sops` sets
`sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]`. Each host
decrypts with an age key derived from a key it already has. To onboard a
host, add one recipient line. Onboarding needs no new key material.

### Files

- `.sops.yaml` — recipients and creation rules. Not secret.
- `secrets/<hostname>.yaml` — encrypted and committed. It is safe to commit. Only the listed
  recipients can decrypt it.
- `modules/core/sops.nix` — registry key `core-sops`. Declares
  `nix-nexus.secrets.sops.hostFile` and the fleet-wide sops policy.

`hostFile` defaults to `null`. This setting leaves sops-nix completely
inert. A host that declares no secrets is byte-identical to a host without
the module.

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

`sops-install-secrets.service` is a `oneshot` in `sysinit.target` with
`RemainAfterExit = true`. Ordering after it is safe for the whole boot.

### Onboarding a host

```bash
# Derive the host's age recipient from its public SSH host key. No host access needed.
ssh-keyscan -t ed25519 <host>.home.lan | cut -d' ' -f2- | ssh-to-age
```

Add the result to `.sops.yaml` under `keys:` and reference it in a
`creation_rules` entry. Then run `sops updatekeys secrets/<host>.yaml`. This
re-encrypts existing files for the new recipient.

### Rotating

- **A secret's value**: `sops secrets/<host>.yaml`, edit, redeploy.
- **A host's key** (reinstall, or host key regenerated): re-derive the recipient, update
  `.sops.yaml`, run `sops updatekeys` on every file that host reads, redeploy.
- **The admin key**: update `.sops.yaml`, `sops updatekeys` across `secrets/`, commit.

## Layer 2 — secretspec

`secretspec.toml` at the repo root declares **what** secrets exist. The
provider decides **where** they live. The same declaration serves a
workstation (keyring), a headless host (Vault), and CI.

### Version constraints — important

The devshell ships secretspec from `nixpkgs-unstable`. Measured against the built binary:

| | |
|---|---|
| Version | **0.13.0** (stable channel has 0.10.1) |
| Providers available | `vault`, `keyring`, `dotenv`, `env` |
| Providers **not** available | `sops`, `age`, `systemd-credential` — 0.17-only, report `Provider backend not found` |
| `[scopes]` | 0.17-only, unavailable |
| `require_reason` policy | **active** — every read needs `--reason "<why>"` or `SECRETSPEC_REASON` |

`github:cachix/secretspec` publishes no `flake.nix`, and no nixpkgs commit
carries 0.17 yet. Adopting 0.17 features needs vendoring a Rust build.
Revisit this when nixpkgs catches up.

### Provider choice by host

- **sweet16, petunia** — `keyring`. A Secret Service daemon runs on these hosts (gnome-keyring,
  via `modules/core/security.nix`).
- **hermes, forge, rk3588, CI** — `vault`. No keyring daemon on these.

### Usage

Load secrets at process launch, not into the shell environment:

```bash
secretspec run --reason "why you need them" -- your-command
```

Eval-time injection (`config.secretspec.secrets` in devenv) is
**unavailable here**: devenv asserts
`!(secretspec.enable && devenv.flakesIntegration)`, and nix-nexus consumes
devenv via `inputs.devenv.flakeModule`. Runtime loading is the only option
here. It is also the practice the upstream project recommends.

### What is wired today

The Claude Code Stop hook runs under `secretspec run`. The hook is
`.claude/hooks/langfuse_hook.py`, declared in `modules/flake/checks.nix`.
Its Langfuse credentials reach that process only and never enter the shell
environment.

All three of its secrets are declared **optional** and **keyring-only**. Both choices are
deliberate:

- *Optional* — the hook provides elective telemetry. Marking the secrets required would make
  `secretspec run` exit non-zero. The hook would then skip on every turn for anyone who has not
  configured Langfuse.
- *Keyring-only* — the hook fires on every Stop event. A provider list that falls back to Vault
  would add a network round-trip on every turn when the keyring misses.

### Storing a value

```bash
secretspec set LANGFUSE_SECRET_KEY                     # prompts, writes to the keyring
secretspec check --reason "audit"                      # declaration status
secretspec run --reason "why" -- env | grep LANGFUSE   # confirm resolution
```

`--reason` is mandatory. Version 0.13 enforces a `require_reason` policy. It
defaults to `agents`. Set `require_reason = false` under `[project]` to
disable it. The policy applies to `check` and `get` too, not only to `run`.

`secretspec check` reports optional secrets as `optional` **without probing
whether they resolve**. "0 found, 0 missing, 3 optional" does not mean they
are unset. Use `run` to test actual resolution.

To use Vault instead of the keyring for a secret, set
`providers = ["home_vault"]` on that secret. This setting is required on
headless hosts, which have no Secret Service daemon. Values land at
`kv-v2/secretspec/{project}/{profile}/{key}` under field `value`.

### Verifying a rendered secret without exposing it

Never run `cat` on a rendered secret or a decrypted sops value to check it.
Error paths leak values too: `sops decrypt` prints the offending plaintext
scalar when a value fails to parse. Route stderr away, or test only the
exit status.

To confirm a rendered file matches its source, compare hashes on both ends:

```bash
# on the host
grep -m1 '^VAR=' file | cut -d= -f2- | tr -d '\n' | sha256sum | cut -c1-12
# locally
sops decrypt --extract '["section"]["key"]' secrets/<host>.yaml | tr -d '\n' | sha256sum | cut -c1-12
```

Counting variables or checking file permissions verifies *structure* only,
not *content* — a wrong value can pass both checks. Only the hash
comparison proves the rendered value is correct.

### hermes gateway env files

`sops.templates` renders `~/.hermes/.env` and
`~/.hermes/profiles/coding-local/.env`. hermes-agent loads
`$HERMES_HOME/.env` itself with `override=True`, and this load outranks
anything systemd injects. Only sensitive values are encrypted. Endpoints
and toggles stay readable in `hosts/hermes/secrets.nix`.

Both gateways are **user** units. `restartUnits` reaches system units only,
so it does not reach these gateways. After you rotate any of these
secrets, run:

```bash
systemctl --user restart hermes-gateway hermes-gateway-coding-local
```

Rotating `MATRIX_ACCESS_TOKEN` also requires wiping the crypto store — see
`docs/hermes.md`. Past E2EE messages become permanently undecryptable.
This result is inherent to `kill-sessions`, not a fault.

## Layer 3 — TPM2 and disk encryption

The sops age key is the SSH host key, which lives on the root filesystem.
**Whatever protects the root disk transitively protects every sops secret
at rest.** There is deliberately no bespoke TPM-sealing of the age key.
sops-nix has no supported TPM path. PCR values change on firmware updates.
Sealing would forfeit remote re-keying.

### petunia — plain TPM2 auto-unseal (accepted risk)

petunia enrolls LUKS2 against **PCR 0 only**. Secure Boot is inactive on
petunia, so PCR 7 has no meaning here. PCR 0 measures firmware only. It
does **not** measure the kernel, the initrd, or the cmdline. A modified
initrd on the same hardware would still unseal the disk.

This is a **consciously accepted risk**, not an oversight: petunia is a
physically-controlled desktop, and its threat model is remote compromise,
not device theft. See `docs/petunia.md` for the enrollment and
re-enrollment procedure.

### sweet16 — TPM2 with PIN, mandatory

> **sweet16 must never use plain TPM2 auto-unseal.**

sweet16 is a laptop, and its threat model is physical theft. Plain
auto-unseal means power-on unlocks the disk — including the SSH host key,
the sops age key, and everything in `/run/secrets`. Use only this
sanctioned enrollment form:

```bash
systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0 --tpm2-with-pin=yes <device>
```

The PIN closes the theft gap. A short PIN is safe here because the TPM
rate-limits guesses against it (anti-hammering). A passphrase is
different: an attacker brute-forces it offline against the LUKS KDF.
Keyslot 0 remains a passphrase fallback.

**This flag must survive re-enrollment.** sweet16's PCR 0 keyslot breaks
on every firmware update, which Lenovo ships frequently via fwupd, and the
re-enroll command is hand-typed. One failure mode is copying petunia's
command and silently dropping `--tpm2-with-pin=yes`.

Device paths differ between the two hosts. sweet16 uses
`/dev/disk/by-partlabel/DISK_LUKS`. petunia must use `/dev/nvme0n1p2`
because disko labels its partition `disk-main-DISK_LUKS`, so
`by-partlabel/DISK_LUKS` does not resolve there. Confirm the path with
`lsblk -o NAME,PARTLABEL` before enrolling.

Verify an enrollment carries the PIN:

```bash
cryptsetup token export --token-id 0 /dev/disk/by-partlabel/DISK_LUKS
```

`"tpm2-pin": true` and `"tpm2-pcrs": [0]` are the fields that matter. A
token without `tpm2-pin` auto-unseals on power-on. Remove it with
`systemd-cryptenroll --wipe-slot=tpm2` and redo the enrollment.

### Dictionary-attack lockout

The TPM rate-limits authValue guesses with one global counter shared by
**every** TPM consumer on the host. The LUKS PIN, `ssh-tpm-agent` key
PINs, and the `tpm2-pkcs11` token PIN all draw on it. Measured with
`tpm2_getcap -T device:/dev/tpmrm0 properties-variable`:

| Property | sweet16 | petunia |
|---|---|---|
| `TPM2_PT_MAX_AUTH_FAIL` | 32 | **3** |
| `TPM2_PT_LOCKOUT_INTERVAL` (counter decays 1 per) | 7200s (2h) | 1000s (~17m) |
| `lockoutAuthSet` | 1 | 0 |

`LOCKOUT_INTERVAL` governs ordinary recovery: one failure is forgiven per
interval. `TPM2_PT_LOCKOUT_RECOVERY` is narrower: it gates re-use of
`lockoutAuth` only after that specific auth fails, not general DA recovery.

petunia locks after three wrong PINs. This limit is survivable only
because you enter an agent PIN once per agent lifetime, not per use.
Anything that prompts per operation would make a 3-strike counter
untenable. sweet16 tolerates 32 attempts but has `lockoutAuth` set, so
`tpm2_dictionarylockout --clear-lockout` needs a password that may not be
recorded anywhere. Wait out the interval instead.

**A TPM lockout cannot lock you out of the disk.** LUKS2 keyslots are
independent, and the systemd-tpm2 token targets only its own slot:

```
Keyslot 0: argon2id   <- passphrase, no TPM involvement
Keyslot 1: pbkdf2     <- systemd-tpm2 token ("keyslots":["1"])
```

`systemd-cryptsetup` falls through to the passphrase prompt whenever the
TPM path fails. On petunia this question does not arise at all. Its
keyslot is PCR-0 only with no PIN. A policy session carrying no
authValue does not feed the DA counter.

### Hosts without a TPM

avina and hermes are Proxmox LXC. dualie, forge, and rk3588 are non-NixOS.
They lose nothing architecturally. Their sops key is protected by
whatever protects their storage. The model stays the same, the at-rest
floor is weaker, and there is no configuration difference.

### Emulated TPM (VM / microvm)

An emulated TPM's state lives on the host, so it is a **test harness for
the mechanism, not a security boundary**. Use `virtualisation.tpm.enable`
in a NixOS VM test to exercise enroll and unseal logic. Never treat it as
protecting a real secret.
