# herdr's Claude Code integration, provisioned declaratively.
#
# `herdr integration install claude` writes two things: a hook script under
# ~/.claude/hooks, and a SessionStart entry in ~/.claude/settings.json that
# runs it. The hook reports Claude's session id to the herdr socket, which is
# what lets herdr resume a pane into the same conversation after a server
# restart.
#
# The script is versioned inside the herdr binary (HERDR_INTEGRATION_VERSION),
# so it is generated from the pinned package rather than copied by hand.
# settings.json is merged rather than replaced: Claude Code writes its own
# keys there, so it cannot become a read-only store symlink.
#
# Merges into the user-herdr-home key rather than declaring its own, so the
# agent integration stays reviewable as a separate file.
_: {
  flake.modules.homeManager.user-herdr-home =
    {
      pkgs,
      lib,
      config,
      options,
      inputs,
      ...
    }:

    let
      pin = import ../../lib/pinned-pkgs.nix { inherit pkgs; };

      unstable-pkgs = pin.pinned inputs.nixpkgs-unstable;

      inherit (unstable-pkgs) herdr;

      # Hosts without the development home profile (avina, hermes) never
      # declare these options; those that disable LLM agents (dualie on Ivy
      # Bridge, rk3588 on ARM) have no Claude Code to integrate with.
      hasDevHome = lib.hasAttrByPath [ "nix-nexus" "user" "dev" ] options;
      claudeEnabled =
        hasDevHome && config.nix-nexus.user.dev.enable && config.nix-nexus.user.dev.enableLlmAgents;

      herdrClaudeHook =
        pkgs.runCommand "herdr-claude-hook-${herdr.version}"
          {
            nativeBuildInputs = [ pkgs.makeWrapper ];
          }
          ''
            export HOME="$(mktemp -d)"
            mkdir -p "$HOME/.claude"
            ${herdr}/bin/herdr integration install claude

            install -Dm555 "$HOME/.claude/hooks/herdr-agent-state.sh" \
              "$out/libexec/herdr-agent-state.sh"

            # The hook fails soft — it exits 0 rather than break a Claude
            # session — so a missing python3 or mktemp would silently disable
            # the integration. Pin both onto its PATH.
            makeWrapper ${pkgs.bash}/bin/bash "$out/bin/herdr-agent-state" \
              --add-flags "$out/libexec/herdr-agent-state.sh" \
              --prefix PATH : ${
                lib.makeBinPath [
                  pkgs.python3
                  pkgs.coreutils
                ]
              }
          '';

      mergeSettings = pkgs.writeShellApplication {
        name = "herdr-claude-settings-merge";
        runtimeInputs = [
          pkgs.jq
          pkgs.coreutils
        ];
        text = ''
          settings="''${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
          cmd="${herdrClaudeHook}/bin/herdr-agent-state session"

          mkdir -p "$(dirname "$settings")"
          [ -f "$settings" ] || printf '{}\n' > "$settings"

          tmp="$(mktemp "$settings.XXXXXX")"
          jq --arg cmd "$cmd" '
            .hooks //= {}
            | .hooks.SessionStart //= []
            | .hooks.SessionStart = (
                .hooks.SessionStart
                | map(.hooks |= map(select((.command // "") | contains("herdr-agent-state") | not)))
                | map(select((.hooks | length) > 0))
              )
            | .hooks.SessionStart += [{
                matcher: "*",
                hooks: [{ type: "command", command: $cmd, timeout: 10 }]
              }]
          ' "$settings" > "$tmp"
          mv "$tmp" "$settings"
        '';
      };
    in
    lib.mkIf claudeEnabled {
      # `herdr integration status` reads HERDR_INTEGRATION_VERSION out of the
      # file at this exact path, so it has to be the raw script rather than the
      # wrapper — the wrapper carries no marker and reports "outdated". Nix
      # owning the path means `herdr integration install claude` can no longer
      # write here, which is the intent: a herdr version bump moves the symlink
      # and the reported version follows.
      home.file.".claude/hooks/herdr-agent-state.sh".source =
        "${herdrClaudeHook}/libexec/herdr-agent-state.sh";

      # settings.json still calls the wrapper: same script, but with python3
      # and coreutils pinned onto PATH.
      home.activation.herdrClaudeIntegration = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${lib.getExe mergeSettings}
      '';
    };
}
