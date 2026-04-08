{ pkgs, ... }:

let
  # Verified from `pw-cli info <id> | grep node.name`
  eeSrcNode = "easyeffects_source";

  # This script acts as a persistent consumer for the EasyEffects source node.
  # It ensures the input capture pipeline remains active regardless of application state,
  # preventing the need for external catalysts like pavucontrol to trigger the chain.
  keepaliveScript = pkgs.writeShellScript "ee-input-keepalive" ''
    echo "Waiting for EasyEffects source node..."
    while ! ${pkgs.pipewire}/bin/pw-cli ls Node 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q "${eeSrcNode}"; do
      ${pkgs.coreutils}/bin/sleep 2
    done
    echo "Node found. Starting keepalive consumer."

    exec ${pkgs.pipewire}/bin/pw-record --target "${eeSrcNode}" /dev/null
  '';
in
{
  # EasyEffects input pipeline keepalive service
  # Maintains a constant capture stream on the virtual source to keep the processing
  # chain live across session transitions and hardware re-enumeration.
  systemd.user.services.ee-input-keepalive = {
    Unit = {
      Description = "EasyEffects input pipeline keepalive";
      After = [
        "pipewire.service"
        "wireplumber.service"
        "easyeffects.service"
      ];
      PartOf = [ "graphical-session.target" ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${keepaliveScript}";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };

  # EasyEffects dconf settings: Logic for hardware tracking
  # Configures EasyEffects to dynamically track the default system source and
  # process only the default playback/capture streams. This prevents stale
  # PCI device lookups and reduces overhead.
  dconf.settings = {
    "com/github/wwmm/easyeffects" = {
      use-default-input-device = true;
      use-default-output-device = true;
      process-all-inputs = false;
      process-all-outputs = false;
      last-used-output-device = "";
      last-used-input-device = "";
      output-blocklist = [ ];
      input-blocklist = [ ];
    };
  };
}
