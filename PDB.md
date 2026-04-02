# PDB — Matrix 2.0 Homeserver (`avina`)

> **SYSTEM PROMPT FOR AI CODING AGENTS**
>
> You are implementing NixOS host **`avina`** inside the **nix-nexus** dendritic framework.
> Read every section before writing a single line of Nix. Every decision here is **binding**.
>
> **Before emitting any NixOS option path, package name, or module attribute** — query
> `mcp-nixos` to confirm existence, type, and defaults. Do not guess at names.
>
> Cross-reference the actual nix-nexus source files before making assumptions:
> - `modules/networking.nix` — Tailscale enabled here; must be overridden for avina
> - `modules/zfs.nix` — `nix-nexus.zfs` option set avina must configure
> - `modules/_hw/petunia/disko.nix` — canonical Disko + ZFS pattern to follow
> - `modules/hosts.nix` — fleet control plane and host definitions
> - `modules/base.nix` — mandatory base; stateVersion, timezone, ZFS defaults
> - `modules/shell.nix` — ambient `VAULT_ADDR` and `CONSUL_HTTP_ADDR` env vars confirm
>   Vault and Consul are already first-class in this infrastructure

---

## 1. Introduction

**Purpose:** Deploy a fully public, self-hosted **Matrix 2.0** communications platform on
a **Proxmox LXC container** running NixOS. The system uses native OIDC via **Matrix Authentication
Service (MAS)** upstream to a self-hosted Keycloak instance, **MatrixRTC via LiveKit SFU**
for audio/video, and a hybrid ingress model: Cloudflare Tunnel for all signaling traffic and
direct media paths via LiveKit's built-in TURN/STUN relay.

**Scope:**
- Host: Proxmox LXC (unprivileged)
- Synapse (element-hq fork) with MSC3861 MAS delegation
- MAS (Matrix Authentication Service) — native OIDC provider, upstream to Keycloak
- LiveKit SFU + `lk-jwt-service` — MatrixRTC audio/video; media via internal TURN relay
- Element Web (static, served by darkhttpd)
- HAProxy — sole local reverse proxy (no Nginx)
- `cloudflared` — external signaling ingress (tunnel)
- `vault-agent` — pulls TLS certs from Vault KV-v2; triggers service reloads
- Federation: enabled, controlled via `federation_domain_whitelist`

**Applicable nix-nexus source files:**
- `modules/networking.nix` — Tailscale + firewall configuration that must be overridden
- `modules/zfs.nix` — `nix-nexus.zfs.*` option schema
- `modules/_hw/petunia/disko.nix` — reference Disko + ZFS implementation
- `docs/packages.md` — confirms Vault 1.21.1, Consul 1.22.1 in operator's toolchain

---

## 2. System Overview

### 2.1 Network Exposure Model

avina uses a "Hybrid Ingress" model. Signaling (HTTPS) is private and brokered via Cloudflare,
while Media (WebRTC) is directly exposed for performance.

```
┌─────────────────────────────────────────────────────────────┐
│                      avina (LXC Container)                   │
│                                                              │
│  Signaling Ingress (Cloudflare Tunnel)                       │
│  ─ outbound connection to Cloudflare edge                    │
│  ─ carries: HTTPS traffic (Matrix, MAS, Element)             │
│  ─ terminates at: HAProxy 127.0.0.1:8080                     │
│                                                              │
│  DIRECTLY EXPOSED (bare network):                            │
│    :22  TCP          OpenSSH (cert/key-based; no passwords)  │
│    :3478 UDP+TCP     LiveKit STUN/TURN                       │
│    :5349 UDP+TCP     LiveKit TURNS/TLS                       │
│    :7881 TCP         LiveKit RTP-over-TCP fallback           │
│    :50100-50200 UDP  LiveKit WebRTC media range              │
└─────────────────────────────────────────────────────────────┘
```

**SSH access**: Port 22 is open to `0.0.0.0/0`. Password authentication is disabled.
Certificate-based authentication is enforced via a trusted SSH CA.

**LiveKit media**: LiveKit signaling (WebSocket) flows through cloudflared → HAProxy → LiveKit :7880.
Media flows directly to ports 50100-50200 (UDP) or 7881 (TCP). Clients behind strict NAT
use LiveKit's built-in TURN server on ports 3478/5349.

### 2.2 Ingress Flow

```
Internet client (Signaling)
  │ HTTPS
  ▼
Cloudflare Edge ──► cloudflared tunnel ──► HAProxy 127.0.0.1:8080
  ├── /_matrix/ /_synapse/ → Synapse :8008
  ├── /auth/ /_mas/ + login/logout/refresh → MAS :8181
  ├── /livekit/jwt/ → lk-jwt-service :8081
  ├── /livekit/sfu/ → LiveKit :7880 (WebSocket signaling)
  ├── /.well-known/ → static JSON responses (MatrixRTC foci)
  ├── rtcDomain/ → Element Call static :8084
  └── default → Element Web static :8082

WebRTC media (Direct or Relayed)
  │ UDP/TCP via bare network (Edge Router DNAT)
  ▼
LiveKit SFU :50100-50200 (UDP) / :7881 (TCP) / :3478 (TURN)
```

