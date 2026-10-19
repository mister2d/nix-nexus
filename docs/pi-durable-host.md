# pi-durable host plumbing (petunia, sweet16)

This guide covers the host-side groundwork for running pi-durable. The
modules below provision identities, a TPM2-sealed credential directory, and
a restricted SSH target. They do not enable pi-durable. `services-pi-durable`
enables it on petunia using the pi-durable module (its own repo).

| Registry key | File | Provides |
|---|---|---|
| `core-agent-identities` | `modules/core/agent-identities.nix` | users and groups `pdh-pi` (9100), `agent` (9101) |
| `core-credstore` | `modules/core/credstore.nix` | `/var/lib/credstore.encrypted`, `seal-credential`, `credstore-selftest.service` |
| `core-agent-ssh-target` | `modules/core/agent-ssh-target.nix` | `Match User agent` sshd block, principals file |
| `services-pi-durable` | `modules/services/pi-durable/default.nix` | harness instance `pi`, credentials directory, socket token unit |
| `user-agent-home` | `modules/user/agent-home.nix` | bash, tmux, herdr profile for `agent` |
| `hm-agent-<host>` | `hosts/<host>/agent-hm.nix` | Home Manager wiring for `agent` |

## Identities and the uid range

Ids 9100-9199 are reserved for agent identities. The repository and the
locked nixpkgs assign nothing in that range. Check the live `/etc/passwd`
and `/etc/group` on each host before the first deploy.

| Identity | uid/gid | Role |
|---|---|---|
| `pdh-pi` | 9100 | host service user for the pi-durable harness `pi` |
| `agent` | 9101 | target of Vault-signed SSH certificates (principal `agent`) and remote nix builds |

Neither identity is in `tss`, `wheel`, `docker`, or `kvm`, and neither is in
`nix-nexus.tpm2.users`. `core-agent-identities` asserts this at evaluation.
The `agent` password stays unset, so login works only with a certificate.

pi-durable always declares `users.users.pdh-<name>` and its socket group
without checking for an existing definition and without setting a uid. The
host definition of uid 9100 merges with it. This holds only while the
values agree: group `pdh-pi`, home `/var/lib/pi-durable-pi`, and
`isSystemUser = true`.

## Trust boundary

The TPM is never reachable by these identities. On both hosts
`/dev/tpmrm0` is `root:tss 0660` (nix-nexus does not enable abrmd, so the
tss user defaults to root). Only `tss` members, such as users in
`nix-nexus.tpm2.users`, can open it. A service holding sealed credentials
gets them from PID 1 through `LoadCredentialEncrypted=` and needs no device
access. pi-durable cannot use that path, so a root unseal unit (see
"Sealed delivery to pi-durable") holds the TPM access instead. The
pi-durable unit already sets `PrivateDevices=true`.

Residual exposure: the service must hold the unsealed secret_id in memory
and as a file on tmpfs (`/run/credstore-unsealed/<name>`, root-0600, read by
PID 1 and passed on via `/run/credentials/<unit>`). Root
on the host is out of scope. Limit the blast radius on the Vault side
(vault-config repo, not part of this repository): bind `secret_id_bound_cidrs`
and `token_bound_cidrs` to the host addresses, set a finite `secret_id_ttl`
and `secret_id_num_uses`, and issue secret_ids through response wrapping.

## Sealing runbook

The credstore holds no secret in the Nix store or the repository. Run as
root on the target host.

1. Choose the PCR set. The default is PCR 0 (`nix-nexus.secrets.credstore.tpm2Pcrs`),
   matching the petunia LUKS posture. On sweet16 use PCR 7 only if Secure
   Boot is enabled. Check with `bootctl status` and `systemd-analyze pcrs`.
   systemd-creds binds no PCR unless `--tpm2-pcrs` is given, and
   `seal-credential` always passes it.
