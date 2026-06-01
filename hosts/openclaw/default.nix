{
  lib,
  pkgs,
  modulesPath,
  nixosModules,
  ...
}:
let
  openclawPkgPath = "/nix/store/qi4gvxv4rdwfrh7lb339kkq7wncb1ih7-openclaw-2026.4.2";
  matrixCryptoBinary = pkgs.fetchurl {
    url = "https://github.com/matrix-org/matrix-rust-sdk-crypto-nodejs/releases/download/v0.4.0/matrix-sdk-crypto.linux-x64-gnu.node";
    sha256 = "06779l1ry2hxdxssiwj3gviyrbb43xi4yb0rzndgfa3ik3fx8y3h";
  };
in
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    nixosModules.server-default
    nixosModules.openclaw-vault-secrets
  ];

  proxmoxLXC = {
    privileged = false;
    manageNetwork = false;
  };

  # Allow HAProxy (running as groot) to bind to port 443
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 443;

  # Let Proxmox manage IP assignment, NixOS systemd-networkd handles DHCP locally.
  networking = {
    hostName = "openclaw";
    networkmanager.enable = false;
    firewall.enable = false;
  };

  # Host-level User configurations
  users.users.groot = {
    isNormalUser = true;
    extraGroups = [
      "openclaw-secrets"
      "kvm"
    ]; # matrix-secrets provides access to /run/secrets and /run/certs
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGQp6H/n2JPSt1VxCAupTC1OTh7R3eu7wO0ZtCNbAkd7"
    ];
  };

  # Security Hardening: Disable sudo entirely.
  # Administrative tasks must be performed via direct root login.
  security.sudo.enable = false;

  systemd = {
    network = {
      enable = true;
      networks."10-eth0" = {
        matchConfig.Name = "eth0";
        networkConfig.DHCP = "yes";
      };
    };

    # FIX: Provide the missing Matrix crypto native binary.
    # We create a writable tmpfs directory, populate it with both the original
    # loader files and the missing platform-specific binary, and then bind-mount
    # it over the read-only Nix store path so Node.js find everything in one place.
    tmpfiles.rules = [
      "d /run/openclaw-crypto 0755 root root -"
      "d /run/openclaw-crypto/matrix-sdk-crypto-nodejs 0755 root root -"
      "d /run/openclaw-crypto/matrix-sdk-crypto-nodejs-linux-x64-gnu 0755 root root -"
      "d /run/openclaw-crypto/matrix-sdk-crypto-wasm 0755 root root -"
      # Link the fetched binary into the gnu-specific path
      "L+ /run/openclaw-crypto/matrix-sdk-crypto-nodejs-linux-x64-gnu/index.node - - - - ${matrixCryptoBinary}"
      # Link it also into the main path as a fallback
      "L+ /run/openclaw-crypto/matrix-sdk-crypto-nodejs/index.node - - - - ${matrixCryptoBinary}"
    ];

    services.openclaw-crypto-setup = {
      description = "Prepare writable crypto module for bind-mount";
      before = [
        "nix-store-qi4gvxv4rdwfrh7lb339kkq7wncb1ih7\\x2dopenclaw\\x2d2026.4.2\\x2dlib\\x2dopenclaw\\x2dnode_modules\\x2d@matrix\\x2dorg.mount"
      ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "setup-openclaw-crypto" ''
          # Copy original loader and wasm files from Nix store into our writable /run path
          # We do this individually to avoid overwriting our fetched index.node
          for dir in matrix-sdk-crypto-nodejs matrix-sdk-crypto-wasm; do
            if [ -d ${openclawPkgPath}/lib/openclaw/node_modules/@matrix-org/$dir ]; then
              cp -rn ${openclawPkgPath}/lib/openclaw/node_modules/@matrix-org/$dir/* /run/openclaw-crypto/$dir/
            fi
          done
          # Create a basic package.json for the gnu folder if it doesn't exist
          if [ ! -f /run/openclaw-crypto/matrix-sdk-crypto-nodejs-linux-x64-gnu/package.json ]; then
            echo '{"name": "@matrix-org/matrix-sdk-crypto-nodejs-linux-x64-gnu", "main": "index.node"}' > /run/openclaw-crypto/matrix-sdk-crypto-nodejs-linux-x64-gnu/package.json
          fi
          chmod -R 755 /run/openclaw-crypto
        '';
      };
    };

    # FIX: Workaround for OpenClaw's requirement to write into its own node_modules
    # for the Matrix crypto binary download. We bind-mount a writable directory
    # from /run over the read-only Nix store path.
    mounts = [
      {
        description = "Writable bind-mount for OpenClaw Matrix Crypto";
        what = "/run/openclaw-crypto";
        where = "${openclawPkgPath}/lib/openclaw/node_modules/@matrix-org";
        type = "none";
        options = "bind,rw";
        wantedBy = [ "multi-user.target" ];
        before = [ "vault-agent-init.service" ];
      }
    ];
  };

  services = {
    haproxy = {
      enable = true;
      user = "groot";
      group = "openclaw-secrets";
      config =
        let
          adminIPs = [
            "127.0.0.1"
            "10.0.0.0/8"
            "172.16.0.0/12"
            "192.168.0.0/16"
          ];
        in
        ''
          global
            maxconn 4096
            stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
            log stdout format raw local0

            # High-Security SSL configuration
            ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
            ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
            ssl-default-bind-options no-sslv3 no-tlsv10 no-tlsv11 no-tls-tickets

          defaults
            mode    http
            log     global
            timeout connect 5s
            timeout client  600s
            timeout server  600s
            timeout tunnel  3600s
            option  forwardfor
            option  http-server-close

          frontend https_ingress
            bind *:443 ssl crt /run/certs/haproxy.pem
            http-request set-header X-Forwarded-Proto https

            acl is_openclaw hdr(host) -i openclaw.novuscotia.com
            use_backend openclaw_backend if is_openclaw

          frontend stats
            bind *:8404 ssl crt /run/certs/haproxy.pem
            stats   enable
            stats   show-legends
            stats   show-modules
            stats   uri /stats
            stats   admin if { src ${lib.concatStringsSep " " adminIPs} }
            http-request use-service prometheus-exporter if { path /metrics }

          backend openclaw_backend
            option httpchk GET /health
            http-check expect status 200
            server openclaw_loopback 127.0.0.1:18789 check
        '';
    };

    resolved = {
      enable = true;
      extraConfig = ''
        Cache=true
        CacheFromLocalhost=true
      '';
    };

    fstrim.enable = false;

    tailscale = {
      enable = true;
      authKeyFile = "/run/secrets/tailscale.key";
    };
  };

  # Delegate novuscotia.com DNS to Cloudflare's public resolvers.
  # The LXC host's split-horizon DNS returns private IPs for novuscotia.com,
  # which triggers OpenClaw's SSRF guard. By delegating this domain to
  # Cloudflare, matrix.novuscotia.com resolves to the public Cloudflare IP
  # (via Cloudflare Tunnel), bypassing the guard entirely.
  environment.etc."systemd/dns-delegate.d/novuscotia.dns-delegate".text = ''
    [Delegate]
    DNS=1.1.1.1 1.0.0.1
    Domains=novuscotia.com
  '';

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

  nixpkgs.config.permittedInsecurePackages = [
    "openclaw-2026.4.2"
  ];

  system.stateVersion = "25.11";
}
