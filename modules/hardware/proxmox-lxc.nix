_: {
  flake.modules.nixos.hardware-proxmox-lxc =
    { modulesPath, ... }:
    {
      imports = [
        # Upstream NixOS Proxmox LXC module.
        # It sets boot.isContainer = true and exposes the proxmoxLXC options.
        # It handles networking.useHostResolvConf, so services.resolved works in the container.
        (modulesPath + "/virtualisation/proxmox-lxc.nix")
      ];

      # Container Network Policy:
      # Proxmox manages the veth interface and IP assignment.
      proxmoxLXC.manageNetwork = false;

      networking = {
        # Disable NetworkManager (fleet default) for server hosts.
        # Use systemd-networkd for a lean, declarative server posture.
        networkmanager.enable = false;

        # Firewall Policy:
        # Proxmox is wide-open at the hypervisor level.
        # NixOS owns the firewall inside the container.
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

      services = {
        # DNS Caching:
        # proxmox-lxc.nix handles networking.useHostResolvConf correctly.
        # resolved does not conflict with the container's host resolv.conf setup.
        resolved = {
          enable = true;
          settings.Resolve = {
            Cache = "yes";
            CacheFromLocalhost = "yes";
          };
        };

        # Disable fstrim.
        # TRIM/discard is managed at the Proxmox storage layer, not inside the container.
        fstrim.enable = false;
      };
    };
}
