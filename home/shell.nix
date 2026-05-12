{
  pkgs,
  lib,
  ...
}: {
  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      # Disable fish greeting
      set fish_greeting ""

      # Zoxide init
      zoxide init fish | source

      # Atuin init (shell history)
      atuin init fish | source
    '';

    shellAliases = {
      ls = "eza -lh --group-directories-first --icons=auto";
      lt = "eza --tree --level=2 --long --icons --git";
      la = "eza -lha --group-directories-first --icons=auto";

      rebuild = "sudo nixos-rebuild switch --flake ~/nixos#ryans-nixos";
      nix-clean = "sudo nix-collect-garbage -d";

      grep = "rg";
      find = "fd";
      top = "btop";
      cd = "z";
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

  # Starship terminal prompt — configured to mimic spaceship-prompt
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = true;

      format = lib.concatStrings [
        "$directory"
        "$git_branch"
        "$line_break"
        "$character"
      ];

      right_format = lib.concatStrings [
        "$git_state"
        "$git_status"
        "$cmd_duration"
      ];

      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
        vimcmd_symbol = "[➜](bold yellow)";
      };

      username = {
        style_user = "bold yellow";
        style_root = "bold red";
        format = "[$user]($style) ";
        show_always = false;
      };

      hostname = {
        ssh_only = true;
        format = "[$hostname](bold green) ";
      };

      directory = {
        style = "bold cyan";
        truncation_length = 3;
        truncate_to_repo = false;
        format = "[$path]($style)[$read_only]($read_only_style)";
        read_only = " ";
      };

      git_branch = {
        symbol = "";
        style = "bold magenta";
        format = "[ in ](bold white)[$branch]($style)";
      };

      git_status = {
        style = "bold red";
        format = "[\\[$all_status$ahead_behind\\]]($style) ";
        conflicted = "⬢";
        ahead = "▲\${count}";
        behind = "▼\${count}";
        diverged = "◆▲\${ahead_count}▼\${behind_count}";
        untracked = "○";
        stashed = "◇";
        modified = "●";
        staged = "■";
        renamed = "▷";
        deleted = "✖";
      };

      git_state = {
        format = "[\\($state( $progress_current/$progress_total)\\)]($style) ";
        style = "bold yellow";
      };

      cmd_duration = {
        min_time = 2000;
        format = "[$duration](bold yellow) ";
      };

      nix_shell = {
        symbol = "❄ ";
        style = "bold cyan";
        format = "[$symbol$state( \\($name\\))]($style) ";
      };

      rust = {
        symbol = " ";
        style = "bold red";
        format = "[$symbol($version )]($style)";
      };

      nodejs = {
        symbol = " ";
        style = "bold green";
        format = "[$symbol($version )]($style)";
      };

      python = {
        symbol = " ";
        style = "bold yellow";
        format = "[$symbol($version )(\\($virtualenv\\) )]($style)";
      };

      haskell = {
        symbol = "λ ";
        style = "bold magenta";
        format = "[$symbol($version )]($style)";
      };

      golang = {
        symbol = " ";
        style = "bold cyan";
        format = "[$symbol($version )]($style)";
      };

      package = {
        symbol = " ";
        style = "bold red";
        format = "[$symbol$version]($style) ";
      };

      jobs = {
        symbol = "✦";
        style = "bold blue";
        format = "[$symbol$number]($style) ";
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
      "--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8"
      "--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc"
      "--color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
    ];
  };

  # Git
  programs.git = {
    enable = true;
    settings = {
      user.name = "Ryan Navsaria";
      user.email = "ryannav2019@gmail.com";
      init.defaultBranch = "main";
      pull.rebase = true;
      core.editor = "hx";
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };
}
