_: {
  flake.modules.nixos.core-users =
    { pkgs, ... }:
    {
      users.users.ddukes = {
        isNormalUser = true;
        description = "ddukes";
        password = "nixos";

        extraGroups = [
          "networkmanager"
          "wheel"
          "video"
          "audio"
          "input"
          "docker"
          "fuse"
          "render"
          "kvm"
        ];

        shell = pkgs.bash;

        openssh.authorizedKeys.keys = [
          # TPM-sealed, one per host — the private half cannot leave the chip,
          # so each machine needs its own. P-256 because petunia's TPM reports
          # P-384 as supported but fails to sign with it (TPM_RC_SIZE).
          "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNFB6pgRk5PE1xMS3TlfOaJe61nDIk+yuJmuxkrtGMLZYVXBqqYnr/IKRLfX6DLIGeEOCTUJbGxXvFhoYUAmC7E= sony (TPM)"
          "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNXL5V23wci0ARBKtji+yLad2Mg0pxIflmq2clUoNVQabpYQbwhIgDHcui1CBqZnA0FdDuVtnsrWzI0XMi3GvQI= ddukes@sweet16 personal (TPM)"
          "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBBwldrZh2sFdX5Z3IyizIlgYBGKLz31t90zokoU/XLcsHGLfZW8RbDwz4c1hGGdjCDlV5eaTMipeqF8a59qiN30= ddukes@petunia personal (TPM)"
        ];
      };
    };
}
