{
  lib,
  ...
}:
{

  den.aspects.networking-aspect = lib.mkForce {
    nixos =
      { config, pkgs, ... }:
      {
        networking = {
          networkmanager = {
            enable = true;
            dns = "systemd-resolved";
          };

          firewall = {
            enable = true;
            trustedInterfaces = [ "tailscale0" ];
            allowedTCPPorts = [
              22
              24800
              8008
              8009
              8443
              22000
            ];
            allowedUDPPorts = [
              (config.services.tailscale.port or 41641) # Default fallback if tailscale not enabled
              1900
              5353
              22000
              21027
            ];
            allowedUDPPortRanges = [
              {
                from = 32768;
                to = 61000;
              }
            ];
          };
        };

        services.tailscale = {
          enable = true;
          useRoutingFeatures = "client";
        };

        services.resolved.enable = true;

        systemd.services.tailscale-autoconnect = {
          description = "Automatic Tailscale up with route acceptance";
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
            ExecStart = "${pkgs.tailscale}/bin/tailscale up --accept-routes --accept-dns";
            RemainAfterExit = true;
          };
        };
      };
  };
}
