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
      fuse3
      iputils
      gnugrep
      coreutils
    ];
    text = ''
      # Sovereign CephFS User-Space Mount Controller
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
          
          local key mons
          key=$(echo "$secret_data" | head -n 1)
          # fsid=$(echo "$secret_data" | grep "fsid=" | cut -d'=' -f2) # fsid is in pass but not strictly needed for mount
          mons=$(echo "$secret_data" | grep "mons=" | cut -d'=' -f2)

          if [[ -z "$key" || -z "$mons" ]]; then
              echo "Error: Invalid secret format in pass. Expected key on line 1 and mons= on subsequent line."
              exit 1
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
          # Create a temporary keyring file in /tmp (shm is better if available)
          local keyring_file
          keyring_file=$(mktemp)
          chmod 600 "$keyring_file"
          printf "[client.%s]\n\tkey = %s\n" "$CLIENT_ID" "$key" > "$keyring_file"

          local run_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ceph/$alias"
          mkdir -p "$run_dir"

          echo "Mounting $csi_path to $mount_point..."
          
          # Execute mount with explicit configuration to support unprivileged operation.
          # - Using both positional mountpoint and --client_mountpoint for robustness.
          # - --no-mon-config and -m bypasses the need for a local /etc/ceph/ceph.conf.
          # - --client_run_dir and associated flags redirect runtime artifacts (sockets, logs, PIDs)
          #   to a user-owned directory, avoiding permission issues with /var/run/ceph.
          ceph-fuse \
              --id "$CLIENT_ID" \
              -k "$keyring_file" \
              --client_mds_namespace "$fs_name" \
              -r "$csi_path" \
              --client_mountpoint "$mount_point" \
              -m "$mons" \
              --no-mon-config \
              --client_run_dir "$run_dir" \
              --admin_socket "$run_dir/ceph-client.$CLIENT_ID.asok" \
              --log_file "$run_dir/client.log" \
              --pid_file "$run_dir/client.pid" \
              "$mount_point"

          # Clean up the keyring file after ceph-fuse has read it
          # ceph-fuse typically forks into background; it reads config during init
          rm -f "$keyring_file"
      }

      unmount_volume() {
          local alias="''${1}"
          local mount_point="$HOME/mnt/ceph/$alias"

          if ! mountpoint -q "$mount_point"; then
              echo "Info: $mount_point is not a mount point."
              return
          fi

          echo "Unmounting $mount_point..."
          if ! fusermount3 -u "$mount_point"; then
              echo "Unmount failed. Attempting lazy unmount..."
              fusermount3 -uz "$mount_point"
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
}
