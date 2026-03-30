# nix-nexus Memory Index

## Reference

- [element-call livekit branch](reference_element_call_livekit_branch.md) — Authoritative source for Element Call widget embed model, livekit_service_url discovery order, OIDC flow in widget vs standalone, required MSCs

## Project

- [avina security posture](project_avina_security_posture.md) — Security decisions and hardening choices for the avina Matrix 2.0 server (crypto, network exposure, secrets model)
- [Matrix 2.0 stack status](project_matrix_stack_status.md) — Current implementation state: what's working (Element Web, MAS, Synapse, email, ToS, versions.nix), what's in progress (Element Call OIDC)
- [WhatsApp bridge implementation lessons](project_whatsapp_bridge_lessons.md) — All gotchas hit adding mautrix-whatsapp: libolm permit, registration filename, PG schema ownership, MAS login endpoint routing, msc4190 for E2EE, double-puppet pending
- [avina Hybrid Ingress and DNS](project_avina_hybrid_ingress_dns.md) — Implementation details of the signaling vs media dual-path ingress model, split-horizon DNS configuration, and turnDomain refactor.
- [Element Call / LiveKit implementation lessons](project_element_call_livekit_lessons.md) — All 8 gotchas hit getting MatrixRTC working: msc4143 gating, static rtc/transports, CORS, well-known/matrix/server, LiveKit TURN crash, UDP port range, SFU path stripping
