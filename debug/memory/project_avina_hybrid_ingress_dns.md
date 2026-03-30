---
name: avina Hybrid Ingress and DNS Architecture
description: Documentation of the validated hybrid signaling/media model and the turnDomain refactor
type: project
---

# avina Hybrid Ingress and DNS Architecture

As of 2026-03-30, the avina Matrix stack has been transitioned to a high-performance hybrid ingress model that optimizes for both security and media quality.

## 1. The Hybrid Ingress Model

To balance public invisibility with local performance, signaling and media follow separate paths:

### Signaling (HTTPS/WSS)
- **External:** Routed via `cloudflared` tunnel. No inbound ports (80/443) are open on the WAN. TLS is terminated at HAProxy.
- **Internal:** Routed via **Split-Horizon DNS**. Internal clients resolve domains directly to `avina:443` (10.0.1.7), bypassing the tunnel and the WAN for lower latency and preserved local IP logging.

### Media (WebRTC)
- **Both Paths:** Media always uses direct WAN/LAN connections to bypass the Cloudflare tunnel (which does not support the required UDP high-port ranges).
- **External:** Handled via Destination NAT (DNAT) on the MikroTik for ports 3478, 5349, 7881, and 50100-50200.
- **Internal:** Handled via local routing. Split-Horizon DNS ensures the `turnDomain` resolves to the local IP, keeping media traffic on the LAN switch.

## 2. Domain Refactoring (`turnDomain`)

The legacy `coturnRealm` variable has been deprecated and replaced with `turnDomain` to reflect the transition to LiveKit's internal TURN implementation.

- **`matrixDomain`**: Signaling, federation, and well-known discovery.
- **`turnDomain`**: Authoritative A-record for STUN/TURN and ICE candidates. Must point to the WAN IP externally and the LAN IP internally.
- **`callDomain`**: Element Call static asset hosting.
- **`masDomain`**: OIDC authentication (MAS).

## 3. Network Configuration (MikroTik)

The "Gold Standard" network configuration (documented professionally as the Hybrid Ingress Implementation) involves:
1. **Static DNS:** `matrix`, `mas`, `element`, `call`, and `turn` subdomains all resolve to `10.0.1.7` locally.
2. **NAT Rules:**
   - TCP/UDP 3478 & 5349 (STUN/TURN)
   - TCP 7881 (LiveKit TCP Mux fallback)
   - UDP 50100-50200 (WebRTC Media Range)
3. **Firewall Rules:** Corresponding `forward` chain rules to allow the NAT traffic.

## 4. Troubleshooting: External IP Validation

LiveKit may log a `WARN: could not validate external IP (context canceled)`. This is identified as a harmless side-effect of the server's self-probe hitting the WAN IP from the LAN. In this split-horizon model, the warning is ignored as long as external clients connect successfully. Hairpin NAT is intentionally avoided in favor of Split-Horizon DNS for better performance and log integrity.
