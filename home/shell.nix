{ config, pkgs, ... }:
{
  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      # Disable fish greeting
      set fish_greeting = ""

      # Zoxide init
      zoxide init fish | source

      # Atuin init (shell history)
      atuin init fish | source 
    '';

    shellAliases = {
      ls = "eza -lh --group-directories-first --icons=auto";
      lt = "eza --tree --level=2 --long --icons --git";
      la = "eza -lha --group-directories-first --icons=auto";

      rebuild = "sudo nixos-rebuild switch --flake ~/nixos-config#ryans-nixos";      
      hm-switch = "home-manager switch --flake ~/nixos-config#ryan";
      nix-clean = "sudo nix-collect-garbage -d";

      grep = "rg";
      find = "fd";
      top = "btop";
    };

    plugins = [
      {
        name = "done";
        src = pkgs.fishPlugins.done.src; # Notify when long commands are done
      }
      {
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish.src; # FZF integration for fish
      }
    ];
  };

  # Starship terminal prompt
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = true;
      format = "$directory$git_branch$git_status$nix_shell$rust$nodejs$python$haskell$character";

      character = {
        success_symbol = "[a](bold green)";
        error_symbol   = "[b](bold red)";
      };

      directory = {
        style = "bold blue";
        truncation_length = 3;
        truncate_to_repo = true;
      };

      git_branch = {
        symbol = "gb";
        style = "bold purple";
      };

      git_status = {
        symbol = "gs";
        style = "bold red";
      };

      nix_shell = {
        symbol = "ns";
        style = "bold cyan";
      };

      rust = {
        symbol = "r";
        style = "bold orange";
      };

      nodejs = {
        symbol = "n";
        style = "bold green";
      };

      
      haskell = {
        symbol = "h";
        style = "bold purple";
      };
    };
  };

  # Zoxide
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  # Atuin - shell history with search
  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      auto_sync = false; # cloud sync
      update_check = false;
      style = "compact";
      filter_mode_shell_up_key_binding = "session";
    };
  };

  # FZF
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    defaultOptions = [
      "--height 40%"
      "--border"
      "--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,h1:#f38ba8"
      "--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc"
      "--color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+#f38ba8" 
    ];
  };

  # Git
  programs.git = {
    enable = true;
    userName = "Ryan Navsaria";
    userEmail = "ryannav2019@gmail.com";
    delta.enable = true;
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      core.editor = "hx";
    };
  };
}
