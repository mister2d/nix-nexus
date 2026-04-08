{ lib, ... }:
{
  options.matrix = {
    matrixDomain = lib.mkOption { type = lib.types.str; };
    elementDomain = lib.mkOption { type = lib.types.str; };
    masDomain = lib.mkOption { type = lib.types.str; };
    rtcDomain = lib.mkOption { type = lib.types.str; };
    vaultAddr = lib.mkOption { type = lib.types.str; };
    certDomain = lib.mkOption { type = lib.types.str; };
    federatedDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };
}
