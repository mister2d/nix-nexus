# Storage & Cluster Integration

This document outlines the tools and procedures for interacting with remote storage clusters, specifically CephFS, using the user-space mount controller.

## CephFS User-Space Mount Controller (`ceph_mount_ctl`)

The `ceph_mount_ctl` is a specialized Bash controller managed by Home Manager. It abstracts the complexity of CSI UUIDs, automates credential retrieval from your secure `pass` store, and utilizes FUSE for non-privileged mounting.

### 1. Prerequisites

Before using the controller, ensure your environment is prepared:

1.  **Group Membership**: Your user must be in the `fuse` group (handled automatically by the `nix-nexus` configuration).
2.  **Secret Storage**: Credentials must be stored in `pass`. The controller expects the following structure:
    - **Path**: `ceph/clusters/<cluster_id>/clients/z16.ddukes`
    - **Format**:
      ```text
      <BASE64_ENCODED_KEY>
      fsid=<cluster_fsid>
      mons=<ip1>,<ip2>,<ip3>
      ```
3.  **Volume Mapping**: Define your volumes in `~/.config/ceph/volumes.json`.

### 2. Configuration (`volumes.json`)

The mapping file translates human-readable aliases to cluster-specific CSI paths.

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

The `ceph_mount_ctl` command provides a simple interface for managing your mounts.

#### List Available Aliases
To see which volumes are configured in your `volumes.json`:
```bash
ceph_mount_ctl list
```

#### Mount a Volume
Mounting is performed into `~/mnt/ceph/<alias>`. The controller will automatically verify network connectivity to the monitors and fetch keys from `pass`.
```bash
ceph_mount_ctl mount work
```

#### Unmount a Volume
The controller uses `fusermount3` for clean teardowns. If the mount is busy, it will attempt a lazy unmount.
```bash
ceph_mount_ctl unmount work
```

### 4. Implementation Details

- **FUSE-based**: No `sudo` or kernel-level mounting is required.
- **Stateless**: No persistent keyrings are stored on disk. Secrets exist only in memory during the mount handshake.
- **Pre-flight Checks**: The controller verifies connectivity to at least one Monitor IP on port 6789 before attempting the mount to prevent long hang times.
