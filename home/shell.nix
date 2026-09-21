{
  pkgs,
  lib,
  ...
}: {
  # Recolours the terminal this fish lives in after a theme switch. The theme's
  # fish fragment (see theme.nix) sets `theme_osc` — background, foreground,
  # cursor, selection background, selection foreground, bare hex — and every
  # running fish picks the universal variable up and repaints its Ghostty
  # surface over OSC. A Ghostty config reload cannot do this: it recolours only
  # new cells and new windows, so open ones keep the colours they started with.
  # A function file rather than an init line, so fish autoloads the handler at
  # event time and shells that were already running when the config landed
  # handle the next switch too. New fish emit nothing, which is right: their
  # window already read the new theme's config.
  xdg.configFile."fish/functions/__theme_osc.fish".text = ''
    function __theme_rgb
      string join / "rgb:"(string sub --length 2 --start 1 $argv[1]) \
        (string sub --length 2 --start 3 $argv[1]) \
        (string sub --length 2 --start 5 $argv[1])
    end

    function __theme_osc --on-variable theme_osc --description "Recolour the terminal after a theme switch"
      test -t 1; or return 0
      set -l c (string split ' ' -- $theme_osc)
      test (count $c) -eq 5; or return 0
      printf '\033]11;%s\007\033]10;%s\007\033]12;%s\007\033]17;%s\007\033]19;%s\007' \
        (__theme_rgb $c[1]) (__theme_rgb $c[2]) (__theme_rgb $c[3]) (__theme_rgb $c[4]) (__theme_rgb $c[5])
    end
  '';

  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      set fish_greeting ""
    '';

    shellAliases = {
      ls = "eza -lh --group-directories-first --icons=auto";
      lt = "eza --tree --level=2 --long --icons --git";
      la = "eza -lha --group-directories-first --icons=auto";

      # Picks nixosConfigurations.<hostname>.
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos";
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
        src = pkgs.fishPlugins.fzf-fish.src;
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

  # Match spaceship-prompt.
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

      # The per-state symbols carry theme colours, so theme.nix adds them to each theme's
      # copy of this file, and starship.toml is linked to the active one.
      git_status = {
        style = "";
        format = "([ $ahead_behind$all_status]($style))";
        up_to_date = "";
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

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      auto_sync = false;
      update_check = false;
      style = "compact";
      filter_mode_shell_up_key_binding = "session";
    };
  };

  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    # Atuin owns Ctrl-R; fzf keeps Ctrl-T and Alt-C.
    historyWidget.command = "";
    # The colours are read from FZF_DEFAULT_OPTS_FILE, which follows the theme.
    defaultOptions = [
      "--height 40%"
      "--border"
    ];
  };

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

  # Theme vendored from github.com/drluckyspin/rose-pine-bat. Which theme is used is set by
  # bat/config, linked to the active theme in theme.nix.
  programs.bat = {
    enable = true;
    themes."Rose-Pine-Moon" = {
      src = ./themes;
      file = "Rose-Pine-Moon.tmTheme";
    };
  };
}
