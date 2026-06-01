_: {
  flake.modules.nixos = {
    hardware-z16 = import ../../profiles/hardware/z16.nix;
    hardware-petunia = import ../../profiles/hardware/petunia.nix;
    workstation-default = import ../../profiles/workstation/default.nix;
    desktop-default = import ../../profiles/desktop/default.nix;
    development-default = import ../../profiles/development/default.nix;
    openclaw-default = import ../../hosts/openclaw/default.nix;
    hermes-default = import ../../hosts/hermes/default.nix;
    sweet16-default = import ../../hosts/sweet16/default.nix;
    avina-default = import ../../hosts/avina/default.nix;
    petunia-default = import ../../hosts/petunia/default.nix;
    server-default = import ../../profiles/server/default.nix;
    services-matrix-default = import ../../modules/services/matrix/default.nix;
    programs-common = import ../../modules/programs/common.nix;
    programs-dev = import ../../modules/programs/dev.nix;
    programs-scripts = import ../../modules/programs/scripts.nix;
  };
  flake.modules.homeManager = {
    dualie-home = import ../../hosts/dualie/home.nix;
    rk3588-home = import ../../hosts/rk3588/home.nix;
    forge-home = import ../../hosts/forge/home.nix;
    sweet16-home = import ../../hosts/sweet16/home.nix;
    avina-home = import ../../hosts/avina/home.nix;
    petunia-home = import ../../hosts/petunia/home.nix;
    openclaw-home = import ../../hosts/openclaw/home.nix;
    hermes-home = import ../../hosts/hermes/home.nix;
  };
}
