_: {
  flake.modules.nixos.hardware-petunia = _: {
    security.tpm2 = {
      enable = true;
      pkcs11.enable = true;
      tctiEnvironment.enable = true;
    };

    boot.initrd.systemd.tpm2.enable = true;
  };
}
