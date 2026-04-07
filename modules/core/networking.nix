{
  config,
  pkgs,
  lib,
  ...
}:

{
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

      # Disable Reverse Path Filtering (lib.mkForce required to override Tailscale default)
      # This prevents the kernel from dropping packets in multi-homed or VPN
      # environments where responses might exit via a different interface.
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
          from = 32768;
          to = 61000;
        } # Google Cast Streaming
      ];

      trustedInterfaces = [ "tailscale0" ];
    };
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
  # - Workstations (NetworkManager): Do NOT --accept-routes to avoid LAN hijacking.
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
          # Disable subnet route acceptance on workstations to prevent Table 52
          # from overriding local LAN routes (e.g., 10.0.1.0/24).
          routing = if config.networking.networkmanager.enable then "" else "--accept-routes";
        in
        "${pkgs.tailscale}/bin/tailscale up --reset --accept-dns ${routing}";
      RemainAfterExit = true;
    };
  };
}