2. Seal the value from stdin so it never lands in shell history or a file:

   ```
   seal-credential pidurable-secret-id
   ```

   Paste the value, then end input with Ctrl-D. The blob is written to
   `/var/lib/credstore.encrypted/pidurable-secret-id` (root, mode 0700
   directory, blob mode 0600).
3. Reference the blob by absolute path in the unit. Systemd's bare-name
   search path covers `/run/credstore.encrypted`, `/etc/credstore.encrypted`
   and `/usr/lib/credstore.encrypted`, not `/var/lib/credstore.encrypted`:

   ```
   LoadCredentialEncrypted=secret_id:/var/lib/credstore.encrypted/pidurable-secret-id
   ```

### Self-test

Seal a throwaway value named `selftest`, then run the manual unit:

```
echo throwaway | seal-credential selftest
systemctl start credstore-selftest.service
journalctl -u credstore-selftest.service
```

It passes when the credential is delivered and no `/dev/tpm*` node is
visible inside the unit. Confirm the attempt did not move the lockout
counter: compare `tpm2_getcap properties-variable` before and after.
Delete the blob afterwards.

## Sealed delivery to pi-durable

The pi-durable module delivers every credential with plain `LoadCredential=`
file paths read by PID 1 as root, and never uses `LoadCredentialEncrypted=`.
Systemd list values concatenate, so a host-side `LoadCredentialEncrypted`
entry would sit beside the plain entry rather than replace it.

`nix-nexus.secrets.credstore.unseal.<name>` bridges the two. Each entry
defines `credstore-unseal-<name>.service`, a root oneshot with
`RemainAfterExit` that runs `systemd-creds decrypt --name=<credentialName>`
on the sealed blob and writes `/run/credstore-unsealed/<name>` (mode 0600,
tmpfs, atomic rename). The unit has TPM access (no `PrivateDevices`), an
empty capability bounding set, `ProtectSystem=strict`, and only
`/run/credstore-unsealed` writable. `ExecStop` removes the file. Every unit
in `consumers` gains `requires` and `after` on the unseal unit, and the
unseal unit is `partOf` the consumers, so stopping or restarting a consumer
removes and recreates the plaintext. The blob defaults to
`/var/lib/credstore.encrypted/<name>` and `credentialName` defaults to
`<name>`; an assertion requires `credentialName` to equal the blob file
name, matching `seal-credential NAME`.

pi-durable `credentials.secretIdFile` points at
`/run/credstore-unsealed/pidurable-secret-id`. The real wiring is described
in "petunia wiring" below.

Residual: while the consumer is up the plaintext sits root-0600 on tmpfs in
`/run/credstore-unsealed`, which is equivalent to the exposure of
`/run/credentials/<unit>`. Root on the host remains out of scope. An
upstream pi-durable `secretIdEncryptedFile` option (delivering via
`LoadCredentialEncrypted=`) would be the cleaner long-term fix and would
make the bridge unnecessary.

There is no per-instance `enable`: set `services.pi-durable.enable = true`.

## petunia wiring

`services-pi-durable` (`modules/services/pi-durable/default.nix`) imports
`inputs.pi-durable.nixosModules.default` and defines instance `pi` on
petunia only. sweet16 keeps its sealed secret_id idle.

| Setting | Value |
|---|---|
| `vault.addr` | `https://vault.service.consul:8200` |
| `model` | provider `anthropic`, name `claude-sonnet-5-5` (default, confirm the intended model id) |
| `database.credsPath` | `database/creds/pidurable-pi-owner` |
| `ssh` | host `192.168.33.10`, `knownHosts = null` (allowed inside 192.168.33.0/24), `signPath = ssh-client-signer/sign/agentrole` |
| `guest.unit` | unset |

### Guest start is staged

With `guest.unit` unset the harness never starts the execution guest. Start
the permafrost guest by hand (`sudo nix run .#permafrost start`) before the
first harness call; while it is down, calls fail. Starting the guest from
the harness needs a microvm.nix host unit on petunia plus a polkit rule,
which is a separate follow-up.

