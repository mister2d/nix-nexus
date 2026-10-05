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

  # Enter the nix-devshell "full" devenv shell by git reference, no local
  # clone required. Works from any directory, regardless of that
  # directory's own repo-declared shell.
  devenv-devshell = "nix develop --refresh git+ssh://gitea@code-ssh.novuscotia.com/novuscotia-ops/nix-devshell#full";
}
