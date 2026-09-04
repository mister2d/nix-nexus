_: {
  flake.modules.nixos.avina-default =
    {
      nixosModules,
      ...
    }:
    let
      # ── Deployment values (gitignored — see site-config.nix.example) ─────────
      # Copy hosts/avina/site-config.nix.example → hosts/avina/site-config.nix
      # and fill in real values before building. Never commit site-config.nix.
      site = import ../../lib/avina/site-config.nix;
      inherit (site)
        matrixDomain
        elementDomain
        masDomain
        rtcDomain
        vaultAddr
        certDomain
        ;

      # Federated Posture:
      # Least-privilege model. Add domains of external homeservers you wish to
      # federate with. Set to "*" to allow all domains.
      federatedDomains = "*";
      # ─────────────────────────────────────────────────────────────────────────
    in
    {
      imports = [
        nixosModules.hardware-proxmox-lxc # Proxmox LXC base: container module, network, resolved
        nixosModules.server-default # Base: security, sysctl, users — no ZFS, no boot, no NM
        nixosModules.services-matrix # Matrix 2.0 communications suite
        nixosModules.core-groot
      ];

      # Encrypted secrets for this host. Decrypted at activation with an age key
      # derived from /etc/ssh/ssh_host_ed25519_key.
      nix-nexus.secrets.sops.hostFile = ../../secrets/avina.yaml;

      sops.secrets = {
        # vault-agent's AppRole seed. Previously hand-placed in /var/lib/secrets
        # and the one credential in the fleet that unlocked all the others while
        # being unmanaged itself. Both vault-agent units run as root.
        vault-role-id = {
          owner = "root";
          group = "root";
          mode = "0400";
        };
        vault-secret-id = {
          owner = "root";
          group = "root";
          mode = "0400";
        };
      };

      # Container Policy:
      # Unprivileged (privileged = false): root inside the container maps to an
      # unprivileged uid on the Proxmox host. Safer for a public-facing server —
      # a container escape cannot yield host root.
      proxmoxLXC.privileged = false;

      _module.args = {
        inherit
          matrixDomain
          elementDomain
          masDomain
          rtcDomain
          federatedDomains
          vaultAddr
          certDomain
          ;
      };

      # Allow HAProxy to bind to port 443 as the haproxy user (non-root).
      # net.ipv4.ip_unprivileged_port_start is namespace-scoped and settable in
      # unprivileged LXC containers; lowering it to 443 permits binding to 443/8404.
      boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 443;

      # Administrative user for server access.
      # avina is the only host that grants groot wheel access.
      users.users.groot = {
        extraGroups = [ "wheel" ];
      };
    };
}
