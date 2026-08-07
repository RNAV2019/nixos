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
    '';

    shellAliases = {
      ls = "eza -lh --group-directories-first --icons=auto";
      lt = "eza --tree --level=2 --long --icons --git";
      la = "eza -lha --group-directories-first --icons=auto";

      rebuild = "sudo nixos-rebuild switch --flake ~/nixos#ryans-nixos";
      nix-clean = "sudo nix-collect-garbage -d";
      cx = "claude --dangerously-skip-permissions";

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
      {
        name = "rose-pine";
        src = pkgs.fetchFromGitHub {
          owner = "rose-pine";
          repo = "fish";
          rev = "127a990e5ad4688118c950123787fb0686afa4c8";
          hash = "sha256-3heI6nhItw5WfKGQT1FRQKfv+lONyn+DzwYjYqJjzLE=";
        };
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
        "$fill"
        "$git_state"
        "$git_status"
        "$cmd_duration"
        "$line_break"
        "$character"
      ];

      fill = {
        symbol = " ";
        style = "";
      };

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
        style = "";
        format = "([ $ahead_behind$all_status]($style))";
        conflicted = "[!](bold fg:#eb6f92)";
        ahead = "[⇡\${count}](bold fg:#9ccfd8)";
        behind = "[⇣\${count}](bold fg:#f6c177)";
        diverged = "[⇡\${ahead_count}⇣\${behind_count}](bold fg:#f6c177)";
        up_to_date = "";
        untracked = "[?\${count} ](fg:#6e6a86)";
        stashed = "[⊙\${count} ](fg:#c4a7e7)";
        modified = "[!\${count} ](fg:#f6c177)";
        staged = "[+\${count} ](fg:#9ccfd8)";
        renamed = "[»\${count} ](fg:#c4a7e7)";
        deleted = "[✗\${count} ](fg:#eb6f92)";
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
      "--color=bg+:#26233a,bg:#191724,spinner:#ebbcba,hl:#eb6f92"
      "--color=fg:#e0def4,header:#eb6f92,info:#c4a7e7,pointer:#ebbcba"
      "--color=marker:#ebbcba,fg+:#e0def4,prompt:#c4a7e7,hl+:#eb6f92"
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

  # bat — Rose Pine themed syntax highlighting.
  # Theme from https://github.com/drluckyspin/rose-pine-bat (vendored under ./themes).
  programs.bat = {
    enable = true;
    config.theme = "Rose-Pine-Moon";
    themes."Rose-Pine-Moon" = {
      src = ./themes;
      file = "Rose-Pine-Moon.tmTheme";
    };
  };
}
