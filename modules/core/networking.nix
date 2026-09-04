_: {
  flake.modules.nixos.core-networking =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.nix-nexus.networking.tailscale;
      castStreamPortRangeStart = 32768; # ephemeral UDP port range start
      castStreamPortRangeEnd = 61000; # ephemeral UDP port range end
    in
    {
      options.nix-nexus.networking.tailscale = {
        homeSSIDs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            List of SSIDs considered "home" networks. When non-empty, a
            NetworkManager dispatcher script will disable --accept-routes on these
            networks (to avoid Tailscale subnet routes hijacking local LAN paths)
            and enable it on all others (so remote LAN resources are reachable
            while travelling).
          '';
        };
      };

      config = {
        # Unified Network Management
        # This module implements a "Modern Networking" pattern that handles both
        # workstations (NetworkManager) and servers (networkd) while avoiding
        # duplicate DHCP client conflicts and asymmetric routing issues.
        networking = {
          # Disable the legacy DHCP client globally. Modern NixOS modules (NetworkManager
          # and systemd-networkd) manage their own DHCP internally. This eliminates
          # duplicate routes (e.g., metric 600 vs 3002) and routing table "wars".
          useDHCP = false;
          dhcpcd.enable = false;

          # Workstation Posture (Default)
          # NetworkManager is the fleet default for Wi-Fi roaming and ease of use.
          networkmanager = {
            enable = lib.mkDefault true;
            dns = "systemd-resolved";

            # SSIDs are defined declaratively; passwords are managed in the system keyring.
            ensureProfiles.profiles = {
              # "MyWiFi" = {
              #   connection = { id = "MyWiFi"; type = "wifi"; permissions = "user:ddukes"; };
              #   wifi = { mode = "infrastructure"; ssid = "MyWiFi"; };
              #   wifi-security = { auth-alg = "open"; key-mgmt = "wpa-psk"; psk-flags = 1; };
              # };
            };
          };

          # Firewall & Security
          firewall = {
            enable = true;

            # Tailscale sets checkReversePath to "loose" at normal priority for
            # useRoutingFeatures = "client". mkForce sets false instead and
            # avoids a definition conflict between the two values. Strict
            # filtering drops return packets on multi-homed or VPN hosts.
            checkReversePath = lib.mkForce false;

            # Standard application ports
            allowedTCPPorts = [
              22 # SSH
              80 # http
              8000 # http
              8080 # http
              443 # https
              24800 # Input-Leap
              8008 # Google Cast
              8009 # Google Cast
              8443 # Google Cast
              22000 # Syncthing (P2P Data)
            ];

            allowedUDPPorts = [
              config.services.tailscale.port
              1900 # SSDP (Discovery)
              5353 # mDNS (Discovery)
              22000 # Syncthing (QUIC/P2P Data)
              21027 # Syncthing (Local Discovery)
            ];

            allowedUDPPortRanges = [
              {
                from = castStreamPortRangeStart;
                to = castStreamPortRangeEnd;
              } # Google Cast Streaming
            ];

            trustedInterfaces = [ "tailscale0" ];
          };

          # NM dispatcher: flip accept-routes based on SSID when homeSSIDs is configured.
          # On a known home SSID the LAN is directly reachable, so subnet routes must be
          # suppressed to prevent Table 52 from overriding local paths.  On any other
          # network (hotel, hotspot, office) we want them so remote LAN resources route
          # through Tailscale.
          networkmanager.dispatcherScripts = lib.mkIf (cfg.homeSSIDs != [ ]) [
            {
              source = pkgs.writeShellScript "tailscale-accept-routes" ''
                INTERFACE="$1"
                ACTION="$2"

                # Only act on wifi/ethernet up/down events
                case "$ACTION" in
                  up|connectivity-change) ;;
                  *) exit 0 ;;
                esac

                # Resolve current SSID (empty on wired or when not associated)
                SSID=$(${pkgs.networkmanager}/bin/nmcli -t -f active,ssid dev wifi 2>/dev/null \
                       | ${pkgs.gnugrep}/bin/grep '^yes' | cut -d: -f2)

                # Check if SSID matches any configured home network
                IS_HOME=0
                ${lib.concatMapStringsSep "\n" (ssid: ''
                  [ "$SSID" = ${lib.escapeShellArg ssid} ] && IS_HOME=1
                '') cfg.homeSSIDs}

                if [ "$IS_HOME" = "1" ]; then
                  ${pkgs.tailscale}/bin/tailscale set --accept-routes=false
                else
                  ${pkgs.tailscale}/bin/tailscale set --accept-routes=true
                fi
              '';
              type = "basic";
            }
          ];
        };

        # Mesh VPN (Tailscale)
        services.tailscale = {
          enable = true;
          useRoutingFeatures = "client";
        };

        # Name Resolution
        services.resolved.enable = true;

        # Tailscale Autoconnect & Routing Strategy
        # We dynamically adjust the Tailscale posture based on the machine type:
        # - Workstations without homeSSIDs (NetworkManager): Do NOT --accept-routes to avoid LAN hijacking.
        # - Workstations with homeSSIDs configured: accept-routes managed dynamically by NM dispatcher.
        # - Servers (networkd): DO --accept-routes to facilitate fleet-wide access.
        systemd.services.tailscale-autoconnect = {
          description = "Automatic Tailscale up with context-aware routing";
          after = [
            "network-pre.target"
            "tailscaled.service"
            "resolved.service"
          ];
          wants = [
            "network-pre.target"
            "tailscaled.service"
            "resolved.service"
          ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart =
              let
                # Roaming workstations (homeSSIDs set): start with accept-routes enabled;
                # the NM dispatcher will disable it when on a known home network.
                # Static workstations (no homeSSIDs): disable to prevent Table 52 LAN hijack.
                # Servers (non-NM): always accept routes.
                routing =
                  if cfg.homeSSIDs != [ ] then
                    "--accept-routes"
                  else if config.networking.networkmanager.enable then
                    ""
                  else
                    "--accept-routes";

                # Official resolution for secret-backed auth keys:
                # Use the 'file:' prefix to avoid leaking the key in the process list.
                authKey = lib.optionalString (
                  config.services.tailscale.authKeyFile != null
                ) "--auth-key file:${config.services.tailscale.authKeyFile}";
              in
              "${pkgs.tailscale}/bin/tailscale up --reset --accept-dns ${routing} ${authKey}";
            RemainAfterExit = true;
          };
        };
      };
    };
}
