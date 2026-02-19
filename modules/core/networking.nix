{ config, ... }:

{
  # Network Management
  networking = {
    networkmanager = {
      enable = true;

      # WiFi Persistence Posture
      # SSIDs are defined here to be declaratively managed and restricted to the user.
      # Passwords are NOT stored in the Nix configuration for Git safety.
      # NetworkManager will prompt for the password on first connection and store it
      # securely in the system-wide keyfile or user keyring.
      ensureProfiles.profiles = {
        # Example Secure SSID (Replace 'MyWiFi' with your actual SSID)
        # "MyWiFi" = {
        #   connection = {
        #     id = "MyWiFi";
        #     type = "wifi";
        #     # Restrict this connection to the ddukes user
        #     permissions = "user:ddukes";
        #   };
        #   wifi = {
        #     mode = "infrastructure";
        #     ssid = "MyWiFi";
        #   };
        #   wifi-security = {
        #     auth-alg = "open";
        #     key-mgmt = "wpa-psk";
        #     # Setting psk-flags to 1 tells NM to ask for the password (not in Nix store)
        #     psk-flags = 1;
        #   };
        #   ipv4.method = "auto";
        #   ipv6.method = "auto";
        # };
      };
    };

    # Firewall Configuration
    firewall = {
      enable = true;
      trustedInterfaces = [ "tailscale0" ];

      # Standard application ports
      allowedTCPPorts = [
        22 # SSH
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

      # Range for Google Cast Streaming
      allowedUDPPortRanges = [
        {
          from = 32768;
          to = 61000;
        }
      ];
    };
  };

  # Tailscale (Mesh VPN)
  services.tailscale.enable = true;
}
