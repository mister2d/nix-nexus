_: {
  flake.modules.homeManager.user-fish =
    { pkgs, ... }:

    let
      sharedAliases = import ../../lib/shell-aliases.nix;
    in
    {
      home.packages = with pkgs; [
        eza
        yazi
        wikiman
        bat-extras.core
      ];

      programs.fish = {
        enable = true;
        generateCompletions = true;

        shellAliases = sharedAliases;

        shellAbbrs = {
          # Tool replacements
          diff = "kitten diff";
          grep = "rg -n --color=auto";
          man = "batman";
          more = "less -mrFX";

          # Location shortcuts
          cd-bl = "cd $BUILD";
          cd-wk = "cd ~/workspace";
          cd-src = "cd ~/src";

          # History
          h-se = "history --show-time=\"[%F %T] \" ";
          h-ls = "history --show-time=\"[%F %T] \" | bat -l log";
          h-de = "history --show-time=\"[%F %T] \" delete";
        };
      };
    };
}
