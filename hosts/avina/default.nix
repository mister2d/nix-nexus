_: {
  flake.modules.nixos.avina-default =
    {
      pkgs,
      modulesPath,
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
        # Official NixOS Proxmox LXC module — sets boot.isContainer = true,
        # exposes proxmoxLXC options, and correctly handles networking.useHostResolvConf
        # (which is why services.resolved works here but fails when isContainer is set manually).
        (modulesPath + "/virtualisation/proxmox-lxc.nix")

        nixosModules.server-default # Base: security, sysctl, users — no ZFS, no boot, no NM
        nixosModules.services-matrix # Matrix 2.0 communications suite
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
      # manageNetwork = false: Proxmox manages the veth interface and IP assignment.
      # NixOS still owns the firewall inside the container's network namespace.
      proxmoxLXC = {
        privileged = false;
        manageNetwork = false;
      };

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

      networking = {
        # Disable NetworkManager (fleet default) for server hosts.
        # Use systemd-networkd for a lean, declarative server posture.
        networkmanager.enable = false;

        # Firewall Policy:
        # Proxmox is configured wide-open at the hypervisor level; NixOS owns the
        # firewall inside the container. Only the ports required by the Matrix stack
        # and operator access are opened.
        firewall.enable = false;
      };

      # Network Interface Configuration (LXC)
      systemd.network = {
        enable = true;
        networks."10-eth0" = {
          matchConfig.Name = "eth0";
          networkConfig.DHCP = "yes";
        };
      };

      # Administrative user for server access.
      # groot is the fleet-wide operator identity used across all hosts.
      users.users.groot = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "kvm"
        ];
        shell = pkgs.bash;
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGQp6H/n2JPSt1VxCAupTC1OTh7R3eu7wO0ZtCNbAkd7"

          # TPM-sealed personal keys, one per originating host.
          "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNXL5V23wci0ARBKtji+yLad2Mg0pxIflmq2clUoNVQabpYQbwhIgDHcui1CBqZnA0FdDuVtnsrWzI0XMi3GvQI= ddukes@sweet16 personal (TPM)"
          "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBBwldrZh2sFdX5Z3IyizIlgYBGKLz31t90zokoU/XLcsHGLfZW8RbDwz4c1hGGdjCDlV5eaTMipeqF8a59qiN30= ddukes@petunia personal (TPM)"
        ];
      };

      services = {
        # DNS Caching:
        # proxmox-lxc.nix handles networking.useHostResolvConf correctly so
        # resolved does not conflict with the container's host resolv.conf setup.
        resolved = {
          enable = true;
          settings.Resolve = {
            Cache = "yes";
            CacheFromLocalhost = "yes";
          };
        };

        # Disable fstrim — TRIM/discard is managed at the Proxmox storage layer,
        # not from inside the container.
        fstrim.enable = false;

      };

      # Session Multiplexer:
      # Persistent sessions for long-running deploys and maintenance.
      programs.tmux = {
        enable = true;
        shortcut = "a";
        baseIndex = 1;
        escapeTime = 0;
        keyMode = "vi";
        terminal = "tmux-256color";
        extraConfig = ''
          set -g status-style bg=black,fg=cyan
          set -g status-left "#[fg=cyan,bold] #S #[default]| "
          bind | split-window -h -c "#{pane_current_path}"
          bind - split-window -v -c "#{pane_current_path}"
        '';
      };

      system.stateVersion = "25.11";
    };
}
