# Registry key: flake.modules.homeManager.user-vault-home
# Configures: Vault CLI helpers (vault-login, vault-token-helper, generate-ssh-cert) and the ~/.vault token_helper wiring.
# Imported by: modules/user/home.nix (user-home).
_: {
  flake.modules.homeManager.user-vault-home =
    { lib, pkgs, ... }:
    let
      # writeShellApplication supplies the shebang and strict-mode header.
      body =
        file:
        lib.concatStringsSep "\n" (
          builtins.filter (l: l != "#!/usr/bin/env bash" && l != "set -euo pipefail") (
            lib.splitString "\n" (builtins.readFile file)
          )
        );

      vault-login = pkgs.writeShellApplication {
        name = "vault-login";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.curl
          pkgs.jq
          pkgs.pass
        ];
        text = body ../../lib/vault/vault-login.sh;
      };

      vault-token-helper = pkgs.writeShellApplication {
        name = "vault-token-helper";
        runtimeInputs = [ pkgs.coreutils ];
        text = body ../../lib/vault/vault-token-helper.sh;
      };

      generate-ssh-cert = pkgs.writeShellApplication {
        name = "generate-ssh-cert";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.curl
          pkgs.jq
          pkgs.openssh
        ];
        text = body ../../lib/vault/generate-ssh-cert.sh;
      };
    in
    {
      home.packages = [
        vault-login
        vault-token-helper
        generate-ssh-cert
      ];

      home.file.".vault".text = ''
        token_helper = "${vault-token-helper}/bin/vault-token-helper"
      '';
    };
}
