{ den, ... }:
{
  den.homes.x86_64-linux."groot@forge" = {
    includes = [ den.aspects.user-groot-aspect ];
  };
}
