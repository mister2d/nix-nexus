# avina — Protocol & Security Reference

> Canonical reference for all standards, specifications, and security decisions
> implemented in the avina Matrix 2.0 stack. Written to be diagram-friendly and
> approachable. Each section describes what a standard does, why it exists, and
> exactly how this deployment uses it.

---

## Table of Contents

1. [Architecture at a Glance](#1-architecture-at-a-glance)
2. [Authentication — The Identity Layer](#2-authentication--the-identity-layer)
   - [MSC3861 — Native OIDC Delegation](#msc3861--native-oidc-delegation)
   - [MSC2965 — OIDC Discovery via Well-Known (Draft)](#msc2965--oidc-discovery-via-well-known-draft)
   - [MSC4108 — QR Code Login](#msc4108--qr-code-login)
   - [OAuth 2.0 and OpenID Connect Core](#oauth-20-and-openid-connect-core)
   - [JWT Signing Keys — ES384 and RS256](#jwt-signing-keys--es384-and-rs256)
3. [Real-Time Communications — The Calls Layer](#3-real-time-communications--the-calls-layer)
   - [MSC3401 — MatrixRTC Native Group Calls](#msc3401--matrixrtc-native-group-calls)
   - [MSC4143 — RTC Foci and SFU Discovery](#msc4143--rtc-foci-and-sfu-discovery)
   - [MSC2764 — Matrix Widget API](#msc2764--matrix-widget-api)
   - [MSC4190 / MSC3202 — Appservice Device Masquerading (E2EE Bridges)](#msc4190--msc3202--appservice-device-masquerading-e2ee-bridges)
   - [MSC3266 — Room Summary API](#msc3266--room-summary-api)
   - [MSC4222 — state_after for Sync v2](#msc4222--state_after-for-sync-v2)
   - [MSC4140 — Delayed Events (MatrixRTC Heartbeats)](#msc4140--delayed-events-matrixrtc-heartbeats)
4. [Network Transport — The Connectivity Layer](#4-network-transport--the-connectivity-layer)
   - [WebRTC Fundamentals](#webrtc-fundamentals)
   - [ICE — RFC 8445](#ice--rfc-8445)
   - [STUN — RFC 8489](#stun--rfc-8489)
   - [TURN — RFC 8656](#turn--rfc-8656)
   - [DTLS-SRTP — Encrypted Media](#dtls-srtp--encrypted-media)
5. [Client Discovery — The Well-Known Layer](#5-client-discovery--the-well-known-layer)
   - [MSC3575 — Simplified Sliding Sync](#msc3575--simplified-sliding-sync)
6. [Ingress & TLS Architecture](#6-ingress--tls-architecture)
7. [Secrets Architecture](#7-secrets-architecture)
8. [Threat Model and Security Decisions](#8-threat-model-and-security-decisions)

---

## 1. Architecture at a Glance

avina runs what the Matrix ecosystem calls a **"Matrix 2.0"** stack — a specific
combination of components that together deliver modern OIDC-native authentication,
native real-time video/audio calling, and fast client sync. These are not separate
features; they are interconnected layers that share state, secrets, and protocol
identity.

```
┌───────────────────────────────────────────────────────────────────────────────────────────┐
│                                    Three-Path Ingress Model                               │
├───────────────────────────────┬───────────────────────────┬───────────────────────────────┤
│  External — Auth / Web        │  External — RTC           │  Internal (LAN)               │
│  matrix.* / element.* / mas.* │  matrix-rtc.*             │  All domains                  │
│  via Cloudflare Tunnel        │  Direct NAT (edge router) │  via Split-Horizon DNS        │
│                               │                           │                               │
│  Browser → Cloudflare Edge    │  Browser → WAN :443       │  Browser → avina:443          │
│      │       │ (outbound       │      │       │ (DNAT)    │          (direct LAN)         │
│      │       │  tunnel)        │      │       │           │                               │
└──────┼───────┼─────────────────┴──────┼───────┼───────────┴────────────────┼──────────────┘
       └───────┘                        └───────┘                            │
              │                                │                             │
              └────────────────────────────────┴─────────────────────────────┘
                                               │
                                ┌──────────────┴──────────────┐
                                │       avina:443 (HAProxy)   │
                                └──────────────┬──────────────┘
                                               │ TLS terminates at HAProxy
                                               │ Routes by Host header + path prefix
         ┌────────────────────┬────────────────┼────────────────────┬────────────────────┐
         │                    │                │                    │                    │
  element.domain         matrix.domain     mas.domain           rtc.domain          livekit/jwt
  Element Web            Synapse + MAS     MAS (OIDC)          Element Call         lk-jwt-service
  darkhttpd :8082         :8008            :8181 (proxy)       darkhttpd :8084      :8081
```

**Signaling path — matrix.* / element.* / mas.*** (brokered by Cloudflare Tunnel):

```
External Client ──HTTPS──► Cloudflare Edge ──Tunnel──► avina :443 (HAProxy)
                                                        │
                                                        ├── matrix.novuscotia.com  ──► Synapse
                                                        ├── element.novuscotia.com ──► Element Web
                                                        └── mas.novuscotia.com     ──► MAS
```

**Signaling path — matrix-rtc.*** (Direct WAN — bypasses Cloudflare Tunnel entirely):

```
External Client ──HTTPS──► Edge Router :443 ──DNAT──► avina :443 (HAProxy)
                                                        │
                                                        └── matrix-rtc.novuscotia.com ──► Element Call
                                                                                          LiveKit WebSocket
```

**Media path** (Direct WAN/LAN — all domains, entirely separate from signaling):

```
External Client ──UDP/TCP──► WAN IP :3478/5349/7881/50100-50200 ──DNAT──┐
                                                                         │
Internal Client ──UDP/TCP──► avina  :3478/5349/7881/50100-50200 ─────────┼──► LiveKit SFU
```

**Ingress path summary:**
1. **Auth / Matrix / Web signaling:** External clients use the Cloudflare Tunnel (HTTPS) for `matrix.*`, `element.*`, and `mas.*`. Internal clients use **Split-Horizon DNS** to reach `avina:443` directly over the LAN.
2. **RTC signaling:** `matrix-rtc.novuscotia.com` is **not** behind Cloudflare. Port 443 is NAT-forwarded directly at the edge router to `avina:443`. This path carries the Element Call web interface and the LiveKit WebSocket signal connection. It receives no Cloudflare WAF or DDoS protection.
3. **Media:** All domains — external and internal — use direct UDP/TCP to LiveKit's media ports (NAT-forwarded at the edge router). The Cloudflare Tunnel is never involved in media.
4. **Fallback:** If UDP is blocked, **TCP 7881** provides a direct RTP-over-TCP path to LiveKit (not TURN).

---

## 2. Authentication — The Identity Layer

### MSC3861 — Native OIDC Delegation

**What it is.** Matrix Spec Change 3861 defines how a Matrix homeserver (Synapse)
delegates all user authentication to an external OpenID Connect provider. Before
MSC3861, Synapse managed its own password database and login flows. MSC3861 allows
Synapse to offload this entirely to a dedicated OIDC service.

**Why it exists.** Matrix's original authentication model was bespoke — usernames,
passwords, and session tokens all lived in Synapse's database. This prevented
integration with enterprise SSO systems, made password policies impossible to
enforce centrally, and created a second credential database to protect. MSC3861
makes Matrix a first-class participant in the OAuth 2.0 ecosystem.

**How this deployment implements it.**

Synapse is configured (via `/run/secrets/synapse-secrets.yaml`, rendered at boot by
vault-agent) with:

```yaml
matrix_authentication_service:
  enabled: true
  endpoint: "http://127.0.0.1:8182"  # MAS internal listener
  secret: "<shared secret>"           # Proves Synapse's identity to MAS
```

The `endpoint` is MAS's internal-only listener (`8182`) — not the public-facing
one. This listener is specifically for Synapse-to-MAS communication and does not
require proxy-protocol headers.

When Synapse has `matrix_authentication_service.enabled: true`:
1. **All Matrix `/_matrix/client/v*/login` requests are intercepted by MAS**, not
   Synapse. HAProxy routes these paths (`path_reg ^/_matrix/client/[^/]+/(login|logout|refresh)`)
   to the MAS backend.
2. **Synapse's password login is disabled** (`password_config.enabled: false`).
3. **Synapse advertises `m.authentication` in `/_matrix/client/v3/capabilities`**,
   telling clients to use OIDC directly.

The shared secret in the Synapse config is a HMAC key that MAS and Synapse use to
sign internal tokens when Synapse needs to make admin calls to MAS
(e.g., provisioning a user after a successful OIDC login). This secret is separate
from any user credential.

**Security properties of MSC3861:**
- No Matrix password database exists. Compromise of Synapse's database exposes
  message content but not credentials.
- Session revocation in Keycloak propagates to Matrix: when a Keycloak account is
  disabled, MAS's next token-refresh attempt fails, and the client is logged out.
- All login audit trails flow through a single system (MAS/Keycloak), not split
  between Matrix and external IdPs.

---

### MSC2965 — OIDC Discovery via Well-Known (Draft)

**What it is.** MSC2965 defines a way for Matrix clients to discover the OIDC
provider for a homeserver through the standard `/.well-known/matrix/client` JSON
file, without having to query the homeserver capabilities endpoint first.

**Why it exists.** The standard Matrix client startup sequence requires multiple
network round-trips: discover homeserver, fetch capabilities, find OIDC provider.
MSC2965 short-circuits this by embedding OIDC provider metadata directly into the
well-known response that clients already fetch.

**How this deployment implements it.**

The well-known JSON (served by darkhttpd at `:8083`, path-rewritten by HAProxy from
`/.well-known` → bare path) contains two overlapping OIDC advertisement keys:

```json
{
  "m.authentication": {
    "issuer": "https://mas.example.com/",
    "account": "https://mas.example.com/account"
  },
  "org.matrix.msc2965.authentication": {
    "issuer": "https://mas.example.com/",
    "account": "https://mas.example.com/account"
  }
}
```

Both keys carry identical content. `m.authentication` is the **stable MSC3861
key** used by current Element clients and Element Call for native OIDC discovery.
`org.matrix.msc2965.authentication` is the **draft key** retained for older client
versions that pre-date the stable spec. Serving both ensures no client is locked
out during the ecosystem's transition period.

**Diagram: Client OIDC Discovery Sequence**

```
Client
  │ 1. GET /.well-known/matrix/client
  ▼
HAProxy → darkhttpd :8083
  │ Returns JSON with m.authentication.issuer = "https://mas.domain/"
  ▼
Client
  │ 2. GET https://mas.domain/.well-known/openid-configuration
  ▼
MAS (OIDC discovery document)
  │ Returns authorization_endpoint, token_endpoint, registration_endpoint, ...
  ▼
Client
  │ 3. POST registration_endpoint (dynamic client registration)
  ▼
MAS (issues client_id for this client instance)
  │ Returns { client_id, ... }
  ▼
Client
  │ 4. Browser redirect → authorization_endpoint (OIDC Authorization Code + PKCE)
  ▼
MAS → Keycloak (upstream IdP)
  │ User authenticates with Keycloak credentials
  ▼
MAS (issues Matrix access token + refresh token)
  │
  ▼
Client uses access token for all Matrix API calls to Synapse
```

---

### MSC4108 — QR Code Login

**What it is.** MSC4108 defines a protocol for logging into a Matrix account by
scanning a QR code displayed by an already-authenticated device. The new device
generates a QR code; the existing device scans it and approves the login without
the user entering a password.

**Why it exists.** Typing a password on a mobile keyboard into a new device is
error-prone. QR code login eliminates password entry for secondary device setup
entirely.

**How this deployment implements it.**

Enabled in Synapse via `synapse.nix`:

```nix
experimental_features.msc4108_enabled = true;
```

MSC4108 in Synapse provides the **rendezvous endpoint** (`/_matrix/client/unstable/
org.matrix.msc3886/rendezvous`) that the two devices use to exchange cryptographic
handshake data. MAS provides the actual authorization approval UI. Synapse validates
at startup that MAS is enabled before allowing MSC4108 — there is a hard dependency
check.

**What does not live in MAS for QR login.** Despite MAS being the auth service,
the MSC4108 rendezvous mechanism is Synapse-side. MAS brokers the final token
issuance but does not implement the QR code handshake itself. The Synapse
`experimental_features.msc4108_enabled` flag is the only configuration required;
no MAS config changes are needed.

---

### OAuth 2.0 and OpenID Connect Core

**What they are.**

- **OAuth 2.0 (RFC 6749)** is an authorization delegation framework. It defines
  how a user can authorize a client application to act on their behalf without
  sharing credentials. The key flows are Authorization Code (browser redirect),
  Client Credentials (machine-to-machine), and Refresh Token.

- **OpenID Connect Core (OIDC)** is a thin identity layer on top of OAuth 2.0.
  Where OAuth 2.0 says "this token lets you do X on behalf of user Y," OIDC adds
  "and here is a signed JWT (ID token) proving who user Y is."

- **PKCE (Proof Key for Code Exchange, RFC 7636)** is a security extension to the
  Authorization Code flow that prevents authorization code interception attacks.
  Public clients (browser apps like Element Web and Element Call) are required to
  use PKCE because they cannot securely store a client secret.

**How this deployment uses them.**

MAS is an OAuth 2.0 Authorization Server and OpenID Connect Provider. It implements:

| Component | Role |
|---|---|
| Authorization Endpoint | Browser redirects here to begin login |
| Token Endpoint | Exchanges authorization codes for access/refresh/ID tokens |
| Registration Endpoint | Clients dynamically register to get a `client_id` |
| JWKS Endpoint | Publishes MAS's public signing keys so token recipients can verify signatures |
| Userinfo Endpoint | Returns identity claims for the authenticated user |
| Discovery Document | `/.well-known/openid-configuration` — advertises all endpoints |

**The three-party relationship:**

```
Keycloak (upstream IdP)
  ↑ MAS authenticates to Keycloak via OIDC Authorization Code flow
  │ Client ID / secret stored in Vault; never in Nix store
MAS (OIDC Provider / Authorization Server)
  ↑ Element Web / Element Call authenticate to MAS via OIDC Authorization Code + PKCE
  │ Clients register dynamically; no pre-shared client secrets for browser clients
Synapse (Resource Server)
  ← Clients present MAS-issued access tokens
  ← Synapse validates tokens against MAS's JWKS endpoint
```

Clients (Element Web, Element Call) authenticate to MAS — not to Keycloak directly.
MAS brokers the upstream identity and issues its own tokens. This means Synapse does
not need to know anything about Keycloak's existence or configuration.

**Dynamic client registration (RFC 7591)** is how Element Call acquires its
`client_id`. Element Call is a public SPA — it has no client secret and cannot be
pre-registered with a stable identifier. Instead, on first use, it calls MAS's
`registration_endpoint` to register itself and receives a fresh `client_id`. MAS's
OPA-based policy controls which registrations are accepted. This deployment sets
`policy.data.client_registration.allow_missing_client_uri: true` because Element
Call (using `oidc-client-ts`) does not include a `client_uri` in its registration
request.

---

### JWT Signing Keys — ES384 and RS256

**What they are.** JSON Web Tokens (JWTs, RFC 7519) are signed by the issuer so
recipients can verify they are authentic. The signature algorithm determines the
cryptographic properties of this guarantee. MAS uses two algorithms:

**ES384 (ECDSA with P-384 curve and SHA-384)** — the primary signing key.
- P-384 is an NIST elliptic curve offering ~192-bit security.
- ES384 signatures are compact (96 bytes vs ~512 bytes for RSA-2048).
- Timing-safe: ECDSA private key operations are inherently resistant to timing
  side-channel attacks in well-implemented libraries.
- Modern clients (Element Web, Element X) advertise `["ES384", "RS256"]` in their
  `id_token_signed_response_alg` preference; MAS selects ES384 when available.

**RS256 (RSA with PKCS#1 v1.5 and SHA-256)** — the compliance key.
- RSA-4096 is used (stronger than the common RSA-2048) to maximise the strength
  of the required compliance key.
- Required by OpenID Connect Core §10.1: "the Authorization Server MUST support
  RS256." Older or spec-strict clients may only accept RS256.
- Computationally more expensive than ES384; kept solely for spec compliance.

**Implementation.** Both keys are stored in Vault KV-v2
(`kv-v2/infrastructure/matrix/avina/mas`) and rendered to `/run/secrets/` by
vault-agent at boot. MAS reads them via `key_file:` entries in its config:

```yaml
secrets:
  keys:
    - kid: "mas-rsa-01"
      key_file: /run/secrets/mas-signing-rsa.key   # RSA-4096, PKCS#1 format
    - kid: "mas-ec-01"
      key_file: /run/secrets/mas-signing-ec.key    # P-384, SEC1 format
```

**Critical operational constraint: these keys must never be rotated after production
use.** Changing a signing key invalidates all active sessions and issued tokens —
every logged-in user is forcibly logged out and must re-authenticate. Treat them as
a master key and store them only in Vault.

---

## 3. Real-Time Communications — The Calls Layer

### MSC3401 — MatrixRTC Native Group Calls

**What it is.** MSC3401 defines how Matrix clients coordinate real-time audio/video
calls by publishing state events in a Matrix room. Rather than a bespoke calling
protocol, MatrixRTC uses Matrix's existing room state infrastructure as the
signaling channel.

**Why it exists.** The original Matrix VoIP (MSC2746) was designed for 1:1 calls
and used Jitsi as an external bridge for group calls. Jitsi integration was
architecturally awkward (an out-of-band widget with its own auth and connection
management). MSC3401 replaces this with a first-class group calling primitive built
directly on Matrix room membership.

**How a MatrixRTC call works.** When a user starts a call:

1. A new Matrix room is created (or an existing room is used).
2. Clients join the call by publishing `org.matrix.msc3401.call.member` state
   events in the room, advertising their supported media capabilities.
3. The SFU (LiveKit) acts as a central media relay. Clients do not connect
   directly to each other (mesh) — they connect to LiveKit which mixes and routes
   media.
4. The `lk-jwt-service` issues short-lived LiveKit JWTs to authenticated Matrix
   users, proving their identity to the SFU.
5. Media flows via WebRTC from client → LiveKit (direct UDP, TURN relay, or TCP
   fallback), encrypted with DTLS-SRTP.

**How this deployment implements it.** Element Web is configured with:

```json
"element_call": {
  "url": "https://call.example.com",
  "use_exclusively": true
}
```

`use_exclusively: true` disables the legacy Jitsi call path. All group calls use
Element Call (MSC3401 / MatrixRTC). `url` points to the self-hosted Element Call
instance; without it, Element Web defaults to the public `call.element.io`.

---

### MSC4143 — RTC Foci and SFU Discovery

**What it is.** MSC4143 defines how Matrix clients discover which SFU (Selective
Forwarding Unit) to connect to for a given MatrixRTC session. A "focus" is a media
relay endpoint; clients publish their preferred focus, and the room converges on a
shared one.

**Why it exists.** With MSC3401, any SFU could in theory be used. Without a
discovery mechanism, clients have no way to know which SFU is authoritative for
this homeserver. MSC4143 solves this by advertising SFU endpoints in the homeserver's
well-known response, making SFU discovery automatic.

**How this deployment implements it.** The well-known JSON includes:

```json
"org.matrix.msc4143.rtc_foci": [
  {
    "type": "livekit",
    "livekit_service_url": "https://matrix.example.com/livekit/jwt"
  }
],
"matrix_rtc": {
  "foci": [
    {
      "type": "livekit",
      "livekit_service_url": "https://matrix.example.com/livekit/jwt"
    }
  ],
  "urn:matrix:org.matrix.msc3861:livekit": {
    "preferred_url": "https://matrix-rtc.example.com/livekit/sfu"
  }
}
```

This tells any client that discovers this homeserver: "for MatrixRTC calls, connect
to this LiveKit instance, and get your JWT from this URL." The inclusion of the
`foci` array inside the `matrix_rtc` key is a mandatory requirement for newer
Element Web (JS SDK) versions to successfully initiate calls.

The client:

1. Fetches the well-known and finds `rtc_foci` or `matrix_rtc.foci`.
2. Requests a LiveKit JWT from `livekit_service_url` (authenticated with its Matrix
   access token).
3. `lk-jwt-service` validates the Matrix token and issues a LiveKit JWT scoped to
   the room and user.
4. Client connects to LiveKit via WebSocket with that JWT.

**The LiveKit URL structure.** HAProxy routes `path_beg /livekit/jwt` to `lk-jwt-service`
on `:8081` and `path_beg /livekit/sfu` to LiveKit on `:7880`. The WebSocket
upgrade for LiveKit signaling is handled by the `timeout tunnel 3600s` default
in HAProxy, which keeps the connection open for the duration of a call.

---

### MSC2764 — Matrix Widget API

**What it is.** MSC2764 (also known as the Matrix Widget API) defines how a Matrix
client (Element Web) can host a web application (Element Call) in an iframe and
mediate its access to the Matrix homeserver. The hosted app communicates with the
host via `postMessage` (browser cross-origin messaging).

**Why it exists.** Without a widget API, an embedded call app would need its own
login flow — or be given the user's access token directly (which would be a
security risk). The Widget API lets the host (Element Web) act as a gatekeeper:
the embedded app makes requests, and the host decides which Matrix API calls to
approve and execute on its behalf.

**How this deployment implements it.** When Element Web opens a call, it creates an
iframe pointing to:

```
https://call.example.com/?widgetId=<id>&parentUrl=<element-web-origin>
  &roomId=!room:matrix.example.com&userId=@alice:matrix.example.com
  &deviceId=DEVICEID&baseUrl=https://matrix.example.com
```

Element Call detects these URL parameters (from `widget.ts` in its source):

```typescript
const { widgetId, parentUrl } = getUrlParams();
if (widgetId && parentUrl) {
  // Widget mode: create a "matryoshka MatrixClient"
  const client = createRoomWidgetClient(api, capabilities, roomId, {
    baseUrl, userId, deviceId, ...
  });
  // No access token is passed here — all Matrix API calls are
  // proxied through postMessage to Element Web
}
```

The `createRoomWidgetClient()` ("matryoshka MatrixClient", named in the source
comments) creates a Matrix SDK client that **does not make direct HTTP requests**.
Every Matrix API call Element Call needs (send event, receive event, to-device
message) is forwarded via `postMessage` to Element Web, which executes it with its
own session credentials and sends the result back.

**What this means for authentication:** Element Call in widget mode has zero access
to the user's Matrix access token. There is no credential to steal from the widget
iframe. Element Web enforces the boundary. This is why the standalone
`call.example.com` login page is irrelevant for widget-mode calls — authentication
never goes through the standalone path.

**The standalone redirect.** Direct browser visits to `call.example.com` (without
a `widgetId` parameter) are redirected 302 to Element Web:

```haproxy
backend element_call_backend
  http-request redirect code 302 location https://element.example.com unless { query -m sub widgetId }
  server element_call 127.0.0.1:8084
```

Note: HAProxy's `http-request return` and `http-request redirect` do not support
backslash line continuation; the directive must be on a single line.

Widget iframes always include `widgetId` and pass through unmodified. This closes
the "orphan standalone login form" UX gap while keeping the domain accessible for
its intended purpose.

---

### MSC4190 / MSC3202 — Appservice Device Masquerading (E2EE Bridges)

**What they are.** MSC3202 (draft) and MSC4190 (stable) define a mechanism for
Matrix application services (bridges) to create encrypted devices without going
through the standard `m.login.application_service` login flow. Instead, the
bridge receives device keys and one-time keys via an extended `/sync` response
and manages E2EE on behalf of ghost users using the appservice's own identity.

**Why they exist.** When Synapse delegates authentication to MAS (MSC3861), the
`m.login.application_service` login type — which bridges historically used to
bootstrap E2EE device creation — is removed. Bridges that enable E2EE would fail
at startup with "homeserver does not support appservice login". MSC4190 provides
an alternative path that is compatible with MAS-enabled homeservers.

**How this deployment implements it.** The `mautrix-whatsapp` bridge is configured
with `encryption.msc4190: true` in its settings. This activates device masquerading
instead of the incompatible application-service login flow. The appservice
registration file (auto-generated by the NixOS module at
`/var/lib/mautrix-whatsapp/whatsapp-registration.yaml`) advertises the `msc4190`
capability to Synapse.

**Bridge-to-homeserver routing.** Synapse with MAS enabled removes
`/_matrix/client/*/login` entirely. Bridges need this endpoint for their startup
capability check. An internal HAProxy frontend on `127.0.0.1:8090` (no TLS,
loopback only) provides bridge-optimised routing:
- `/_matrix/client/*/login|logout|refresh` → MAS compat backend (provides login flows)
- All other Matrix CS API calls → Synapse backend

Bridges set `homeserver.address: http://127.0.0.1:8090` to use this frontend
rather than pointing directly at Synapse.

---

### MSC3266 — Room Summary API

**What it is.** MSC3266 defines a `/_matrix/client/v1/rooms/{roomId}/summary`
endpoint that returns a room's name, avatar, join rules, and member count without
requiring the client to join the room first.

**Why it matters for MatrixRTC.** Element Call uses MSC3266 for the federation
**knocking flow** in standalone mode: when a user on an external homeserver is
invited to join a call room, Element Call fetches the room summary across federation
to display call metadata before the user accepts. Without MSC3266, the standalone
join-via-knock flow cannot resolve room information.

**How this deployment implements it.**

```nix
experimental_features.msc3266_enabled = true;
```

---

### MSC4222 — state_after for Sync v2

**What it is.** MSC4222 adds a `state_after` field to the Matrix sync v2 response
(`/sync`). Standard sync v2 sends `state` containing a snapshot of room state
*before* the timeline events in the response. MSC4222 adds the state *after* all
timeline events, giving clients an accurate view of current room membership.

**Why it matters for MatrixRTC.** Element Call relies on precise room state to
track which participants are actively in a call. Without `state_after`, clients can
observe stale membership state when a participant joins or leaves during a sync
window, leading to incorrect participant lists during calls.

**How this deployment implements it.**

```nix
experimental_features.msc4222_enabled = true;
```

---

### MSC4140 — Delayed Events (MatrixRTC Heartbeats)

**What it is.** MSC4140 defines a mechanism for sending Matrix events with a
server-side delay. Clients send a "delayed event" with a TTL; if the client does
not refresh the delay (heartbeat), the server delivers the event after the TTL
expires.

**Why it matters for MatrixRTC.** Call participants periodically send delayed
`org.matrix.msc3401.call.member` state events. If a client disconnects unexpectedly
(crash, network loss), the delayed event fires automatically after the TTL, removing
the participant from the room. Without MSC4140, participants appear stuck in calls
indefinitely after an abnormal disconnect.

**How this deployment implements it.**

```nix
max_event_delay_duration = "24h";  # Maximum TTL Synapse will accept for delayed events
```

Rate limits are also tuned to accommodate the MatrixRTC heartbeat (0.2 events/s
steady-state):

```nix
rc_message         = { per_second = 0.5; burst_count = 30; };
rc_delayed_event_mgmt = { per_second = 1; burst_count = 20; };
```

---

## 4. Network Transport — The Connectivity Layer

### WebRTC Fundamentals

WebRTC (Web Real-Time Communication) is a browser/application standard that enables
direct peer-to-peer (or peer-to-SFU) audio, video, and data exchange. It is not a
single protocol — it is a stack of interoperating protocols:

| Protocol | Layer | Role |
|---|---|---|
| ICE | Connection | Finds a path between two endpoints |
| STUN | Connection | Discovers public IP/port via a relay server |
| TURN | Connection | Relays media when direct connection fails |
| DTLS | Security | Establishes an encrypted channel (like TLS, but for UDP) |
| SRTP | Media | Encrypts the actual audio/video streams |
| SDP | Signaling | Describes what media each side can send/receive |

In this deployment, **connection establishment** (ICE/STUN/TURN) uses LiveKit's
built-in TURN server for relay and LiveKit for direct media. The **media relay** is
handled by LiveKit's SFU. Clients never connect directly to each other; all media
paths go through LiveKit.

---

### ICE — RFC 8445

**What it is.** Interactive Connectivity Establishment (ICE) is the algorithm
WebRTC uses to find the best network path between two endpoints. ICE tries multiple
candidate paths in parallel — direct connection, via STUN, via TURN — and picks
the one that works first.

**The three candidate types ICE tries:**
1. **Host candidates** — direct LAN IP addresses.
2. **Server-reflexive (srflx) candidates** — the client's public IP/port as seen
   from outside, discovered via STUN.
3. **Relayed (relay) candidates** — an address at the TURN server that will relay
   all media.

**ICE candidate selection in this deployment.** LiveKit is configured with
`ips.includes = ["10.0.1.7/32"]` — the LAN IP of avina — and deliberately omits
`use_external_ip = true`. This is the key design decision for this network topology:
avina is an LXC container on the internal LAN; the WAN IP (`151.196.33.88`) belongs
to the edge router, not to avina. Enabling `use_external_ip` would cause LiveKit to
STUN-discover the WAN IP and use it for both ICE host candidates and TURN relay
allocation — producing two simultaneous silent failures: (1) ICE host candidates at
the WAN IP are unreachable internally because hairpin NAT is not implemented;
(2) TURN relay allocation tries to bind sockets to the WAN IP, which is not a local
interface on avina, producing zero relay candidates even though credentials are issued.

By advertising `10.0.1.7` directly instead:
- **LAN clients** receive a valid host candidate (`10.0.1.7`) and connect directly.
- **WAN clients** receive TURN relay credentials; TURN binds relay sockets to
  `10.0.1.7` (a real local interface), and the relay is reachable externally via
  NAT forwarding at ports `3478`/`5349`.
- **TCP fallback**: port `7881` for clients where all UDP is blocked.

Split-horizon DNS makes this work transparently: `matrix-rtc.novuscotia.com`
resolves to `10.0.1.7` for internal clients (direct host path) and to
`151.196.33.88` externally (TURN relay via NAT-forwarded ports). Hairpin NAT is
explicitly not implemented and will not be.

---

### STUN — RFC 8489

**What it is.** Session Traversal Utilities for NAT (STUN) is a simple
request/response protocol. A client behind a NAT router sends a UDP packet to a
STUN server; the STUN server replies with the client's public IP and port number
as seen from the internet. The client can then advertise this as an ICE candidate.

**Role in this deployment.** LiveKit's built-in TURN server implements STUN on
port `3478` (UDP and TCP). Clients use this to discover their public-facing
address. STUN itself does not relay any media — it is only for address discovery.

---

### TURN — RFC 8656

**What it is.** Traversal Using Relays around NAT (TURN) extends STUN with
**media relay** capability. When direct or server-reflexive ICE candidates fail
(e.g., both peers are behind symmetric NATs, or a firewall blocks inbound UDP), a
TURN server steps in as a relay: both sides send their media to the TURN server,
which forwards it between them.

**Implementation in this deployment.** LiveKit's built-in TURN server (based on
pion/turn) handles relay in place of an external coturn process. LiveKit generates
per-session HMAC credentials internally and embeds them in the LiveKit JWT issued
by `lk-jwt-service`. Clients do not need to call Synapse for TURN credentials —
the LiveKit JWT response includes ICE server info with TURN endpoints and
time-limited credentials.

LiveKit TURN is configured in `livekit.nix`:

```nix
turn = {
  enabled = true;
  domain = rtcDomain;
  tls_port = 5349;
  udp_port = 3478;
  cert_file = "/run/certs/turn-fullchain.pem";
  key_file  = "/run/certs/turn.key";
};
```

`use_external_ip` is intentionally absent (see ICE section above). LiveKit's TURN
server binds relay sockets to the IP LiveKit has selected for itself — `10.0.1.7`
in this deployment. Because `10.0.1.7` is a real local interface on avina (not a
WAN IP residing at the edge router), relay allocation succeeds. External clients
reach the TURN server via NAT forwarding at the edge router (ports `3478`/`5349`).

**The RTC Domain.** `rtcDomain` (`matrix-rtc.novuscotia.com`) is the dual-purpose
ingress domain: it serves Element Call and proxies LiveKit signaling. For TURN, it
resolves via **Split-Horizon DNS** to `10.0.1.7` for internal clients (direct LAN)
and to `151.196.33.88` externally (NAT-forwarded at the edge). This ensures TURN
relay is reachable from both paths without hairpin NAT.

**Ports and protocols.**

| Port | Protocol | Purpose |
|---|---|---|
| 3478 | UDP | STUN/TURN (standard) |
| 3478 | TCP | STUN/TURN (TCP fallback for UDP-blocked clients) |
| 5349 | TCP/TLS | TURNS — TURN over TLS (additional firewall traversal) |
| 50100–50200 | UDP | WebRTC media direct to SFU (ICE direct path) |
| 7881 | TCP | RTP-over-TCP direct to SFU (not TURN — for clients where all UDP is blocked) |

**SSRF gap (accepted risk).** LiveKit's pion/turn implementation does not expose a
configurable `denied-peer-ip` list equivalent to coturn's. A malicious client with
valid TURN credentials could theoretically use the relay to probe RFC-1918 or
loopback addresses. This risk is **accepted** and **mitigated** — TURN credentials
are gated behind LiveKit JWT issuance, which requires a valid Matrix access token
validated by `lk-jwt-service`. An unauthenticated client cannot obtain credentials.
The attack surface is limited to authenticated Matrix users on this homeserver.

---

### DTLS-SRTP — Encrypted Media

**DTLS (Datagram TLS, RFC 6347)** is TLS adapted for UDP. It performs a
cryptographic handshake between two WebRTC endpoints to establish session keys.
The DTLS handshake is initiated after ICE completes a path.

**SRTP (Secure RTP, RFC 3711)** encrypts the actual audio/video stream using keys
derived from the DTLS handshake. Every RTP packet sent over the wire is encrypted.

**In this deployment:** DTLS-SRTP operates between each client and LiveKit (not
between clients directly, since this is an SFU topology). LiveKit terminates the
DTLS session, decrypts the SRTP stream, processes it (mix/route), and re-encrypts
it for each recipient. This is a "media relay with decryption" model — it is
confidential in transit but the SFU can see the plaintext media content. This is
the standard trade-off of SFU-based calling versus E2E-encrypted mesh calling.

---

## 5. Client Discovery — The Well-Known Layer

Two well-known files are served by darkhttpd at `:8083`, path-rewritten by HAProxy
from `/.well-known/*` to the bare path. Both are static JSON derived from Nix
expressions and cached in the store.

**Content-Type caveat.** darkhttpd serves files without extensions (e.g.,
`matrix/client`, `matrix/server`) as `application/octet-stream`. matrix-js-sdk
silently rejects any well-known response whose `Content-Type` is not
`application/json`, leaving `getClientWellKnown()` empty. HAProxy's
`wellknown_backend` overrides the response header
(`http-response set-header Content-Type "application/json"`) to correct this.
Without the override, Element Web fails to discover `org.matrix.msc4143.rtc_foci`
and reports `MISSING_MATRIX_RTC_FOCUS`.

**`/.well-known/matrix/client`** — the client discovery entry point, consumed by
Matrix clients to bootstrap the homeserver connection and discover OIDC, SFU, and
sync endpoints.

**`/.well-known/matrix/server`** — the federation server discovery document,
consumed by remote homeservers and internal services (including `lk-jwt-service`)
to determine which port to use for federation connections. Without this file,
federation clients fall back to port 8448 (the Matrix default), which is not
open on avina.

**`/.well-known/matrix/client`:**

```json
{
  "m.homeserver": {
    "base_url": "https://matrix.example.com"
  },
  "m.authentication": {
    "issuer": "https://mas.example.com/",
    "account": "https://mas.example.com/account"
  },
  "org.matrix.msc2965.authentication": {
    "issuer": "https://mas.example.com/",
    "account": "https://mas.example.com/account"
  },
  "org.matrix.msc3575.proxy": {
    "url": "https://matrix.example.com"
  },
  "org.matrix.msc4143.rtc_foci": [
    {
      "type": "livekit",
      "livekit_service_url": "https://matrix.example.com/livekit/jwt"
    }
  ]
}
```

| Key | Protocol | What clients do with it |
|---|---|---|
| `m.homeserver` | Matrix Core | Connect to Synapse for all Matrix API calls |
| `m.authentication` | MSC3861 (stable) | Discover MAS as the OIDC provider |
| `org.matrix.msc2965.authentication` | MSC2965 (draft) | Same as above, for older clients |
| `org.matrix.msc3575.proxy` | MSC3575 | Use Sliding Sync for efficient room list updates |
| `org.matrix.msc4143.rtc_foci` | MSC4143 | Use this LiveKit SFU for MatrixRTC calls |

**`/.well-known/matrix/server`:**

```json
{ "m.server": "matrix.example.com:443" }
```

Tells remote servers and internal services to reach this homeserver on port 443
(HAProxy), not the Matrix default 8448. Required for `lk-jwt-service`, which
performs `/_matrix/federation/v1/openid/userinfo` calls to verify client OpenID
tokens during JWT issuance.

---

### MSC3575 — Simplified Sliding Sync

**What it is.** MSC3575 defines a new Matrix sync API (`/sync/v3`) that replaces
the original `/sync` endpoint. The original sync sends the entire room list and all
new events to the client on every poll. Sliding Sync sends only what the client is
currently displaying — a "window" into the room list — dramatically reducing
bandwidth and processing time.

**Why it matters.** The original Matrix sync was the primary cause of slow client
startup times (the "initial sync" could take tens of seconds for accounts with many
rooms). Sliding Sync eliminates this by lazy-loading room data as needed.

**How this deployment implements it.** Synapse 1.149.1 has Sliding Sync built in
natively (earlier versions required a separate proxy). The well-known
`org.matrix.msc3575.proxy` key points to `https://matrix.example.com` (Synapse
itself). Clients that support MSC3575 use the native Synapse endpoint directly.

---

## 6. Ingress & TLS Architecture

### Hybrid Ingress Model

avina employs a "Split-Ingress" strategy to balance public security with local
performance. This provides a robust and high-performance ingress model for
self-hosted Matrix deployments.

#### 1. External Ingress — Cloudflare Tunnel (matrix.* / element.* / mas.*)

For the Matrix homeserver, Element Web, and MAS auth domains, avina is not
directly internet-reachable. A Cloudflare Tunnel connector running on a
**separate node near the network edge** maintains a persistent outbound connection
to Cloudflare's edge. Inbound HTTPS requests arrive at Cloudflare, traverse the
tunnel, and land at `avina:443`.

This means (for these domains):
- Port 443 is not open on the WAN firewall — inbound traffic enters only via the tunnel.
- DDoS mitigation, WAF, and bot protection are handled at Cloudflare before
  traffic reaches avina.
- The tunnel is authenticated with a Cloudflare-issued credential stored in Vault.

#### 2. External Ingress — Direct NAT (matrix-rtc.*)

`matrix-rtc.novuscotia.com` (the RTC domain) is **not** behind the Cloudflare
Tunnel. Port 443 is NAT-forwarded directly at the edge router to `avina:443`.
This path handles the Element Call web interface (HTTPS) and LiveKit WebSocket
signaling. All LiveKit media ports (3478/5349/7881/50100–50200) are also
NAT-forwarded at the edge.

This path carries **no Cloudflare WAF or DDoS protection** — traffic arrives
directly from the internet. The trade-off is intentional: LiveKit's media and
WebSocket connections require direct reachability that the Cloudflare Tunnel
cannot provide for UDP media or the low-latency WebSocket upgrade.

#### 3. Internal Ingress (Split-Horizon DNS)

When a client is on the same local network as avina, **Split-Horizon DNS**
(configured at the edge router) resolves all stack domains — including
`matrix-rtc.novuscotia.com` — to `avina`'s internal LAN IP (`10.0.1.7`).
Traffic goes directly to `avina:443` without leaving the LAN.

This means:
- **Direct LAN speed:** Signaling and media traffic stay on-LAN with no WAN hop.
- **Privacy:** Internal communication metadata remains within the local network.
- **Logging:** HAProxy sees the real internal client IP for all domains.

### TLS Architecture

The number of TLS hops depends on which ingress path is used:

```
matrix.* / element.* / mas.* (external):
  Browser ──TLS#1──► Cloudflare edge ──TLS#2 (tunnel)──► avina:443 (HAProxy)
  Two TLS sessions; Cloudflare terminates TLS#1, connector re-encrypts for TLS#2.

matrix-rtc.* (external):
  Browser ──TLS#1────────────────────────────────────────► avina:443 (HAProxy)
  Single TLS session; no Cloudflare intermediary.

All domains (internal / LAN):
  Browser ──TLS#1────────────────────────────────────────► avina:443 (HAProxy)
  Single TLS session; HAProxy terminates directly.

HAProxy terminates TLS and routes all traffic to backends over plain HTTP.
```

The Let's Encrypt wildcard certificate (`*.novuscotia.com`) is used by HAProxy
for all TLS termination — both the Cloudflare tunnel leg and the direct connections.
It is issued and renewed by an external certbot process. On renewal, certbot writes
the new certificate into Vault KV-v2. vault-agent detects the version increment,
re-renders `/run/certs/haproxy.pem` and the LiveKit TURN cert files, and signals
HAProxy (`systemctl reload-or-restart`) and LiveKit (`systemctl restart`) —
zero-downtime rotation with no manual intervention on avina.

**`noTLSVerify: true` on the cloudflared connector:** The LE cert covers
`*.novuscotia.com` but the connector reaches avina via its LAN hostname
(`avina.home.lan`), causing a hostname mismatch. `noTLSVerify: true` suppresses
the check. The risk is accepted because both endpoints are on a controlled, trusted
LAN segment; the session is still encrypted against passive eavesdropping.

### HAProxy TLS Configuration

```
ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:...
ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:...
ssl-default-bind-options no-sslv3 no-tlsv10 no-tlsv11 no-tls-tickets
```

- **TLS 1.0 and 1.1 disabled** — both are deprecated and have known weaknesses.
- **TLS 1.2 minimum** with forward-secret cipher suites only (ECDHE key exchange).
- **TLS 1.3** supported via the ciphersuites line.
- **Session tickets disabled** (`no-tls-tickets`) — prevents ticket-based session
  resumption which can compromise forward secrecy if the ticket key leaks.

### HAProxy Routing Logic

```
Incoming request
  │
  ├─ Host: mas.domain          → MAS backend (OIDC flows)
  ├─ path_reg ^/_matrix/client/[^/]+/(login|logout|refresh)
  │                             → MAS backend (compat layer)
  ├─ path_beg /complete-compat-sso
  │                             → MAS backend (SSO callback)
  ├─ path_beg /_matrix or /_synapse
  │                             → Synapse backend
  ├─ path_beg /.well-known     → darkhttpd :8083 (path-rewritten)
  ├─ path_beg /livekit/jwt     → lk-jwt-service :8081
  ├─ path_beg /livekit/sfu     → LiveKit :7880 (WebSocket)
  ├─ path_beg /tos             → darkhttpd :8085 (Terms of Service)
  ├─ Host: call.domain         → Element Call :8084
  │         (302 redirect to element.domain unless widgetId in query)
  └─ default                   → Element Web :8082
```

The MAS compat routing (`path_reg login|logout|refresh`) catches legacy Matrix
client API paths that older or compatibility-mode clients use, and routes them to
MAS's compatibility layer rather than Synapse. Synapse no longer handles these
paths when MAS is enabled.

`send-proxy` on the MAS backend enables HAProxy PROXY protocol v2, which passes
the real client IP to MAS for rate limiting. MAS is configured with
`proxy_protocol: true` on its web listener.

---

## 7. Secrets Architecture

### The Core Principle

No secret value appears in the Nix store, in `/etc`, or in any file that persists
across reboots. All secrets live in Vault KV-v2 and are rendered to RAM-backed
paths at boot. If the system is powered off and the hard drive is imaged, there are
no credentials to extract.

### Vault KV-v2 Hierarchy

```
kv-v2/
  infrastructure/
    matrix/avina/
      config/        # Non-secret structural metadata: domain names, instance name
      synapse/       # Synapse-specific: macaroon key, form secret, TURN secret, MAS secret
      mas/           # MAS-specific: encryption key, signing keys, OIDC client credentials
    smtp/            # Shared SMTP credentials (used by both MAS and Synapse)
  letsencrypt/
    certificates/live/<apex-domain>/
                     # fullchain + privkey — written here by external certbot
```

KV-v2 stores each secret as a **versioned key-value pair**. vault-agent watches for
version increments: when certbot writes a new certificate (bumping the KV version),
vault-agent detects it and re-renders the dependent files without polling.

### Vault Agent

vault-agent runs as two systemd services:

**`vault-agent-init`** (Type=oneshot): Runs at boot before any dependent service
starts. Authenticates to Vault via AppRole, renders all templates, then exits.
Synapse, MAS, HAProxy, LiveKit, and lk-jwt-service all have
`after = ["vault-agent-init.service"]` to ensure secrets are present before they
start.

**`vault-agent`** (persistent daemon): Runs indefinitely. Maintains the AppRole
token (96-hour TTL, auto-renewed), and re-renders templates whenever an upstream
KV version increments. Signals the affected service (reload or restart) via
`systemctl` in the template `command` field.

### File Permissions

All rendered secrets land under `/run/secrets/` (mode `0750`, group
`matrix-secrets`). Individual files are `0640`. Each service that needs secrets
receives `matrix-secrets` as a supplementary group:

```nix
matrix-synapse = { serviceConfig.SupplementaryGroups = [ "matrix-secrets" ]; };
matrix-authentication-service = { ... };
haproxy = { ... };
livekit = { ... };
```

TLS certificates land under `/run/certs/` (mode `0755`). HAProxy's combined PEM
is `0640 root matrix-secrets`. LiveKit's TURN cert (`turn-fullchain.pem`) is `0644`
(public cert) and key (`turn.key`) is `0640`.

---

## 8. Threat Model and Security Decisions

### What is protected and how

| Asset | Protection |
|---|---|
| User credentials | Never exist in Matrix — fully delegated to Keycloak via MSC3861 |
| Matrix access tokens | Issued by MAS; short-lived; bound to device |
| JWT signing private keys | In Vault; rendered to RAM; never on disk after reboot |
| TLS private key | In Vault KV-v2; rendered to `/run/certs/`; never in Nix store |
| OIDC client secrets (Keycloak) | In Vault; never in Nix store or config files |
| MAS encryption secret | In Vault; encrypts MAS's database rows; must never rotate |
| Database | No direct external access; PostgreSQL unix socket only; password in Vault |

### Explicit attack surface

| Entry point | Accessible from | Protection |
|---|---|---|
| HTTPS :443 via Cloudflare Tunnel (matrix.*, element.*, mas.*) | Internet (all) | Cloudflare WAF + DDoS, TLS, HAProxy ACLs |
| HTTPS :443 direct NAT (matrix-rtc.*) | Internet (all) | TLS only; no Cloudflare WAF — limited to RTC domain; only serves Element Call UI and LiveKit WebSocket |
| SSH :22 | Internet (all) | Certificate-based auth; password disabled; SSH CA |
| TURN :3478, :5349 | Internet (NAT-forwarded) | Time-limited HMAC credentials; gated behind Matrix auth (see SSRF gap note below) |
| HAProxy stats :8404 | Internet (all) | TLS; RFC-1918 + loopback ACL for admin |

### What is explicitly not exposed

- LiveKit HTTP API :7880 — loopback only; accessed through HAProxy at `/livekit/sfu`
- PostgreSQL — unix socket only
- MAS internal listener :8182 — loopback only; Synapse-to-MAS channel
- Synapse :8008 — loopback only; behind HAProxy
- All darkhttpd static servers (:8082–:8085) — loopback only; behind HAProxy
- mautrix-whatsapp appservice :29318 — loopback only; Synapse pushes events here

### What is explicitly exposed for media

- LiveKit WebRTC UDP :50100–50200 — opened in firewall; ICE direct path to SFU
- LiveKit RTP/TCP :7881 — opened in firewall; direct TCP fallback for UDP-blocked clients
- LiveKit TURN/STUN :3478 (UDP+TCP), :5349 (TLS) — relay fallback for clients behind strict NAT

### Authentication chain integrity

```
User's browser
  → Cloudflare (WAF + DDoS)
  → HAProxy (TLS termination + routing)
  → MAS (OIDC authorization server)
  → Keycloak (upstream IdP — authoritative for user identity)
  → MAS issues Matrix access token
  → Synapse validates token via MSC3861
```

Breaking this chain requires compromising either Cloudflare (external), MAS
(OIDC token forgery requires signing key), or Keycloak (user account compromise).
Compromising Synapse alone does not yield credentials — the credential database is
in Keycloak, not Synapse.

### Key rotation policy

| Key/Secret | Rotation? | Consequence of rotation |
|---|---|---|
| MAS JWT signing keys | **Never** after prod | All sessions invalidated |
| MAS encryption secret | **Never** after prod | Database rows unreadable |
| TLS cert | Auto-rotated by certbot | Zero-downtime via vault-agent reload |
| Vault AppRole secret_id | Survives reboots; rotate when changing access policy | vault-agent re-authenticates on next startup |
| OIDC client secrets (Keycloak) | Rotate as needed | Update Vault; vault-agent propagates on next render |

---

*This document reflects the state of the avina stack as of 2026-04-01.*

*Update when adding components, changing protocols, or making security decisions.*
