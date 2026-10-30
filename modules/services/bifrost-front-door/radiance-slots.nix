# radiance slot states on the petunia edge.
# Registry key: flake.modules.nixos.services-bifrost-front-door (merges with
# default.nix).
# llama-swap decides which radiance slots run (8000, or 8002 + 8003 for a GPU
# pair). This unit reads llama-swap's /running (read-only: it never loads a
# model) every few seconds and sets each server of be_radiance through the
# HAProxy runtime API: `ready` when llama-swap reports the slot ready, `maint`
# when it does not. So the stats and the metrics show an idle slot as MAINT
# and keep DOWN for a loaded slot that fails its health check. When
# llama-swap does not answer, the states stay as they are.
_: {
  flake.modules.nixos.services-bifrost-front-door =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      fd = config.services.bifrost-front-door;
      route = "radiance";
      servers = lib.concatMapStringsSep " " (
        s: "${toString s.port}=${s.name}"
      ) fd.routes.${route}.upstream.servers;
    in
    {
      systemd.services.radiance-slot-sync = {
        description = "Set the radiance slot servers of the edge from llama-swap";
        wantedBy = [ "multi-user.target" ];
        after = [ "bifrost-front-door.service" ];
        wants = [ "bifrost-front-door.service" ];
        path = [
          pkgs.curl
          pkgs.jq
          pkgs.socat
          pkgs.gnugrep
        ];
        script = ''
          set -uo pipefail
          sock=${fd.runtimeApi.socket}
          backend=be_${route}
          declare -A prev=()
          tick=0
          unreachable=0
          while true; do
            if running=$(curl -sf --max-time 2 http://127.0.0.1:7999/running); then
              unreachable=0
              ready=$(jq -r '.running[] | select(.state == "ready") | .cmd
                | capture("--port[ =](?<p>[0-9]+)").p' <<<"$running" 2>/dev/null || true)
              for pair in ${servers}; do
                port=''${pair%%=*}
                name=''${pair#*=}
                if grep -qx "$port" <<<"$ready"; then want=ready; else want=maint; fi
                # Apply on a change, and again every minute (HAProxy restart).
                if [ "''${prev[$name]:-}" != "$want" ] || [ $((tick % 20)) -eq 0 ]; then
                  if echo "set server $backend/$name state $want" \
                    | socat -t 2 stdio "UNIX-CONNECT:$sock" >/dev/null; then
                    [ "''${prev[$name]:-}" = "$want" ] || echo "$name: $want"
                    prev[$name]=$want
                  fi
                fi
              done
            elif [ "$unreachable" = 0 ]; then
              echo "llama-swap /running does not answer; the server states stay as they are"
              unreachable=1
            fi
            tick=$((tick + 1))
            sleep 3
          done
        '';
        serviceConfig = {
          DynamicUser = true;
          SupplementaryGroups = [ fd.runtimeApi.group ];
          ReadWritePaths = [ (dirOf fd.runtimeApi.socket) ];
          Restart = "always";
          RestartSec = 5;
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          RestrictAddressFamilies = [
            "AF_UNIX"
            "AF_INET"
            "AF_INET6"
          ];
        };
      };
    };
}
