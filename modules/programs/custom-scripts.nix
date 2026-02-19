{ pkgs }:

rec {
  battery-alert = pkgs.writeShellScriptBin "battery-alert" ''
    # Waybar Battery Alert Daemon
    ALERT_FILE="/tmp/waybar-style-alert.css"
    BATTERY_PATH=$(find /sys/class/power_supply/BAT* -print -quit)
    THRESHOLD=15

    cleanup() {
        echo -n "" > "$ALERT_FILE"
        ${pkgs.procps}/bin/pkill -SIGUSR2 waybar
        exit
    }

    trap cleanup EXIT INT TERM
    touch "$ALERT_FILE"

    check_battery() {
        CAPACITY=$(cat "$BATTERY_PATH/capacity")
        STATUS=$(cat "$BATTERY_PATH/status")

        if [ "$STATUS" = "Discharging" ] && [ "$CAPACITY" -le "$THRESHOLD" ]; then
            if [ ! -s "$ALERT_FILE" ]; then
                echo "window#waybar { background-color: #880000; transition: none; }" > "$ALERT_FILE"
                ${pkgs.procps}/bin/pkill -SIGUSR2 waybar
            fi
        else
            if [ -s "$ALERT_FILE" ]; then
                echo -n "" > "$ALERT_FILE"
                ${pkgs.procps}/bin/pkill -SIGUSR2 waybar
            fi
        fi
    }

    check_battery
    if ${pkgs.bash}/bin/command -v ${pkgs.inotify-tools}/bin/inotifywait >/dev/null; then
        while ${pkgs.inotify-tools}/bin/inotifywait -q -e close_write "$BATTERY_PATH/capacity" "$BATTERY_PATH/status"; do
            check_battery
        done
    else
        while true; do
            check_battery
            sleep 5
        done
    fi
  '';

  system-stats =
    pkgs.writers.writePython3Bin "system-stats"
      {
        libraries = [ ];
        doCheck = false;
      }
      ''
        import time
        import sys
        import json


        # Configuration
        BLOCKS = [" ", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
        COLORS = {
            "low": "#00FF00",
            "med": "#FFFF00",
            "high": "#FF0000",
            "crit": "#FF00FF"
        }


        def get_cpu_usage():
            try:
                with open("/proc/stat", "r") as f:
                    lines = f.readlines()
            except Exception:
                return []

            cores = []
            for line in lines:
                if line.startswith("cpu") and line.split()[0] != "cpu":
                    parts = [int(x) for x in line.split()[1:]]
                    idle = parts[3] + parts[4]
                    total = sum(parts)
                    cores.append({"idle": idle, "total": total})
            return cores


        def get_gpu_usage():
            gpus = []
            paths = [
                "/sys/class/drm/card1/device/gpu_busy_percent",
                "/sys/class/drm/card2/device/gpu_busy_percent"
            ]
            for path in paths:
                try:
                    with open(path, "r") as f:
                        val = int(f.read().strip())
                        gpus.append(val)
                except Exception:
                    gpus.append(0)
            return gpus


        def format_graph(percent):
            idx = int((percent / 100) * (len(BLOCKS) - 1))
            char = BLOCKS[idx]
            color = COLORS["low"]
            if percent > 80:
                color = COLORS["crit"]
            elif percent > 60:
                color = COLORS["high"]
            elif percent > 30:
                color = COLORS["med"]
            return f"<span color='{color}'>{char}</span>"


        def main():
            prev_cpu = get_cpu_usage()
            time.sleep(1)
            curr_cpu = get_cpu_usage()
            cpu_graph = ""
            total_cpu_load = 0
            core_count = 0
            for prev, curr in zip(prev_cpu, curr_cpu):
                total_d = curr["total"] - prev["total"]
                idle_d = curr["idle"] - prev["idle"]
                usage = 100 * (total_d - idle_d) / total_d if total_d > 0 else 0
                cpu_graph += format_graph(usage)
                total_cpu_load += usage
                core_count += 1
            avg_cpu = int(total_cpu_load / core_count) if core_count > 0 else 0
            gpu_loads = get_gpu_usage()
            gpu_graph = ""
            avg_gpu = 0
            if gpu_loads:
                avg_gpu = int(sum(gpu_loads) / len(gpu_loads))
                for load in gpu_loads:
                    gpu_graph += format_graph(load)
            text = f"CPU {cpu_graph} {avg_cpu}%   GPU {gpu_graph} {avg_gpu}%"
            tooltip = f"CPU Load: {avg_cpu}%\\nGPU Load: {avg_gpu}%"
            print(json.dumps({
                "text": text,
                "tooltip": tooltip,
                "class": "custom-stats"
            }))
            sys.stdout.flush()


        if __name__ == "__main__":
            main()
      '';

  audio-selector =
    pkgs.writers.writePython3Bin "audio-selector"
      {
        libraries = [ ];
        doCheck = false;
      }
      ''
        import subprocess
        import sys
        import shutil

        # Leveraging absolute paths for dmenu and pactl provides a more robust and
        # self-contained audio management tool within the Nix ecosystem.
        MENU_CMD = "${pkgs.wofi}/bin/wofi --dmenu -i -p 'Select Audio Device'"
        if not shutil.which("${pkgs.wofi}/bin/wofi"):
            MENU_CMD = "${pkgs.dmenu}/bin/dmenu -i -p 'Select Audio Device'"

        PA_CTL = "${pkgs.pulseaudio}/bin/pactl"


        def get_devices(dev_type):
            try:
                cmd = f"{PA_CTL} list short {dev_type}"
                output = subprocess.check_output(cmd, shell=True).decode()
            except Exception:
                return []
            devices = []
            for line in output.strip().split('
        '):
                if not line:
                    continue
                parts = line.split('	')
                dev_id = parts[0]
                dev_name = parts[1]
                devices.append({'id': dev_id, 'name': dev_name, 'desc': dev_name})
            try:
                cmd_full = f"{PA_CTL} list {dev_type}"
                full_out = subprocess.check_output(cmd_full, shell=True).decode()
                current_id = None
                desc_map = {}
                for line in full_out.split('
        '):
                    line = line.strip()
                    if line.startswith(f"{dev_type[:-1]} #"):
                        current_id = line.split('#')[1]
                    elif line.startswith("Description:") and current_id:
                        desc_map[current_id] = line.split(':', 1)[1].strip()
                        current_id = None
                for dev in devices:
                    if dev['id'] in desc_map:
                        dev['desc'] = desc_map[dev['id']]
            except Exception:
                pass
            return devices


        def main():
            if len(sys.argv) < 2:
                sys.exit(1)
            mode = sys.argv[1]
            type_name = "sinks" if mode == "sink" else "sources"
            devices = get_devices(type_name)
            if not devices:
                sys.exit(1)
            menu_input = "
        ".join([f"{d['id']}: {d['desc']}" for d in devices])
            try:
                p = subprocess.Popen(
                    MENU_CMD, shell=True, stdin=subprocess.PIPE,
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE
                )
                stdout, _ = p.communicate(input=menu_input.encode())
                selection = stdout.decode().strip()
                if not selection:
                    sys.exit(0)
                selected_id = selection.split(':')[0]
                set_cmd = f"{PA_CTL} set-default-{mode} {selected_id}"
                subprocess.run(set_cmd, shell=True, check=True)
                stream_type = "sink-inputs" if mode == "sink" else "source-outputs"
                try:
                    ls_cmd = f"{PA_CTL} list short {stream_type}"
                    streams = subprocess.check_output(ls_cmd, shell=True).decode()
                    for line in streams.strip().split('
        '):
                        if line:
                            stream_id = line.split('	')[0]
                            mv_cmd = f"{PA_CTL} move-{mode}-input {stream_id} {selected_id}"
                            if mode == "source":
                                mv_cmd = (
                                    f"{PA_CTL} move-source-output "
                                    f"{stream_id} {selected_id}"
                                )
                            subprocess.run(mv_cmd, shell=True)
                except Exception:
                    pass
            except Exception:
                sys.exit(1)


        if __name__ == "__main__":
            main()
      '';
}
