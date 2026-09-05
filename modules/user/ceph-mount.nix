# Registry key: flake.modules.homeManager.user-ceph-mount
# Configures: the ceph_mount_ctl script and its pinned Ceph package set.
# Imported by: modules/user/home.nix (user-home).
_: {
  flake.modules.homeManager.user-ceph-mount =
    {
      pkgs,
      inputs,
      ...
    }:

    let
      pin = import ../../lib/pinned-pkgs.nix { inherit pkgs; };

      # Ceph packages from pinned input for stability
      ceph-pkgs = pin.pinned inputs.pkgs-ceph;

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
        text = builtins.readFile ./ceph-mount-ctl.sh;
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
