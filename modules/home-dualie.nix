{ den, ... }:
{
  den.homes.x86_64-linux."groot@dualie" = {
    includes = [ den.aspects.user-groot-aspect ];
  };
}
