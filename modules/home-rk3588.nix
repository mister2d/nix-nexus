{ den, ... }:
{
  den.homes.aarch64-linux."groot@rk3588" = {
    includes = [ den.aspects.user-groot-aspect ];
  };
}