### 2.3 MAS / Native OIDC Architecture (MSC3861)

```
Client (Element Web / Element X)
  │ OIDC Authorization Code flow
  ▼
MAS (127.0.0.1:8181, proxied via HAProxy + cloudflared)
  │ upstream OIDC to Keycloak
  ▼
Keycloak (operator's existing deployment)
  │ identity token returned to MAS
  ▼
MAS issues access/refresh tokens to client
  │
Client uses MAS tokens with Synapse (127.0.0.1:8008)
  └── Synapse validates via MSC3861 shared secret with MAS
```

MAS is the OIDC issuer Synapse trusts. Keycloak is MAS's upstream. Clients never speak
directly to Keycloak. Synapse password auth is fully disabled.
This is a greenfield deployment — no `syn2mas` migration required.
MAS delegation is one-way and irreversible; document prominently in the module.

### 2.4 Certificate Management (Vault + vault-agent)

The operator's infrastructure already runs Vault and Consul (confirmed by ambient
`VAULT_ADDR` and `CONSUL_HTTP_ADDR` env vars in `modules/user/bash.nix` and by
`docs/packages.md` listing Vault 1.21.1 and Consul 1.22.1).

TLS certs for all directly-exposed services (Coturn, HAProxy stats) come from **Vault
KV-v2**. An external process outside this spec places the Let's Encrypt certificate into
Vault. vault-agent reads from the KV path and re-renders whenever the secret version
increments (i.e. when the external renewal process writes a new cert):

```
Vault KV-v2  kv-v2/letsencrypt/certificates/live/novuscotia.com
  │  fields: fullchain, privkey
  │  vault-agent watches KV version; re-renders on version increment
  ▼
vault-agent daemon (custom systemd service on avina)
  │ renders three files to /run/certs/
  ├── /run/certs/haproxy.pem       (fullchain+privkey combined)
  │   → command: systemctl reload haproxy.service || true
  ├── /run/certs/turn-fullchain.pem  (fullchain only)
  │   → command: systemctl restart livekit.service || true
  └── /run/certs/turn.key           (privkey only)
      → command: systemctl restart livekit.service || true
```

Cloudflare-proxied domains (MATRIX_DOMAIN, ELEMENT_DOMAIN, MAS_DOMAIN) do not need local
TLS certs — Cloudflare provides TLS at its edge.

### 2.5 Tailscale — Confirmed Override Required

**Validated from `modules/core/networking.nix`**: `profiles/core` unconditionally enables:
- `services.tailscale.enable = true`
- `systemd.services.tailscale-autoconnect` (wantedBy multi-user.target)
- `networking.firewall.trustedInterfaces = ["tailscale0"]`
- `networking.firewall.allowedUDPPorts` includes `config.services.tailscale.port`

All of these must be overridden for `avina`. The override must be careful: the UDP ports
list in `networking.nix` references `config.services.tailscale.port` — this evaluates to
Tailscale's default port (41641) even when the service is disabled, so it will not cause
an evaluation error, but the firewall override should use `lib.mkForce` on the entire UDP
port list to eliminate it cleanly.

**Future**: When the operator deploys self-hosted **Headscale** VPN infrastructure,
`avina` will be enrolled at that time. The module should carry a comment placeholder for
this. Until Headscale is deployed, avina has no VPN layer; admin access is via cloudflared
SSH only.

### 2.6 Module Availability Pre-Check

Query `mcp-nixos` for each item before writing any module:

