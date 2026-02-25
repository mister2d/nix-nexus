{
  pkgs,
  inputs,
  ...
}:

{
  # Add Model Control Protocol (MCP) server packages via overlay
  # These remain system-wide to ensure all users can leverage them if needed,
  # though primary tools are now in the user's dev profile.
  nixpkgs.overlays = [ inputs.mcp-servers-nix.overlays.default ];

  # System-level development utilities
  environment.systemPackages = with pkgs; [
    # Devbox is kept at system level as it's often used for bootstrapping
    devbox
  ];

  # Direnv integration for automatic environment loading
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Docker daemon is a system-wide service
  virtualisation.docker = {
    enable = true;
    storageDriver = "zfs";
  };
}
