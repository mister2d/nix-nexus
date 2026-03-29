{
  den,
  inputs,
  lib,
  ...
}:
{
  # ============================================================================
  # Unified Host and Aspect Registry
  # ============================================================================

  den = {
    hosts.x86_64-linux = {
      sweet16 = {
        users.ddukes = {
          classes = [
            "homeManager"
            "user"
          ];
          includes = [ den.aspects.user-ddukes-aspect ];
        };
      };
      petunia = {
        users.ddukes = {
          classes = [
            "homeManager"
            "user"
          ];
          includes = [ den.aspects.user-ddukes-aspect ];
        };
      };
      avina = {
        users.ddukes = {
          classes = [
            "homeManager"
            "user"
          ];
          includes = [ den.aspects.user-ddukes-aspect ];
        };
      };
    };

    aspects = {
      sweet16 = {
        includes = [
          den.provides.hostname
          den.aspects.base-aspect
          den.aspects.boot-aspect
          den.aspects.hw-z16-aspect
          den.aspects.zfs-aspect
          den.aspects.networking-aspect
          den.aspects.security-aspect
          den.aspects.sysctl-aspect
          den.aspects.programs-aspect
          den.aspects.sway-aspect
          den.aspects.niri-aspect
          den.aspects.ceph-aspect
          den.aspects.printing-aspect
        ];
        nixos =
          { pkgs, ... }:
          {
            _module.args.inputs = inputs;
            networking.hostId = "efca0213";
            nix-nexus.zfs = {
              arcMax = 8589934592;
              arcMin = 2147483648;
              arcSysFree = 4294967296;
              metaLimitPercent = 85;
              dnodeLimitPercent = 25;
            };
            imports = [ ./_hw/sweet16/hardware-configuration.nix ];
            users.users.ddukes = {
              isNormalUser = true;
              group = "users";
              description = "ddukes";
              extraGroups = [
                "networkmanager"
                "wheel"
                "video"
                "audio"
                "input"
                "docker"
                "fuse"
                "render"
              ];
              openssh.authorizedKeys.keys = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGQp6H/n2JPSt1VxCAupTC1OTh7R3eu7wO0ZtCNbAkd7"
              ];
            };
            services.greetd.settings.default_session.command =
              lib.mkForce "${pkgs.tuigreet}/bin/tuigreet --time --remember --asterisks --cmd sway";
          };
      };

      petunia = {
        includes = [
          den.provides.hostname
          den.aspects.base-aspect
          den.aspects.boot-aspect
          den.aspects.hw-petunia-aspect
          den.aspects.zfs-aspect
          den.aspects.networking-aspect
          den.aspects.security-aspect
          den.aspects.sysctl-aspect
          den.aspects.programs-aspect
          den.aspects.sway-aspect
          den.aspects.niri-aspect
          den.aspects.ceph-aspect
          den.aspects.printing-aspect
        ];
        nixos =
          { pkgs, ... }:
          {
            _module.args.inputs = inputs;
            networking.hostId = "4e1a0d9b";
            nix-nexus.zfs = {
              arcMax = 17179869184;
              arcMin = 4294967296;
              arcSysFree = 8589934592;
              metaLimitPercent = 80;
              dnodeLimitPercent = 20;
            };
            imports = [
              inputs.disko.nixosModules.disko
              ./_hw/petunia/hardware-configuration.nix
              ./_hw/petunia/disko.nix
            ];
            users.users.ddukes = {
              isNormalUser = true;
              group = "users";
              description = "ddukes";
              extraGroups = [
                "networkmanager"
                "wheel"
                "video"
                "audio"
                "input"
                "docker"
                "fuse"
                "render"
              ];
              openssh.authorizedKeys.keys = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGQp6H/n2JPSt1VxCAupTC1OTh7R3eu7wO0ZtCNbAkd7"
              ];
            };
            services.greetd.settings.default_session.command =
              lib.mkForce "${pkgs.tuigreet}/bin/tuigreet --time --remember --asterisks --cmd niri-session";
          };
      };

      avina = {
        includes = [
          den.provides.hostname
          den.aspects.base-aspect
          den.aspects.security-aspect
          den.aspects.sysctl-aspect
          den.aspects.matrix-aspect
        ];
        nixos =
          { pkgs, lib, ... }:
          {
            _module.args =
              let
                site = import ./_hw/avina/site-config.nix;
              in
              {
                inherit inputs;
                inherit (site)
                  matrixDomain
                  elementDomain
                  masDomain
                  callDomain
                  coturnRealm
                  vaultAddr
                  certDomain
                  ;
                federatedDomains = [ ];
              };
            imports = [ (inputs.nixpkgs + "/nixos/modules/virtualisation/proxmox-lxc.nix") ];
            proxmoxLXC = {
              privileged = false;
              manageNetwork = false;
            };
            boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 443;
            networking.firewall = {
              enable = true;
              trustedInterfaces = [ ];
              allowedTCPPorts = [
                22
                443
                5349
                8404
              ];
              allowedUDPPorts = [
                3478
                5349
              ];
              allowedUDPPortRanges = [
                {
                  from = 49000;
                  to = 49999;
                }
                {
                  from = 50100;
                  to = 50200;
                }
              ];
              allowedTCPPortRanges = [
                {
                  from = 3478;
                  to = 3478;
                }
              ];
            };
            services = {
              resolved = {
                enable = true;
                extraConfig = "Cache=true\nCacheFromLocalhost=true";
              };
              fstrim.enable = false;
              openssh.settings = {
                PasswordAuthentication = lib.mkForce false;
                KbdInteractiveAuthentication = lib.mkForce false;
                PermitRootLogin = lib.mkForce "prohibit-password";
                TrustedUserCAKeys = toString ../certs/trusted_ssh_ca.pub;
              };
            };
            users.users = {
              groot = {
                isNormalUser = true;
                extraGroups = [ "wheel" ];
                shell = pkgs.bash;
                openssh.authorizedKeys.keys = [
                  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGQp6H/n2JPSt1VxCAupTC1OTh7R3eu7wO0ZtCNbAkd7"
                ];
              };
              ddukes = {
                isNormalUser = true;
                group = "users";
                description = "ddukes";
                extraGroups = [
                  "networkmanager"
                  "wheel"
                  "video"
                  "audio"
                  "input"
                  "docker"
                  "fuse"
                  "render"
                ];
                openssh.authorizedKeys.keys = [
                  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGQp6H/n2JPSt1VxCAupTC1OTh7R3eu7wO0ZtCNbAkd7"
                ];
              };
            };
          };
      };
    };
  };
}
