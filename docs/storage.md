# Storage & Cluster Integration

This document covers the tools and steps for reaching remote storage
clusters, specifically CephFS, through the user-space mount controller.

## CephFS User-Space Mount Controller (`ceph_mount_ctl`)

The `ceph_mount_ctl` is a Bash controller managed by Home Manager. It hides
the complexity of CSI UUIDs, retrieves credentials from your secure `pass`
store, and uses FUSE for non-privileged mounting.

### 1. Prerequisites

Before you use the controller, prepare your environment:

1.  **Group Membership**: Your user must be in the `fuse` group. The `nix-nexus` configuration handles this for you.
2.  **Secret Storage**: Store credentials in `pass`. The controller expects this structure:
    - **Path**: `ceph/clusters/<cluster_id>/clients/z16.ddukes`
    - **Format**:
      ```text
      <BASE64_ENCODED_KEY>
      fsid=<cluster_fsid>
      mons=<ip1>,<ip2>,<ip3>
      ```
3.  **Volume Mapping**: Define your volumes in `~/.config/ceph/volumes.json`.

### 2. Configuration (`volumes.json`)

The mapping file translates readable aliases to cluster-specific CSI paths.

**Path**: `~/.config/ceph/volumes.json`
**Schema**:
```json
{
  "aliases": {
    "work": {
      "csi_path": "/volumes/csi/csi-vol-<uuid>",
      "cluster_id": "prod-cluster",
      "fs_name": "cephfs"
    },
    "backups": {
      "csi_path": "/volumes/csi/csi-vol-<another-uuid>",
      "cluster_id": "backup-cluster",
      "fs_name": "cephfs"
    }
  }
}
```

### 3. Usage

The `ceph_mount_ctl` command gives a simple interface for managing your mounts.

#### List Available Aliases
To see which volumes are set in your `volumes.json`:
```bash
ceph_mount_ctl list
```

#### Mount a Volume
Mounting happens into `~/mnt/ceph/<alias>`. The controller checks network
connectivity to the monitors and fetches keys from `pass` on its own.
```bash
ceph_mount_ctl mount work
```

#### Unmount a Volume
The controller uses `fusermount3` for clean teardowns. If the mount is
busy, it tries a lazy unmount.
```bash
ceph_mount_ctl unmount work
```

### 4. Implementation Details

- **FUSE-based**: The mount needs no `sudo` or kernel-level mounting.
- **Stateless**: No persistent keyrings sit on disk. Secrets exist only in memory during the mount handshake.
- **Pre-flight Checks**: The controller checks connectivity to at least one Monitor IP on port 6789 before it attempts the mount. This avoids long hang times.
