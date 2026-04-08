{ ... }:
{
  # ============================================================================
  # User Aspect: The Personal Environment
  # ============================================================================

  den.aspects.user-ddukes-aspect = {
    nixos = { ... }: {
      home-manager.users.ddukes = {
        imports = [ ./_user/home.nix ];
        home.stateVersion = "25.11";
      };
    };
  };
}
