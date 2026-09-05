# Helper: returns shell aliases identical in bash and fish.
# Called by: modules/user/fish.nix, modules/user/bash.nix.
{
  ".." = "cd ..";
  "..." = "cd ../..";
  "2.." = "cd ../..";
  "3.." = "cd ../../..";
  "4.." = "cd ../../../..";
  "5.." = "cd ../../../../..";
  h = "cd ~";

  la = "eza --long --all --group";
  ll = "eza -la --icons --octal-permissions --group-directories-first";
  ls = "eza -1 --icons --group-directories-first";
  lrt = "eza -l --icons --octal-permissions --sort newest";

  yz = "yazi";
  df = "df -h -x tmpfs";
  du = "du -h --max-depth=1 2> /dev/null | sort -h -r | head -n20";
  wiki = "wikiman -q";

  tup = "sudo tailscale up";
  tdown = "sudo tailscale down";
  tstatus = "tailscale status";
}
