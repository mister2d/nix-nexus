# Registry key: flake.modules.homeManager.user-ssh-tpm-agent
# Configures: two isolated ssh-tpm-agent instances for TPM-sealed SSH keys.
# Imported by: hosts/sweet16/home.nix (sweet16-home), hosts/petunia/home.nix (petunia-home).
# TPM group access needs nix-nexus.tpm2.users. A fresh login applies new membership.
#
#   ssh-tpm-agent     ~/.ssh/tpm      interactive ssh, Vault-cert deploys
#   permafrost-agent  ~/.ssh/agents   forwarded to permafrost-* guests only
#
# Each instance loads only .tpm files from its own --key-dir.
# A socket forwarded into a sandbox cannot reach the personal key.
_: {
  flake.modules.homeManager.user-ssh-tpm-agent =
    {
      pkgs,
      config,
      lib,
      ...
    }:

    let
      bin = lib.getExe' pkgs.ssh-tpm-agent "ssh-tpm-agent";

      instances = {
        ssh-tpm-agent = {
          keyDir = "${config.home.homeDirectory}/.ssh/tpm";
          description = "TPM-sealed SSH agent (personal)";
        };
        permafrost-agent = {
          keyDir = "${config.home.homeDirectory}/.ssh/agents";
          description = "TPM-sealed SSH agent (permafrost guests)";
        };
      };
    in

    {
      home = {
        packages = [ pkgs.ssh-tpm-agent ];

        # ssh-tpm-agent serves SSH. gpg-agent serves GPG only.
        # Both variables are necessary. Login shells source
        # home.sessionVariables. Graphical terminals inherit from the
        # systemd user manager. That manager reads only environment.d.
        sessionVariables.SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/ssh-tpm-agent.sock";

        # Both targets are generated at runtime on each host and cannot live in
        # the store, hence mkOutOfStoreSymlink. Each host resolves to its own
        # key, since a TPM key cannot be shared.
        file = {
          # ~/.ssh/id_ecdsa is in ssh's default identity list, so naming the
          # public half canonically means the key is found with no client
          # config at all — including under IdentitiesOnly, which lists exactly
          # those default paths and would otherwise offer nothing. It pairs
          # with the already-canonical ~/.ssh/id_ecdsa-cert.pub.
          #
          # Only the public half moves. The sealed key stays in its own
          # directory: --key-dir recurses, so a key-dir of ~/.ssh would pull in
          # ~/.ssh/agents too and collapse the two agents into one.
          ".ssh/id_ecdsa.pub".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.ssh/tpm/id_ecdsa_personal.pub";

          # ssh-tpm-agent reads certificates only from its own --key-dir, while
          # renewals are written to the canonical path.
          ".ssh/tpm/id_ecdsa_personal-cert.pub".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.ssh/id_ecdsa-cert.pub";
        };
      };

      # The keys carry no PIN.
      # The agent runs as a daemon with no tty, so a PIN needs an askpass.
      # No askpass binary exists on these hosts.
      # The kernel keyctl helpers are absent, so the agent caches no PIN.
      # Without caching, a PIN would prompt on every signature, not once per login.
      # The TPM protects the key instead: the private half never leaves the chip.
      systemd.user = {
        sessionVariables.SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/ssh-tpm-agent.sock";

        sockets = lib.mapAttrs (name: inst: {
          Unit.Description = "${inst.description} socket";
          Socket = {
            ListenStream = "%t/${name}.sock";
            SocketMode = "0600";
            Service = "${name}.service";
          };
          Install.WantedBy = [ "sockets.target" ];
        }) instances;

        services = lib.mapAttrs (name: inst: {
          Unit = {
            Description = inst.description;
            Requires = [ "${name}.socket" ];
          };
          Service = {
            Type = "simple";
            # The agent exits non-zero if its key directory is absent, which on
            # a fresh host is the state before any key has been generated.
            ExecStartPre = "${lib.getExe' pkgs.coreutils "mkdir"} -p -m 0700 ${inst.keyDir}";
            ExecStart = "${bin} --key-dir ${inst.keyDir}";
            Environment = [ "SSH_TPM_AUTH_SOCK=%t/${name}.sock" ];
            SuccessExitStatus = 2;
          };
        }) instances;
      };
    };
}
