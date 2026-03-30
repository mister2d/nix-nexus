---
name: Matrix 2.0 stack implementation status
description: Current state of avina Matrix 2.0 deployment — what's complete, key decisions made
type: project
---

Stack is feature-complete and fully documented as of 2026-03-30 on the `matrix`
branch. All components are working. Documentation is aligned (commit 9340576).

## Fully implemented and verified

- **Element Web 1.12.10** — darkhttpd :8082, OIDC-only auth, `element_call.url` pointing to self-hosted call domain, `use_exclusively: true` (Jitsi disabled, all calls via MatrixRTC)
- **Element Call 0.11.1** — darkhttpd :8084, HAProxy redirects standalone visits (no widgetId) to elementDomain; widget iframes pass through unchanged (MSC2764 matryoshka pattern — no token passing, all Matrix API calls proxied via postMessage)
- **MAS 1.13.0** — custom systemd service, OIDC bridge via Keycloak SSO, signing keys (ECDSA P-384/ES384 primary + RSA-4096/RS256 compliance) from Vault, `allow_missing_client_uri: true` for Element Call dynamic OIDC registration
- **Synapse 1.149.1** — MSC3861 MAS delegation, MSC4108 QR code login (`experimental_features.msc4108_enabled`), MSC3575 Sliding Sync (native), password auth disabled, MSC4143 enabled with `matrix_rtc.transports` configured
- **Email (SMTP)** — both MAS and Synapse use `smtp_login` key from Vault KV, Mailgun :587 starttls
- **claims_imports** — `fetch_userinfo: true`, email `action: force` + `set_email_verification: import`, localpart `action: force`, displayname `action: suggest`
- **Well-known** — `matrix/client` (m.authentication stable+draft, rtc_foci, msc3575 proxy) + `matrix/server` (m.server:443) both served from symlinkJoin via darkhttpd :8083
- **Terms of Service** — `/tos` via darkhttpd :8085, `path_beg /tos` ACL
- **LiveKit SFU + lk-jwt-service** — working end-to-end; UDP 50100-50200 open, `use_external_ip=true`; ICE selects UDP direct on 50100-50200 range.
- **LiveKit TURN** — Internal TURN enabled on ports 3478 (UDP/TCP) and 5349 (TLS). **Coturn has been deprecated and removed.**
- **HAProxy** — TLS 1.2+ only, forward-secret ciphers, no session tickets, full routing table, Cloudflare header propagation, Prometheus metrics on :8404; MSC4143 rtc/transports served statically (no auth required); /livekit/jwt and /livekit/sfu both have prefix stripping
- **mautrix-whatsapp** — running, E2EE via msc4190, bridge via HAProxy internal frontend :8090; double-puppet working (`as_token` approach, verified `ping-matrix` response)
- **Vault / vault-agent** — KV-v2 three-tier hierarchy (config/synapse/mas), AppRole auth, init oneshot + persistent daemon, all secrets RAM-only at /run/secrets/ and /run/certs/
- **versions.nix** — authoritative version registry with NixOS assertions for all 11 stack components

## Key technical decisions made

- **Hybrid Ingress Model:** Signaling uses a dual-path model (Cloudflare Tunnel for external, Split-Horizon DNS for internal). Media uses direct WAN/LAN paths via DNAT.
- **Split-Horizon DNS:** Preferred over Hairpin NAT to preserve local IP logging and improve performance. Internal clients resolve domains directly to the LAN IP.
- **Coturn Removal:** Purged all coturn-related modules and secrets. LiveKit's internal TURN implementation is now the sole relay provider.
- **`turnDomain` Refactor:** Replaced `coturnRealm` with `turnDomain` to provide an authoritative DNS name for ICE candidates that bypasses the Cloudflare tunnel.
- Element Call standalone login is non-functional by design (v0.11.1 has no OIDC standalone login). Redirect to Element Web instead.
- MAS JWT signing keys must never be rotated after production; same for encryption secret.
- MAS `allow_missing_client_uri: true` — required because Element Call's oidc-client-ts doesn't send client_uri in dynamic registration requests.
- UDP :5349 comment is TURNS/TLS (not DTLS — DTLS is per-session WebRTC encryption, unrelated to port classification).
- `/.well-known/matrix/server` is required — lk-jwt-service uses it for federation server discovery to call `/_matrix/federation/v1/openid/userinfo`. Without it, falls back to :8448 (not open).
- MSC4143 `rtc/transports` endpoint served statically from HAProxy (not proxied to Synapse) because Synapse requires auth on it but clients call it unauthenticated.
- Both `/livekit/jwt` and `/livekit/sfu` prefixes must be stripped in their respective HAProxy backends.

## Documentation

- `PROTOCOL_REFERENCE.md` — canonical reference for the hybrid ingress model, DNS strategy, and LiveKit TURN implementation.
- `README.md` — updated with the hybrid ingress components and port tables.

## Pending

Nothing outstanding. Stack is fully operational in its hybrid state.

**Why:** Stack is optimized for security and media performance as of 2026-03-30.
**How to apply:** Reference `project_avina_hybrid_ingress_dns.md` for details on the network/DNS setup.
