# TPM-sealed SSH keys, served by two isolated ssh-tpm-agent instances.
#
# The split is the whole point: a socket forwarded into a sandbox must not be
# able to reach the personal key. ssh-tpm-agent scopes its key set by
# --key-dir, so one instance per socket is the only hard boundary — per-key
# confirmation would still let a guest *use* a key, merely with a prompt.
#
#   ssh-tpm-agent     ~/.ssh/tpm      interactive ssh, Vault-cert deploys
#   permafrost-agent  ~/.ssh/agents   forwarded to permafrost-* guests only
#
# Each instance loads only .tpm files from its directory, so plain keys left
# alongside them are ignored. Passphrases are held in a kernel session keyring
# for the lifetime of the agent process with no expiry, which is what makes a
# PIN cost one prompt per login rather than one per connection.
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

      # ssh-tpm-agent probes a fixed list of FHS askpass paths
      # (/usr/lib/ssh/gnome-ssh-askpass, /usr/bin/ksshaskpass, ...), none of
      # which exist here, and then refuses every signature with "system does
      # not have an askpass program". SSH_ASKPASS is the only way to reach a
      # prompt from a unit with no tty. Qt rather than the x11-ssh-askpass
      # NixOS otherwise defaults to, since these are Wayland sessions.
      askpass = lib.getExe' pkgs.lxqt.lxqt-openssh-askpass "lxqt-openssh-askpass";

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
      home.packages = [
        pkgs.ssh-tpm-agent
        pkgs.lxqt.lxqt-openssh-askpass
      ];

      systemd.user.sockets = lib.mapAttrs (name: inst: {
        Unit.Description = "${inst.description} socket";
        Socket = {
          ListenStream = "%t/${name}.sock";
          SocketMode = "0600";
          Service = "${name}.service";
        };
        Install.WantedBy = [ "sockets.target" ];
      }) instances;

      systemd.user.services = lib.mapAttrs (name: inst: {
        Unit = {
          Description = inst.description;
          Requires = [ "${name}.socket" ];
        };
        Service = {
          Type = "simple";
          # The agent exits non-zero if its key directory is absent, which on a
          # fresh host is the state before any key has been generated.
          ExecStartPre = "${lib.getExe' pkgs.coreutils "mkdir"} -p -m 0700 ${inst.keyDir}";
          ExecStart = "${bin} --key-dir ${inst.keyDir}";
          Environment = [
            "SSH_TPM_AUTH_SOCK=%t/${name}.sock"
            "SSH_ASKPASS=${askpass}"
            "SSH_ASKPASS_REQUIRE=force"
          ];
          SuccessExitStatus = 2;
        };
      }) instances;
    };
}