| Component | Expected | Query |
|---|---|---|
| `services.matrix-synapse` | Module exists | `get option services.matrix-synapse.enable` |
| `pkgs.matrix-authentication-service` | Package only (nixpkgs #376738) | `search packages matrix-authentication-service` |
| `services.livekit` | Module likely exists | `get option services.livekit.enable` |
| `services.lk-jwt-service` | Module likely exists | `get option services.lk-jwt-service.enable` |
| `services.haproxy` | Module exists; raw string config | `get option services.haproxy.config` |
| `services.cloudflared` | Module exists | `get option services.cloudflared.tunnels` |
| `pkgs.vault-agent` | Package only; no module | `search packages vault-agent` |
| `services.postgresql` | Module exists | `get option services.postgresql.ensureUsers` |
| `services.coturn` | Module exists | `search options services.coturn` |
| `services.tailscale` | Module exists (imported by core) | `get option services.tailscale.enable` |

---

## 3. Component Specifications

### 3.1 Synapse (element-hq fork)

Confirm package attribute via `mcp-nixos` (still `services.matrix-synapse` per NixOS module;
element-hq fork is the active upstream since Synapse 1.99).

- Listener: `127.0.0.1:8008` only (plain HTTP)
- `server_name = MATRIX_DOMAIN`
- Database: PostgreSQL, Unix socket (`/run/postgresql`), `LC_COLLATE = "C"`, `LC_CTYPE = "C"`
- `enable_registration = false`
- `password_config.enabled = false`
- `suppress_key_server_warning = true`

**MSC3861 + MatrixRTC MSCs** (in `extraConfigFiles` YAML at runtime path):
```yaml
experimental_features:
  msc3266_enabled: true            # Room Summary API — Element Call federation knocking
  msc4222_enabled: true            # State After Sync — correct room state tracking
  max_event_delay_duration: 24h    # MSC4140 Delayed Events — call participation signalling
  msc3861:
    enabled: true
    issuer: "https://MAS_DOMAIN/"  # MAS is the OIDC issuer Synapse trusts
    client_id: "synapse"
    client_auth_method: "client_secret_basic"
    client_secret: "<from /run/secrets/synapse-secrets.yaml>"
    admin_token:   "<from /run/secrets/synapse-secrets.yaml>"
```

**TURN block** (in same `extraConfigFiles` YAML):
```yaml
turn_uris:
  - "turn:COTURN_REALM:3478?transport=udp"
  - "turn:COTURN_REALM:3478?transport=tcp"
  - "turns:COTURN_REALM:5349?transport=tcp"
turn_shared_secret: "<from /run/secrets/synapse-secrets.yaml>"
turn_user_lifetime: "86400000ms"
```

**Federation allowlist**:
```yaml
federation_domain_whitelist:
  - "MATRIX_DOMAIN"   # own domain always included (Synapse issue #4857)
  # operator appends trusted peers; nixos-rebuild switch to expand
```

`extraConfigFiles = ["/run/secrets/synapse-secrets.yaml"]` contains:
`macaroon_secret_key`, `form_secret`, `registration_shared_secret`,
`turn_shared_secret`, MSC3861 `client_secret`, `admin_token`.

**Service ordering**:
```nix
systemd.services.matrix-synapse = {
  after    = [ "postgresql.service" "matrix-authentication-service.service" ];
  requires = [ "postgresql.service" "matrix-authentication-service.service" ];
};
```

### 3.2 PostgreSQL

```nix
services.postgresql = {
  enable  = true;
  package = pkgs.postgresql_16;  # confirm via mcp-nixos
  settings.listen_addresses = lib.mkForce "";  # Unix socket only
  ensureUsers = [
    { name = "matrix-synapse";               ensureDBOwnership = true; }
    { name = "matrix-authentication-service"; ensureDBOwnership = true; }
  ];
  ensureDatabases = [ "matrix-authentication-service" ];
  # matrix-synapse DB needs LC_COLLATE = "C" — ensureDatabases cannot set locale.
  # Use initialScript with idempotent CREATE DATABASE:
  initialScript = pkgs.writeText "synapse-pg-init.sql" ''
    SELECT 'CREATE DATABASE "matrix-synapse"
      ENCODING ''UTF8''
      LC_COLLATE = ''C''
      LC_CTYPE = ''C''
      TEMPLATE template0'
    WHERE NOT EXISTS (
      SELECT FROM pg_database WHERE datname = 'matrix-synapse'
    )\gexec
    GRANT ALL ON DATABASE "matrix-synapse" TO "matrix-synapse";
  '';
};
```

### 3.3 Matrix Authentication Service (MAS) — Custom Module

### 3.5 LiveKit SFU + lk-jwt-service (MatrixRTC)

**Media routing**: LiveKit's direct UDP ports (50100-50200) and TCP port (7881)
are exposed via DNAT at the edge router. For clients behind strict NAT, LiveKit's
built-in TURN/STUN relay is used on ports 3478 and 5349.

Confirm modules exist via `mcp-nixos`:
- `services.livekit.enable`
- `services.lk-jwt-service.enable`

If absent, write custom systemd service modules using the MAS skeleton as a template.

**Key generation** (idempotent oneshot; from NixOS Wiki pattern):
```nix
let keyFile = "/run/livekit.key"; in
systemd.services.livekit-key = {
  before   = [ "lk-jwt-service.service" "livekit.service" ];
  wantedBy = [ "multi-user.target" ];
  path     = with pkgs; [ livekit coreutils gawk ];
  script   = ''
    echo "lk-jwt-service: $(livekit-server generate-keys | tail -1 | awk '{print $3}')" \
      > "${keyFile}"
  '';
  serviceConfig.Type = "oneshot";
  unitConfig.ConditionPathExists = "!${keyFile}";
};
```

**LiveKit SFU** (`services.livekit`):
- `openFirewall = false` (firewall managed in `hosts/avina/default.nix`)
- `keyFile = "/run/livekit.key"`
- `settings.room.auto_create = false` ← **mandatory**; prevents unauthenticated room creation
- HTTP: `127.0.0.1:7880` (WebSocket signaling proxied via HAProxy)
- **Direct Exposure**: 7881 TCP and 50100–50200 UDP publicly via Edge Router DNAT.
- **Internal TURN**: Built-in relay on 3478 (UDP+TCP) and 5349 (TLS).

**lk-jwt-service** (`services.lk-jwt-service`):
- `livekitUrl = "wss://MATRIX_DOMAIN/livekit/sfu"` (via HAProxy → cloudflared)
- Inherits `keyFile`
- `environment.LIVEKIT_FULL_ACCESS_HOMESERVERS = "MATRIX_DOMAIN"` — local users can create
  rooms; federated users can only join existing rooms (requires `auto_create = false`)

### 3.6 Element Web

- Package: `pkgs.element-web` (confirm via `mcp-nixos`)
- Minimal static file server on `127.0.0.1:8082` (e.g. `pkgs.darkhttpd`)
- `config.json` generated by `pkgs.writeText`:
  ```json
  {
    "default_server_config": {
      "m.homeserver": {
        "base_url": "https://MATRIX_DOMAIN",
        "server_name": "MATRIX_DOMAIN"
      }
    },
    "disable_custom_urls": true,
    "disable_guests": true,
    "brand": "Element"
  }
  ```

### 3.7 vault-agent (Certificate Lifecycle)

Package `pkgs.vault-agent` exists; no NixOS module. Custom systemd service.
Certificates are fetched from **Vault KV-v2** (not Vault PKI engine). An external process
outside this spec is responsible for placing the Let's Encrypt certificate into Vault at
the path `kv-v2/letsencrypt/certificates/live/novuscotia.com` with fields `fullchain`
(full cert chain PEM) and `privkey` (private key PEM).

The same certificate is shared by **both HAProxy and LiveKit**. Three files are rendered:
- `/run/certs/haproxy.pem` — fullchain + privkey concatenated (HAProxy `ssl crt` format)
- `/run/certs/turn-fullchain.pem` — fullchain only (LiveKit `cert` option)
- `/run/certs/turn.key` — privkey only (LiveKit `key` option)

`VAULT_ADDR` is set directly in the service (non-secret URL, already ambient in the
nix-nexus environment per `modules/user/bash.nix`). `VAULT_TOKEN` is injected from a
secret file so the token never appears in the process environment table.

**`modules/services/matrix/vault-secrets.nix`**:
```nix
{ lib, pkgs, ... }:
let
  certDir  = "/run/certs";
  kvPath   = "kv-v2/letsencrypt/certificates/live/novuscotia.com";

  # HAProxy needs fullchain + privkey in a single PEM file.
  haproxyTmpl = pkgs.writeText "haproxy-cert.ctmpl" ''
    {{ with secret "${kvPath}" }}
    {{ .Data.data.fullchain }}{{ .Data.data.privkey }}
    {{ end }}
  '';

  # LiveKit TURN needs cert and key as separate files.
  turnCertTmpl = pkgs.writeText "turn-cert.ctmpl" ''
    {{ with secret "${kvPath}" }}
    {{ .Data.data.fullchain }}
    {{ end }}
  '';

  turnKeyTmpl = pkgs.writeText "turn-key.ctmpl" ''
    {{ with secret "${kvPath}" }}
    {{ .Data.data.privkey }}
    {{ end }}
  '';

  ctConfig = pkgs.writeText "vault-agent-certs.hcl" ''
    vault {
      # VAULT_ADDR is injected via Environment= in the systemd unit.
      # VAULT_TOKEN is injected via EnvironmentFile= from the secrets file.
      unwrap_token = false
      renew_token  = true
    }

    template {
      source      = "${haproxyTmpl}"
      destination = "${certDir}/haproxy.pem"
      perms       = "0640"
      # Reload HAProxy after cert renders; || true is safe if HAProxy not yet started
      command     = "${pkgs.systemd}/bin/systemctl reload-or-restart --no-block haproxy.service || true"
    }

    template {
      source      = "${turnCertTmpl}"
      destination = "${certDir}/turn-fullchain.pem"
      perms       = "0644"
      command     = "${pkgs.systemd}/bin/systemctl restart --no-block livekit.service || true"
    }

    template {
      source      = "${turnKeyTmpl}"
      destination = "${certDir}/turn.key"
      perms       = "0640"
      command     = "${pkgs.systemd}/bin/systemctl restart --no-block livekit.service || true"
    }
  '';
in
{
  systemd.tmpfiles.rules = [ "d ${certDir} 0755 root root -" ];

  systemd.services.vault-agent-certs = {
    description = "vault-agent: render TLS certs from Vault KV for avina services";
    after    = [ "network-online.target" ];
    wants    = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    # Both cert consumers must start after this service has rendered certs
    before   = [ "livekit.service" "haproxy.service" ];
    serviceConfig = {
      # VAULT_ADDR: non-secret; set directly. Matches ambient env from modules/user/bash.nix.
      Environment     = [ "VAULT_ADDR=https://vault.service.consul:8200" ];
      # VAULT_TOKEN: secret; injected from file. File contains: VAULT_TOKEN=<token>
      EnvironmentFile = "/run/secrets/vault-token.env";
      ExecStart = lib.escapeShellArgs [
        "${pkgs.vault-agent}/bin/vault-agent"
        "-config" ctConfig
      ];
      Restart         = "on-failure";
      RestartSec      = "30s";
      NoNewPrivileges = true;
      PrivateTmp      = false;   # must write to /run/certs
      ProtectSystem   = "strict";
      ReadWritePaths  = [ certDir ];
    };
  };
}
```

**Implementation notes**:
1. The KV-v2 `{{ with secret "kv-v2/..." }}` block re-renders whenever vault-agent
   detects the secret version has changed (Vault KV lease expiry). This is the correct
   behaviour for a KV source — the daemon watches the lease and re-renders on renewal.
2. `|| true` in each command prevents the template render from failing if the target
   service is not yet started on first boot.
3. `/run/secrets/vault-token.env` must contain exactly `VAULT_TOKEN=<token>` on one line.
   The token must have a Vault policy granting `read` on `kv-v2/data/letsencrypt/certificates/live/novuscotia.com`.
4. HAProxy's `/run/certs/haproxy.pem` is mode `0640` — HAProxy runs as `haproxy` user;
   ensure that user or group can read the file (adjust group ownership if needed).

### 3.8 HAProxy

`services.haproxy.config` is a raw Nix string. Validate with `haproxy -c -f <path>` before
committing. WebSocket proxying for LiveKit requires `option http-server-close` and
`timeout tunnel 3600s`. The TLS certificate rendered by vault-agent at
`/run/certs/haproxy.pem` is used for the stats/metrics frontend which binds on all
interfaces. The HAProxy user must be able to read that file.

Stats frontend binds on `*:8404` (unique port; open in firewall). Admin level is granted
to RFC-1918 and loopback source IPs. Prometheus metrics are served at `/metrics`.

```haproxy
global
  maxconn 4096
  stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners

defaults
  mode    http
  timeout connect 5s
  timeout client  600s
  timeout server  600s
  timeout tunnel  3600s
  option  forwardfor
  option  http-server-close

# ── Matrix ingress (from cloudflared) ────────────────────────────────────
frontend matrix_ingress
  bind 127.0.0.1:8080

  # MSC3861 auth endpoint routing — confirm exact paths with MAS docs
  acl is_mas_login   path_beg /_matrix/client/v3/login
  acl is_mas_login   path_beg /_matrix/client/r0/login
  acl is_mas_logout  path_beg /_matrix/client/v3/logout
  acl is_mas_logout  path_beg /_matrix/client/r0/logout
  acl is_mas_refresh path_beg /_matrix/client/v3/refresh
  acl is_mas_auth    path_beg /auth
  acl is_mas_oidc    path_beg /_mas
  acl is_lk_jwt      path_beg /livekit/jwt
  acl is_lk_sfu      path_beg /livekit/sfu
  acl is_matrix      path_beg /_matrix
  acl is_synapse     path_beg /_synapse
  acl is_wellknown   path_beg /.well-known

  use_backend mas_backend       if is_mas_login or is_mas_logout or is_mas_refresh or is_mas_auth or is_mas_oidc
  use_backend lk_jwt_backend    if is_lk_jwt
  use_backend lk_sfu_backend    if is_lk_sfu
  use_backend wellknown_backend if is_wellknown
  use_backend synapse_backend   if is_matrix or is_synapse
  default_backend element_backend

# ── Stats and Prometheus metrics ──────────────────────────────────────────
# Binds on all interfaces on the designated stats port with TLS.
# /run/certs/haproxy.pem is rendered by vault-agent from Vault KV.
frontend stats
  bind *:8404 ssl crt /run/certs/haproxy.pem
  option  http-use-htx
  stats   enable
  stats   show-legends
  stats   show-modules
  stats   uri /stats
  # Admin level for RFC-1918 + loopback source addresses
  stats   admin if { src 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 127.0.0.0/8 }
  # Prometheus metrics endpoint
  http-request use-service prometheus-exporter if { path /metrics }

backend synapse_backend
  server synapse 127.0.0.1:8008

backend mas_backend
  server mas 127.0.0.1:8181

backend lk_jwt_backend
  server lk_jwt 127.0.0.1:8081

backend lk_sfu_backend
  option http-server-close
  server lk_sfu 127.0.0.1:7880

backend wellknown_backend
  server wellknown 127.0.0.1:8083

backend element_backend
  server element 127.0.0.1:8082
```

Well-known responses at `/run/avina-wellknown/` served by minimal static server on :8083.
`/.well-known/matrix/client` must include:
```json
{
  "m.homeserver": { "base_url": "https://MATRIX_DOMAIN" },
  "org.matrix.msc3575.proxy": { "url": "https://MATRIX_DOMAIN" },
  "org.matrix.msc4143.rtc_foci": [
    { "type": "livekit", "livekit_service_url": "https://MATRIX_DOMAIN/livekit/jwt" }
  ]
}
```

Synapse Admin restriction: add ACL to `/_synapse/admin/` — allow only operator-defined
source IPs. Define the list as a `let` binding at the top of `modules/services/matrix/haproxy.nix`.

### 3.9 Cloudflared (Edge Ingress)

```nix
services.cloudflared = {
  enable = true;
  tunnels."<TUNNEL-UUID>" = {
    credentialsFile = "/run/secrets/cloudflared-creds.json";
    ingress = {
      "MATRIX_DOMAIN"  = "http://127.0.0.1:8080";
      "ELEMENT_DOMAIN" = "http://127.0.0.1:8080";
      "MAS_DOMAIN"     = "http://127.0.0.1:8080";
    };
    default = "http_status:404";
  };
};
```

SSH certificate auth: the operator places the SSH CA public key at `certs/ssh_user_ca.pub`
in the nix-nexus repository root. This follows the existing pattern where `certs/int_cert.crt`
holds the internal PKI CA (`modules/core/security.nix` references it as `../../certs/int_cert.crt`).
The SSH CA public key is referenced in the same way from `hosts/avina/default.nix`.

---

## 4. `modules/hosts.nix` (avina entry)

```nix
      avina = {
        includes = [
          den.provides.hostname
          den.aspects.base-aspect
          den.aspects.security-aspect
          den.aspects.sysctl-aspect
          den.aspects.matrix-aspect
        ];
        nixos =
          { pkgs, lib, ... }:
          {
            _module.args =
              let
                site = import ./_hw/avina/site-config.nix;
...
            imports = [ (inputs.nixpkgs + "/nixos/modules/virtualisation/proxmox-lxc.nix") ];
            # ... rest of NixOS config
          };
      };
```

**ZFS Tuning**:
Set in `modules/hosts.nix`: `arcMax = 2 GB`, `arcMin = 512 MB`, `arcSysFree = 3 GB`
(Scale up if RAM ≥ 16 GB). Headroom for PostgreSQL, Synapse, MAS, LiveKit.

**Tailscale**: disabled — confirmed present in `modules/networking.nix`.
Override in `modules/hosts.nix`: `services.tailscale.enable = lib.mkForce false;`

**Firewall**: Coturn + SSH directly exposed.
Override the entire firewall block in `modules/hosts.nix` to eliminate Tailscale references.

  # ── SSH: cert-based auth; open to all; prohibit-password root ────────────
  # Password auth is disabled globally. Certificate-based authentication is
  # enforced via a trusted SSH CA whose public key lives in the nix-nexus
  # certs/ directory alongside the internal PKI CA (certs/int_cert.crt).
  # Operator manages network-level SSH access restrictions externally.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication       = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin              = "prohibit-password";
      # Trust user certificates signed by the fleet SSH CA.
      # Operator places the CA public key at certs/ssh_user_ca.pub.
      # Pattern matches modules/core/security.nix: ../../certs/int_cert.crt
      TrustedUserCAKeys            = toString ../../certs/ssh_user_ca.pub;
    };
    # No listenAddresses restriction — open to 0.0.0.0/0.
  };

  # ── VM guest tools ───────────────────────────────────────────────────────
  # avina runs as a virtual machine. Install the QEMU guest agent for
  # hypervisor integration (graceful shutdown, time sync, snapshot quiescing).
  # Confirm option name via mcp-nixos: get option services.qemuGuest.enable
  services.qemuGuest.enable = true;

  system.stateVersion = "25.11";
}
```

---

## 5. ZFS Disko Layout (`modules/_hw/avina/disko.nix`)

Follow `modules/_hw/petunia/disko.nix` as a structural reference for the ZFS dataset layout,
but **remove the LUKS layer entirely** — avina is a VM; disk encryption is handled by the
hypervisor. The ZFS pool sits directly on the partition, with no `luks` Disko type.

```
Disk: /dev/disk/by-id/OPERATOR-SET-DISK-ID  (or /dev/vda for virtio)
├── Partition 1  1G    vfat    /boot  (EFI; fmask=0077, dmask=0077)
└── Partition 2  100%  ZFS pool: avina  (directly on partition — no LUKS)
    ├── dataset root    /          lz4  atime=off  legacy mountpoint
    ├── dataset nix     /nix       lz4  atime=off  (Nix store)
    ├── dataset var     /var       lz4  atime=off
    ├── dataset data    /var/lib   lz4  atime=off  recordsize=128k
    │   (PostgreSQL 8k pages + Matrix media — balanced with 128k)
    └── zvol   swap     8G
