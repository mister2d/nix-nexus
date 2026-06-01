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
    services-matrix-versions = import ../../modules/services/matrix/versions.nix;
    services-matrix-synapse = import ../../modules/services/matrix/synapse.nix;
    services-matrix-database = import ../../modules/services/matrix/database.nix;
    services-matrix-mas = import ../../modules/services/matrix/mas.nix;
    services-matrix-livekit = import ../../modules/services/matrix/livekit.nix;
    services-matrix-element = import ../../modules/services/matrix/element.nix;
    services-matrix-element-call = import ../../modules/services/matrix/element-call.nix;
    services-matrix-haproxy = import ../../modules/services/matrix/haproxy.nix;
    services-matrix-vault-secrets = import ../../modules/services/matrix/vault-secrets.nix;
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
