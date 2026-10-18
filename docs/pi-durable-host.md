# pi-durable host plumbing (petunia, sweet16)

This guide covers the host-side groundwork for running pi-durable. The
modules below provision identities, a TPM2-sealed credential directory, and
a restricted SSH target. They do not enable pi-durable. The pi-durable
module (its own repo) does that.

| Registry key | File | Provides |
|---|---|---|
| `core-agent-identities` | `modules/core/agent-identities.nix` | users and groups `pdh-pi` (9100), `agent` (9101) |
| `core-credstore` | `modules/core/credstore.nix` | `/var/lib/credstore.encrypted`, `seal-credential`, `credstore-selftest.service` |
| `core-agent-ssh-target` | `modules/core/agent-ssh-target.nix` | `Match User agent` sshd block, principals file |
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
access. The pi-durable unit already sets `PrivateDevices=true`.

Residual exposure: the service must hold the unsealed secret_id in memory
and in `/run/credentials/<unit>` (tmpfs, readable only by the unit). Root
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

## Open design gap: sealed delivery to pi-durable

The pi-durable module delivers every credential with plain
`LoadCredential=` file paths and never uses `LoadCredentialEncrypted=`.
Systemd list values concatenate, so adding a `LoadCredentialEncrypted`
entry on the host sits beside the plain secret_id entry and does not
replace it. Sealed delivery needs either a host override of
`serviceConfig.LoadCredential` or an upstream pi-durable change. Until this
is resolved, the plain credential file must be a root-owned file outside the
Nix store, and the TPM isolation argument applies only to credentials
delivered through the credstore.

Enabling pi-durable also differs from the original plan: there is no
per-instance `enable`. Set `services.pi-durable.enable = true`,
`services.pi-durable.vault.addr`, and define `instances.pi` with `model.name`,
`ssh.host`, `ssh.knownHosts`, and the `credentials.*File` paths
(`roleIdFile`, `secretIdFile`, `databaseUrlFile`, `socketTokenFile`).

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
