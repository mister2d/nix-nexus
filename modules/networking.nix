{ ... }:
{
  # ============================================================================
  # Networking Aspect: Connectivity & Mesh Mesh
  # ============================================================================

  den.aspects.networking-aspect = {
    nixos = { config, pkgs, lib, ... }: {
      networking = {
        useDHCP = false;
        dhcpcd.enable = false;
        networkmanager = {
          enable = lib.mkDefault true;
          dns = "systemd-resolved";
        };

        firewall = {
          enable = true;
          checkReversePath = lib.mkForce false;
          allowedTCPPorts = [ 22 80 8000 8080 443 24800 8008 8009 8443 22000 ];
          allowedUDPPorts = [
            config.services.tailscale.port
            1900 5353 22000 21027
          ];
          allowedUDPPortRanges = [ { from = 32768; to = 61000; } ];
          trustedInterfaces = [ "tailscale0" ];
        };
      };

      services.tailscale = {
        enable = true;
        useRoutingFeatures = "client";
      };

      services.resolved.enable = true;

      systemd.services.tailscale-autoconnect = {
        description = "Automatic Tailscale up with context-aware routing";
        after = [ "network-pre.target" "tailscaled.service" "resolved.service" ];
        wants = [ "network-pre.target" "tailscaled.service" "resolved.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = let
            routing = if config.networking.networkmanager.enable then "" else "--accept-routes";
          in "${pkgs.tailscale}/bin/tailscale up --reset --accept-dns ${routing}";
          RemainAfterExit = true;
        };
      };
    };
  };
}