```

Pool options: `ashift=12`, `autotrim=on`. No deduplication. No L2ARC. No swap random
encryption (no LUKS outer layer). ZFS-native encryption may be enabled at the pool level
by the operator if desired, but is not required here.

Disko type chain for the data partition:
```
type = "disk" → content.type = "gpt" → partitions:
  ESP: content.type = "filesystem", format = "vfat", mountpoint = "/boot"
  ZFS: content.type = "zfs", pool = "avina"   ← no "luks" wrapper
```

The `passwordFile = "/tmp/disko-luks-password"` pattern from petunia is **not needed**
and must be omitted. Remove the `boot.initrd.luks.devices` block from
`hardware-configuration.nix` as well.

---

## 6. `flake.nix` Addition

```nix
avina = nixpkgs.lib.nixosSystem {
  system      = "x86_64-linux";
  specialArgs = { inherit inputs; };
  modules = [
    inputs.disko.nixosModules.disko
    ./hosts/avina/default.nix
    home-manager.nixosModules.home-manager
    {
      home-manager = {
        useGlobalPkgs       = true;
        useUserPackages      = true;
        backupFileExtension = "bak";
        extraSpecialArgs     = { inherit inputs; };
        users.ddukes.imports = [
          nixvim.homeModules.nixvim
          ./hosts/avina/home.nix
        ];
      };
    }
  ];
};
```

`hosts/avina/home.nix` — minimal admin (no desktop, no MCP/LLM agents):
```nix
{ ... }: {
  imports = [
    ../../modules/user/bash.nix
    ../../modules/user/neovim-home.nix
    ../../modules/user/dev-home.nix
  ];
  programs.dev-home = {
    enable           = true;
    enableMcpServers = false;
    enableLlmAgents  = false;
  };
  home.stateVersion = "25.11";
}
```

---

## 7. Module Directory Layout

```
modules/
  ├── matrix.nix                   ← gateway aspect: imports modules/_matrix/*
  └── _matrix/                     ← internal service modules (quarantined)
      ├── synapse.nix
      ├── database.nix
      ├── mas.nix
      ├── coturn.nix
      ├── livekit.nix
      ├── element.nix
      ├── haproxy.nix
      ├── vault-secrets.nix
      └── versions.nix
```

---

## 8. Secrets Manifest

All: `root:root`, mode `0600`, provisioned by operator before first boot.

| Path | Contents | Consumer |
|---|---|---|
| `/run/secrets/synapse-secrets.yaml` | `macaroon_secret_key`, `form_secret`, `registration_shared_secret`, `turn_shared_secret`, MSC3861 `client_secret`, `admin_token` | Synapse |
| `/run/secrets/mas-config.yaml` | Full MAS config YAML (Section 3.3) | MAS |
| `/run/secrets/cloudflared-creds.json` | Cloudflare tunnel credentials JSON | cloudflared |
| `/run/secrets/vault-token.env` | `VAULT_TOKEN=<token>` | vault-agent |
| `/run/certs/haproxy.pem` | fullchain+privkey combined; rendered by vault-agent from `kv-v2/letsencrypt/...` | HAProxy stats TLS |
| `/run/certs/turn-fullchain.pem` | fullchain only; rendered by vault-agent | LiveKit `cert` |
| `/run/certs/turn.key` | privkey only; rendered by vault-agent | LiveKit `key` |
| `/run/livekit.key` | Generated by livekit-key.service oneshot | LiveKit + lk-jwt-service |

---

## 9. Verification Checklist

```bash
# Nix correctness
nix flake check
nix build .#nixosConfigurations.avina.config.system.build.toplevel --no-link
statix check .
deadnix .

# HAProxy config validity (run on the host after deploy)
haproxy -c -f /nix/store/.../haproxy.cfg

# Matrix federation
curl "https://federationtester.matrix.org/api/report?server_name=MATRIX_DOMAIN"

# Client API
curl https://MATRIX_DOMAIN/_matrix/client/versions

# Well-known — must include rtc_foci
curl https://MATRIX_DOMAIN/.well-known/matrix/client | python3 -m json.tool

# MAS OIDC discovery
curl https://MAS_DOMAIN/.well-known/openid-configuration

# LiveKit JWT health
curl https://MATRIX_DOMAIN/livekit/jwt/healthz

# Element Web
curl -I https://ELEMENT_DOMAIN

# LiveKit certs rendered by vault-agent
ls -la /run/certs/

# Tailscale not running
systemctl is-active tailscaled 2>/dev/null && echo "ERROR: tailscale running" || echo "OK"
systemctl is-active tailscale-autoconnect 2>/dev/null && echo "ERROR: running" || echo "OK"

# Firewall (from external): 22 + stats + LiveKit open; 80, 443 closed
nmap -p 22,80,443,3478,5349,7881,8404 AVINA_IP

# HAProxy stats page accessible with TLS
curl -k https://AVINA_IP:8404/stats

# Prometheus metrics endpoint
curl -k https://AVINA_IP:8404/metrics | head -20

# QEMU guest agent running
systemctl is-active qemu-guest-agent

# No secrets in Nix store
grep -rn "client_secret\|VAULT_TOKEN\|encryption" \
  /nix/store 2>/dev/null | grep -v ".drv:"
```

---

## 10. Known Risks and Implementation Notes

| Risk | Resolution |
|---|---|
| No NixOS MAS module | Write custom systemd service; query `mcp-nixos` first; use Section 3.3 skeleton |
| PostgreSQL locale for Synapse | `initialScript` with idempotent `CREATE DATABASE ... LC_COLLATE = 'C'` |
| Tailscale in `modules/networking.nix` | `lib.mkForce false` on `services.tailscale.enable` and `tailscale-autoconnect` service; `lib.mkForce` on entire firewall block |
| vault-agent KV-v2 re-render frequency | KV-v2 secrets re-render on version change; ensure the external cert-renewal process increments the KV version so vault-agent picks up the new cert |
| vault-agent fires before services start | `|| true` in commands; `before = ["livekit.service" "haproxy.service"]` in service ordering |
| HAProxy `haproxy.pem` permissions | HAProxy user must read `/run/certs/haproxy.pem`; set mode `0640` and group `haproxy` in the vault-agent `perms` or via `systemd.tmpfiles` |
| HAProxy stats on all interfaces | Port 8404 is open to the internet; TLS is required; admin ACL restricts RFC-1918 + loopback only |
| LiveKit media direct exposure | PORTS 7881, 50100-50200, 3478, 5349 must be opened at the Edge Router via DNAT to avina |
| `federation_domain_whitelist` must include own domain | Always include `MATRIX_DOMAIN` (Synapse issue #4857) |
| MAS encryption secret | Generate once with `openssl rand -hex 32`; never rotate; losing it invalidates all sessions |
| HAProxy raw string config errors | Validate with `haproxy -c -f` before committing; `option http-use-htx` required for `prometheus-exporter` service |
| No LUKS on avina | LXC container; disk encryption handled by hypervisor |
| VM guest agent module name | Query `mcp-nixos` for `services.qemuGuest.enable`; may vary by NixOS version |
| `certs/ssh_user_ca.pub` missing at deploy time | Operator must commit SSH CA public key to `certs/` before build |
| Vault policy for KV read | `VAULT_TOKEN` must have policy granting `read` on `kv-v2/data/letsencrypt/certificates/live/novuscotia.com` |

---

## 11. Glossary

| Term | Definition |
|---|---|
| MAS | Matrix Authentication Service — MSC3861 OIDC provider; Synapse delegates auth |
| MSC3861 | Matrix Spec Change: native OIDC delegation from Synapse to MAS |
| MatrixRTC | Matrix real-time audio/video via WebRTC + LiveKit SFU |
| LiveKit | Open-source WebRTC SFU; MatrixRTC media backbone |
| lk-jwt-service | MatrixRTC Authorization Service; issues LiveKit JWTs for Matrix participants |
| vault-agent | HashiCorp daemon rendering templates from Vault/Consul; manages cert lifecycle |
| Vault KV-v2 | Key-Value secrets engine v2; stores the Let's Encrypt cert at a versioned path |
| cloudflared | Cloudflare Tunnel daemon; carries all inbound signaling (HTTP/S) traffic |
| HAProxy | High-Availability Proxy; sole HTTP reverse proxy on avina; stats+metrics on :8404 |
| nix-nexus.zfs | Custom NixOS option set in `modules/zfs.nix`; ARC + metadata tuning |
| QEMU guest agent | In-guest daemon enabling hypervisor integration (shutdown, time sync, snapshots) |
| Headscale | Self-hosted Tailscale coordination server; future VPN replacement for this fleet |
| SSH CA | Trusted CA whose public key in `certs/ssh_user_ca.pub` authorises all certificate-based logins |

*End of PDB — Matrix 2.0 Homeserver (`avina`)*
