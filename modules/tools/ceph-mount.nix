_: {
  flake.modules.homeManager.user-ceph-mount =
    {
      pkgs,
      inputs,
      ...
    }:

    let
      # Ceph packages from pinned input for stability
      ceph-pkgs = import inputs.pkgs-ceph {
        inherit (pkgs.stdenv.hostPlatform) system;
        config.allowUnfree = true;
      };

      ceph-mount-ctl = pkgs.writeShellApplication {
        name = "ceph_mount_ctl";
        runtimeInputs = with pkgs; [
          jq
          ceph-pkgs.ceph # Provides 'ceph-fuse'
          ceph-pkgs.ceph-client # Provides 'ceph', 'rados', 'rbd' and other essential tools
          pass
          util-linux
          fuse # Provides 'fusermount'
          fuse3 # Provides 'fusermount3'
          iputils
          gnugrep
          coreutils
        ];
        text = ''
          # CephFS User-Space Mount Controller
          # Managed by Nix Home Manager

          VOLUMES_CONFIG="$HOME/.config/ceph/volumes.json"
          CLIENT_ID="z16.ddukes" # Matches the spec example

          show_help() {
              echo "Usage: ceph_mount_ctl [mount|unmount|list] <alias>"
              echo ""
              echo "Commands:"
              echo "  mount <alias>    Mount a CephFS volume by alias"
              echo "  unmount <alias>  Unmount a CephFS volume by alias"
              echo "  list             List available volume aliases"
          }

          list_volumes() {
              if [[ ! -f "$VOLUMES_CONFIG" ]]; then
                  echo "Error: Configuration file not found at $VOLUMES_CONFIG"
                  exit 1
              fi
              jq -r '.aliases | keys[]' "$VOLUMES_CONFIG"
          }

          mount_volume() {
              local alias="''${1}"
              
              if [[ ! -f "$VOLUMES_CONFIG" ]]; then
                  echo "Error: Configuration file not found at $VOLUMES_CONFIG"
                  exit 1
              fi

              # 1. Lookup
              local entry
              entry=$(jq -r ".aliases.\"$alias\"" "$VOLUMES_CONFIG")
              if [[ "$entry" == "null" ]]; then
                  echo "Error: Alias '$alias' not found in $VOLUMES_CONFIG"
                  exit 1
              fi

              local csi_path cluster_id fs_name
              csi_path=$(echo "$entry" | jq -r '.csi_path')
              cluster_id=$(echo "$entry" | jq -r '.cluster_id')
              fs_name=$(echo "$entry" | jq -r '.fs_name')

              # 2. Auth from pass
              local pass_path="ceph/clusters/$cluster_id/clients/$CLIENT_ID"
              echo "Retrieving credentials from pass: $pass_path"
              
              local secret_data
              if ! secret_data=$(pass show "$pass_path"); then
                  echo "Error: Failed to retrieve secret from pass at $pass_path"
                  exit 1
              fi
              
              # Extract key: Look for 'key=' line, otherwise fallback to first line
              local key
              if echo "$secret_data" | grep -q "^key="; then
                  key=$(echo "$secret_data" | grep "^key=" | head -n 1 | cut -d'=' -f2-)
              else
                  key=$(echo "$secret_data" | head -n 1)
              fi

              # Extract monitors: Look for 'mons=' or 'mon_host='
              local mons
              if echo "$secret_data" | grep -q "^mons="; then
                  mons=$(echo "$secret_data" | grep "^mons=" | head -n 1 | cut -d'=' -f2-)
              elif echo "$secret_data" | grep -q "^mon_host="; then
                  mons=$(echo "$secret_data" | grep "^mon_host=" | head -n 1 | cut -d'=' -f2-)
              fi

              if [[ -z "$key" || -z "$mons" ]]; then
                  echo "Error: Invalid secret format in pass. Expected key and mons= list."
                  exit 1
              fi

              # Sanity check: Ceph keys are base64 and usually end in ==
              if [[ ! "$key" =~ ^[A-Za-z0-9+/]+={0,2}$ ]]; then
                  echo "Warning: Extracted key does not look like valid Base64. Check your pass entry."
              fi

              # 3. Pre-flight
              echo "Verifying connectivity to monitors: $mons"
              local connected=false
              IFS=',' read -ra MON_IPS <<< "$mons"
              for ip in "''${MON_IPS[@]}"; do
                  # Handle potential whitespace
                  ip=$(echo "$ip" | xargs)
                  if timeout 1 bash -c "cat < /dev/null > /dev/tcp/$ip/6789" 2>/dev/null; then
                      connected=true
                      break
                  fi
              done

              if [[ "$connected" == "false" ]]; then
                  echo "Error: Could not connect to any Ceph monitors on port 6789."
                  exit 1
              fi

              local mount_point="$HOME/mnt/ceph/$alias"
              mkdir -p "$mount_point"

              # 4. Execute
              # Create a temporary keyring file
              local keyring_file
              keyring_file=$(mktemp)
              chmod 600 "$keyring_file"
              printf "[client.%s]\n\tkey = %s\n" "$CLIENT_ID" "$key" > "$keyring_file"

              local run_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ceph/$alias"
              mkdir -p "$run_dir"

              echo "Mounting $csi_path to $mount_point..."
              
              # Execute mount with explicit configuration to support unprivileged operation.
              # - Positional mountpoint is used for the local directory.
              # - --no-mon-config, -m, and -c /dev/null bypass system-wide config files.
              # - --run_dir and associated flags redirect runtime artifacts (sockets, logs, PIDs)
              #   to a user-owned directory, avoiding permission issues with /var/run/ceph.
              ceph-fuse \
                  --id "$CLIENT_ID" \
                  -k "$keyring_file" \
                  -c /dev/null \
                  --client_mds_namespace "$fs_name" \
                  -r "$csi_path" \
                  -m "$mons" \
                  --no-mon-config \
                  --run_dir "$run_dir" \
                  --admin_socket "$run_dir/admin.asok" \
                  --log_file "$run_dir/client.log" \
                  --pid_file "$run_dir/client.pid" \
                  "$mount_point"

              # Clean up the keyring file after ceph-fuse has read it
              rm -f "$keyring_file"
          }

          unmount_volume() {
              local alias="''${1}"
              local mount_point="$HOME/mnt/ceph/$alias"
              local run_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ceph/$alias"
              local pid_file="$run_dir/client.pid"

              if ! mountpoint -q "$mount_point"; then
                  echo "Info: $mount_point is not a mount point."
                  rm -rf "$run_dir" 2>/dev/null || true
                  return
              fi

              echo "Unmounting $mount_point..."

              # 1. Graceful Process Termination (Bypasses FUSE permission shadowing)
              if [[ -f "$pid_file" ]]; then
                  local pid
                  pid=$(cat "$pid_file")
                  echo "Sending termination signal to ceph-fuse (PID: $pid)..."
                  if kill -SIGTERM "$pid" 2>/dev/null; then
                      # Wait up to 5 seconds for clean teardown
                      for _ in {1..10}; do
                          if ! mountpoint -q "$mount_point"; then
                              echo "Successfully unmounted."
                              break
                          fi
                          sleep 0.5
                      done
                  fi
              fi

              # 2. Fallback to FUSE tools if the process was already dead or signal failed
              if mountpoint -q "$mount_point"; then
                  echo "Process did not exit, attempting fusermount tools..."
                  # Try both fusermount3 and fusermount for compatibility
                  if ! fusermount3 -u "$mount_point" 2>/dev/null; then
                      fusermount -u "$mount_point" 2>/dev/null || true
                  fi
              fi

              # 3. Nuclear option (requires sudo if standard tools fail)
              if mountpoint -q "$mount_point"; then
                  echo "Warning: Unmount stuck. Attempting sudo lazy unmount..."
                  sudo umount -l "$mount_point"
              fi

              # 4. Clean up the runtime artifacts
              if ! mountpoint -q "$mount_point" && [[ -d "$run_dir" ]]; then
                  echo "Cleaning up runtime directory: $run_dir"
                  rm -rf "$run_dir"
              fi
          }

          case "''${1:-}" in
              mount)
                  if [[ -z "''${2:-}" ]]; then show_help; exit 1; fi
                  mount_volume "''${2}"
                  ;;
              unmount)
                  if [[ -z "''${2:-}" ]]; then show_help; exit 1; fi
                  unmount_volume "''${2}"
                  ;;
              list)
                  list_volumes
                  ;;
              *)
                  show_help
                  ;;
          esac
        '';
      };
    in
    {
      home.packages = [ ceph-mount-ctl ];

      # Default volumes configuration (placeholder as per spec)
      xdg.configFile."ceph/volumes.json.example".text = ''
        {
          "aliases": {
            "example": {
              "csi_path": "/volumes/csi/csi-vol-00000000-0000-0000-0000-000000000000",
              "cluster_id": "example-cluster",
              "fs_name": "cephfs"
            }
          }
        }
      '';
    };
}
