# Registry key: flake.modules.nixos.core-agent-identities
# Configures: fixed-uid agent identities in the reserved 9100-9199 id range.
# Imported by: hosts/sweet16/default.nix (sweet16-default), hosts/petunia/default.nix (petunia-default).
# pdh-pi (9100) is the host-side pi-durable harness service user.
# agent (9101) is the target login identity for Vault-signed SSH certificates.
# Neither identity is in the TPM, wheel, docker, or kvm groups. See docs/pi-durable-host.md.
_: {
  flake.modules.nixos.core-agent-identities =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      identities = [
        "pdh-pi"
        "agent"
      ];
      forbiddenGroups = [
        config.security.tpm2.tssGroup
        "wheel"
        "docker"
        "kvm"
      ];
      tpm2Users = lib.attrByPath [ "nix-nexus" "tpm2" "users" ] [ ] config;
    in
    {
      users.groups = {
        pdh-pi.gid = 9100;
        agent.gid = 9101;
      };

      users.users = {
        pdh-pi = {
          uid = 9100;
          isSystemUser = true;
          group = "pdh-pi";
          home = "/var/lib/pi-durable-pi";
          description = "pi-durable harness service user";
        };

        agent = {
          uid = 9101;
          isNormalUser = true;
          group = "agent";
          description = "agent SSH target identity";
          home = "/home/agent";
          homeMode = "0700";
          shell = pkgs.bashInteractive;
          # No hashedPassword: password login stays disabled. Access is by
          # Vault-signed SSH certificate only.
        };
      };

      assertions = lib.concatMap (name: [
        {
          assertion = !(builtins.elem name tpm2Users);
          message = "nix-nexus.tpm2.users must not contain ${name}: agent identities never get TPM access.";
        }
        {
          assertion = lib.all (g: !(builtins.elem g config.users.users.${name}.extraGroups)) forbiddenGroups;
          message = "users.users.${name}.extraGroups must not contain any of ${lib.concatStringsSep ", " forbiddenGroups}.";
        }
      ]) identities;
    };
}
