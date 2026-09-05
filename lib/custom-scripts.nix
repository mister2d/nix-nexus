# Helper: returns an attrset of shell script derivations (battery-alert,
# system-stats, audio-selector, llm-init, rocm-init).
# Called by: modules/programs/dev/scripts.nix, modules/desktop/hyprland-home.nix,
# modules/user/dev-home.nix.
{ pkgs }:

{
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
                echo "window#waybar { background-color: #AA0000; transition: none; }" > "$ALERT_FILE"
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
            "low": "#00AA00",
            "med": "#AAAA00",
            "high": "#AA0000",
            "crit": "#AA00AA"
        }


        def get_cpu_usage():
            try:
                with open("/proc/stat", "r") as f:
                    lines = f.readlines()
            except Exception:
                return []

            cpu_stats = []
            for line in lines:
                if line.startswith("cpu") and line.split()[0] != "cpu":
                    parts = [int(x) for x in line.split()[1:]]
                    idle = parts[3] + parts[4]
                    total = sum(parts)
                    cpu_stats.append({"idle": idle, "total": total})
            return cpu_stats


        def get_gpu_usage():
            import glob
            gpu_stats = []
            # Dynamically discover all GPU busy percentage files
            paths = glob.glob("/sys/class/drm/card*/device/gpu_busy_percent")
            for path in paths:
                try:
                    with open(path, "r") as f:
                        val = int(f.read().strip())
                        gpu_stats.append(val)
                except Exception:
                    pass
            return gpu_stats


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
            for line in output.strip().split('\n'):
                if not line:
                    continue
                parts = line.split('\t')
                dev_id = parts[0]
                dev_name = parts[1]
                devices.append({'id': dev_id, 'name': dev_name, 'desc': dev_name})
            try:
                cmd_full = f"{PA_CTL} list {dev_type}"
                full_out = subprocess.check_output(cmd_full, shell=True).decode()
                current_id = None
                desc_map = {}
                for line in full_out.split('\n'):
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
            menu_input = "\n".join([f"{d['id']}: {d['desc']}" for d in devices])
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
                    for line in streams.strip().split('\n'):
                        if line:
                            stream_id = line.split('\t')[0]
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

  llm-init = pkgs.writeShellScriptBin "llm-init" ''
    # Generate a portable LLM/CUDA project environment
    if [ -f "flake.nix" ] || [ -f ".envrc" ]; then
        echo "Error: flake.nix or .envrc already exists in this directory."
        exit 1
    fi

    echo "Creating Nix Flake for CUDA/LLM development..."
    cat <<'EOF' > flake.nix
    {
      description = "Portable LLM/CUDA Inference Environment";

      inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
      };

      outputs = { self, nixpkgs }: let
        system = "x86_64-linux";
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in {
        devShells.''${system}.default = pkgs.mkShell {
          name = "llm-cuda-shell";

          # Isolated development toolchain
          buildInputs = with pkgs; [
            python312
            python312Packages.pip
            python312Packages.virtualenv
            uv
            stdenv.cc.cc.lib
            zlib
            # Modern CUDA 13.x compatibility via redistributables
            cudaPackages.cuda_nvcc
            cudaPackages.cuda_cudart
          ];

          # Bridge the "ABI Gap" between Nix and Host (e.g., Debian)
          shellHook = '''
            # 1. Setup Virtual Environment
            if [ ! -d ".venv" ]; then
              echo "Creating virtual environment with uv..."
              uv venv .venv
            fi
            source .venv/bin/activate

            # 2. Bridge the ABI Gap
            # We only add specific libraries from the host to avoid glibc poisoning.
            CUDA_BRIDGE_DIR="/tmp/nix-cuda-bridge-$USER"
            mkdir -p "$CUDA_BRIDGE_DIR"
            for lib in libcuda.so.1 libnvidia-ml.so.1 libnvidia-ptxjitcompiler.so.1 libcuda.so; do
              if [ -f "/usr/lib/x86_64-linux-gnu/$lib" ]; then
                ln -sf "/usr/lib/x86_64-linux-gnu/$lib" "$CUDA_BRIDGE_DIR/$lib"
              fi
            done

            export LD_LIBRARY_PATH="''${pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib pkgs.zlib pkgs.ncurses5 ]}:$CUDA_BRIDGE_DIR:$LD_LIBRARY_PATH"

            # 3. Compiler flags for compiling llama.cpp and others from source
            export CUDA_PATH=''${pkgs.cudaPackages.cuda_nvcc}
            export EXTRA_CCFLAGS="-I/usr/local/cuda/include"
            export EXTRA_LDFLAGS="-L/usr/lib/x86_64-linux-gnu"

            echo "🚀 CUDA LLM Environment Initialized."
            echo "Host Driver: 590.48.01 | CUDA: 13.1 (Bridge Active)"
            echo "Tip: Use 'uv pip install <package>' for 10x faster installs."
          ''';
        };
      };
    }
    EOF

    echo "Creating .envrc for direnv..."
    echo "use flake" > .envrc

    if command -v direnv >/dev/null 2>&1; then
        echo "Running 'direnv allow'..."
        direnv allow
    else
        echo "Tip: Install 'direnv' to automatically load this environment upon entry."
    fi

    echo "Done. Happy coding!"
  '';

  rocm-init = pkgs.writeShellScriptBin "rocm-init" ''
    # Generate a portable ROCm project environment for AMD GPUs (Z16)
    if [ -f "flake.nix" ] || [ -f ".envrc" ]; then
        echo "Error: flake.nix or .envrc already exists in this directory."
        exit 1
    fi

    echo "Creating Nix Flake for ROCm/LLM development..."
    cat <<'EOF' > flake.nix
    {
      description = "Portable ROCm/LLM Inference Environment";

      inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
      };

      outputs = { self, nixpkgs }: let
        system = "x86_64-linux";
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in {
        devShells.''${system}.default = pkgs.mkShell {
          name = "rocm-llm-shell";

          buildInputs = with pkgs; [
            python312
            python312Packages.pip
            python312Packages.virtualenv
            uv
            # ROCm Packages for development
            rocmPackages.clr
            rocmPackages.rocminfo
            clinfo
            stdenv.cc.cc.lib
          ];

          shellHook = '''
            if [ ! -d ".venv" ]; then
              echo "Creating virtual environment with uv..."
              uv venv .venv
            fi
            source .venv/bin/activate

            # ROCm/PyTorch Compatibility Variables
            export HSA_OVERRIDE_GFX_VERSION=10.3.0
            export LD_LIBRARY_PATH="''${pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib pkgs.rocmPackages.clr ]}:$LD_LIBRARY_PATH"

            echo "🚀 ROCm LLM Environment Initialized."
            echo "GPU: AMD Radeon (RDNA2 Override Active)"
            echo "Tip: Install torch with ROCm support via: uv pip install torch --index-url https://download.pytorch.org/whl/rocm6.2"
          ''';
        };
      };
    }
    EOF

    echo "Creating .envrc for direnv..."
    echo "use flake" > .envrc

    if command -v direnv >/dev/null 2>&1; then
        echo "Running 'direnv allow'..."
        direnv allow
    fi
    echo "Done. Use 'nix develop' or allow direnv to enter the shell."
  '';
}
