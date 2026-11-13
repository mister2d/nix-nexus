# Registry key: modules.nixos.core-nix (contributes to the Nix daemon stack)
# Configures: KVM for sandboxed Nix builds through an ACL entry on /dev/kvm,
#   so NixOS VM checks run under KVM and not on an emulated CPU.
# Imported by: profiles/server/default.nix (server-default), profiles/workstation/default.nix (workstation-default).
# Options: nix-nexus.nix.buildKvm.enable
_: {
  modules.nixos.core-nix =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.nix-nexus.nix.buildKvm;
    in
    {
      options.nix-nexus.nix.buildKvm.enable = lib.mkEnableOption ''
        KVM for sandboxed Nix builds. A udev rule adds the ACL entry group:nixbld:rw
        to /dev/kvm, and the mode of the device does not change. Use it where
        /dev/kvm is 0660 (core-microvm-host)
      '';

      config = lib.mkIf cfg.enable {
        # The Linux sandbox of Nix drops all supplementary groups before it
        # makes the user namespace, so membership in kvm does not reach a
        # build. The build keeps the primary group of its build user
        # (nixbld), and the kernel checks ACL entries against host ids.
        # The change action lets a deploy apply the entry with
        # `udevadm trigger --action=change /dev/kvm`, with no reboot.
        services.udev.extraRules = ''
          ACTION=="add|change", KERNEL=="kvm", RUN+="${pkgs.acl}/bin/setfacl -m g:nixbld:rw /dev/kvm"
        '';

        # The daemon bind-mounts /dev/kvm only into builds that need the kvm
        # system feature. The NixOS default of nix.settings.system-features
        # has it, so this module does not set the list.
        assertions = [
          {
            assertion = lib.elem "kvm" config.nix.settings.system-features;
            message = "nix-nexus.nix.buildKvm.enable needs \"kvm\" in nix.settings.system-features.";
          }
        ];
      };
    };
}
