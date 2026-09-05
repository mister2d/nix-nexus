# Merged into: flake.modules.nixos.services-matrix
# Configures: version assertions for every Matrix stack package.
# Imported by: hosts/avina/default.nix (avina-default).
_: {
  flake.modules.nixos.services-matrix =
    { pkgs, ... }:
    let
      # ── Matrix 2.0 Stack — Authoritative Version Registry ────────────────────
      # The pkgs-stable overlay in flake.nix sources every package marked
      # (stable), pinned to nixos-25.11 @ b6018f87. The primary nixpkgs input
      # sources all other packages, pinned to nixos-26.05 @ 8eeec934.
      #
      # To upgrade a component:
      #   1. Update the version constant below.
      #   2. Update the pkgs-stable or nixpkgs pin in flake.nix when the new
      #      version requires a newer channel.
      #   3. Run nixos-rebuild.
      #   4. Confirm the assertion matches the resolved version.
      #   5. Update hosts/avina/README.md stack table.
      expected = {
        # Matrix homeserver (stable)
        synapse = "1.155.0";
        # OIDC bridge — MSC3861 native OIDC delegation (stable)
        mas = "1.17.0";
        # WebRTC SFU (stable)
        livekit = "1.9.4";
        # LiveKit JWT authentication service (stable)
        lkJwt = "0.4.0";
        # Matrix web client (stable)
        elementWeb = "1.12.18";
        # WebRTC calling — MSC4143 (stable)
        elementCall = "0.11.1";
        # Database backend for Synapse and MAS (stable)
        postgresql = "16.14";
        # TLS termination and reverse proxy
        haproxy = "3.3.11";
        # Secrets agent — pulls credentials from Vault KV-v2 at runtime
        vault = "1.21.4";
        # Static file server — well-known discovery and ToS
        darkhttpd = "1.17";
      };

      check = name: pkg: declared: {
        assertion = pkg.version == declared;
        message = "Matrix stack version drift: ${name} is ${pkg.version} but versions.nix declares ${declared}. Update modules/services/matrix/versions.nix after intentional upgrades.";
      };
    in
    {
      assertions = [
        (check "matrix-synapse" pkgs.matrix-synapse-unwrapped expected.synapse)
        (check "matrix-authentication-service" pkgs.matrix-authentication-service expected.mas)
        (check "livekit" pkgs.livekit expected.livekit)
        (check "lk-jwt-service" pkgs.lk-jwt-service expected.lkJwt)
        (check "element-web" pkgs.element-web expected.elementWeb)
        (check "element-call" pkgs.element-call expected.elementCall)
        (check "postgresql_16" pkgs.postgresql_16 expected.postgresql)
        (check "haproxy" pkgs.haproxy expected.haproxy)
        (check "vault" pkgs.vault expected.vault)
        (check "darkhttpd" pkgs.darkhttpd expected.darkhttpd)
      ];
    };
}