### Credentials directory

`/var/lib/pi-durable-creds` is `root:root 0700`, outside the unit's
`StateDirectory` (`/var/lib/pi-durable-pi`, created by systemd at first
start). PID 1 reads these files as root and passes them on via
`LoadCredential=`.

| File | Origin |
|---|---|
| `database_url` | created by tmpfiles (`f`, written only when absent) with the non-secret URL `postgresql://pidurable-db.service.consul:5432/pidurable?sslmode=verify-full&sslnegotiation=direct`; Vault supplies user and password |
| `role_id` | written by tmpfiles (`f+`, rewritten on activation) with the non-secret AppRole role_id of `pidurable-pi`, a Terraform output of vault-config; update the value in the module if the role is recreated |
| `socket_token` | generated once by `pi-durable-socket-token.service` |
| `/run/credstore-unsealed/pidurable-secret-id` | TPM2 unseal bridge, see above |

### Socket token

`pi-durable-socket-token.service` is a root oneshot ordered before and
required by `pi-durable-pi.service`. It runs only while
`/var/lib/pi-durable-creds/socket_token` is absent and writes 32 random
bytes as hex with `umask 077`, then sets `root:pdh-pi 0640`. Members of
`pdh-pi` can read the token they must present to the socket. That group
already grants socket access, so the read adds no authority. To rotate,
delete the file and restart `pi-durable-pi.service`.

### TLS trust

pi-durable sets no CA option: Vault calls use Node `fetch` and Postgres uses
`pg`, and Node ignores the system store. The unit sets
`NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt`. NixOS generates
that bundle from `security.pki`, and it includes `certs/int_cert.crt`
(intermediate and root) through `security.pki.certificateFiles` in
`core-security`.

### Name resolution

Consul DNS is each host's first resolver hop, so `*.service.consul` names
(`vault.service.consul`, `pidurable-db.service.consul`) resolve on petunia.

### Scope

The guest is started by hand (see "Guest start is staged"). Model discovery
through bifrost and Anthropic subscription models are future scope; the
model name `claude-sonnet-5-5` is a placeholder.

## SSH target

The Vault SSH CA is already trusted fleet-wide by `core-sshd`
(`TrustedUserCAKeys`). `core-agent-ssh-target` adds, for `agent` only:
principals from `/etc/ssh/authorized_principals.d/agent` (the single
principal `agent`), `AuthorizedKeysFile none`, publickey-only
authentication, and no agent, TCP, stream-local or X11 forwarding and no
tunnels. A tty is permitted because tmux and herdr need one. The
`AuthorizedPrincipalsFile` key is set inside the Match block only, so
existing certificate logins for other users keep their default
principal-equals-username rule.

## Remote builds as agent

`agent` is not in `nix.settings.trusted-users`, which would be
root-equivalent, and `core-agent-ssh-target` asserts this. `allowed-users`
keeps its default of `*`, so `agent` can talk to the daemon. It can import
only signed store paths. Build on the target and copy signed closures. If
importing unsigned paths turns out to be required, stop and decide that
explicitly.

## Rotation

Rotate the secret_id by issuing a new one in Vault, running
`seal-credential` with the new value (it replaces the blob atomically), and
restarting the pi-durable unit. Re-seal after any firmware or Secure Boot
change that alters the bound PCRs, or the blob will not unseal.

## Dictionary-attack counter

Sealing to PCRs without a PIN uses a policy session with no authValue, which
does not feed the global DA counter (see `docs/secrets.md`). No identity
here can open the TPM, so none can burn the shared counter (`MAX_AUTH_FAIL`
is 3 on petunia).

## Deferred

Dynamic microVM launch from the harness needs root for tap, bridge and kvm.
Prefer a root-owned, socket-activated launcher with a fixed template argv
and no caller-supplied paths. Never add `agent` to `kvm` or `wheel`.
