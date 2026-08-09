_: {
  flake.modules.homeManager.user-fish =
    { pkgs, ... }:

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

        shellAliases = {
          # Navigation
          ".." = "cd ..";
          "..." = "cd ../..";
          "2.." = "cd ../..";
          "3.." = "cd ../../..";
          "4.." = "cd ../../../..";
          "5.." = "cd ../../../../..";
          h = "cd ~";

          # Listing (eza-based)
          la = "eza --long --all --group";
          ll = "eza -la --icons --octal-permissions --group-directories-first";
          ls = "eza -1 --icons --group-directories-first";

          # Tools
          yz = "yazi";
          df = "df -h -x tmpfs";
          du = "du -h --max-depth=1 2> /dev/null | sort -h -r | head -n20";
          wiki = "wikiman -q";

          # Tailscale
          tup = "sudo tailscale up";
          tdown = "sudo tailscale down";
          tstatus = "tailscale status";
        };

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
