{
  config,
  pkgs,
  helix-steel,
  ...
}: let
  # Steel cogs, vendored instead of installed with `forge`.
  notify-hx = pkgs.fetchFromGitHub {
    owner = "chuwy";
    repo = "notify.hx";
    rev = "0a328073e6d3e5041346374ae747c275ab8ce746";
    hash = "sha256-shKUVnJw2j0yYO+mTHsKie+d1VrJGWDTRul+PTpqlhs=";
  };

  glyph-hx = pkgs.fetchFromGitHub {
    owner = "Ra77a3l3-jar";
    repo = "glyph.hx";
    rev = "1e63ccbc8f17511543412c955879ba672f3f8ec1"; # 0.2.0
    hash = "sha256-TpYnGqROkKfoB9G+JTjADWvMtpRJbv4NVaTqiUfW1Eg=";
  };
in {
  # Steel creates an empty helix.scm if missing; manage it instead.
  xdg.configFile."helix/helix.scm".text = "";
  xdg.configFile."helix/init.scm".source = ./helix/init.scm;

  # Pinned so cog lookup doesn't depend on whether ~/.steel exists.
  home.sessionVariables.STEEL_HOME = "${config.xdg.dataHome}/steel";

  xdg.dataFile = {
    "steel/cogs/forest".source = ./helix/forest;
    "steel/cogs/notify".source = notify-hx;
    "steel/cogs/glyph".source = glyph-hx;
  };

  programs.helix = {
    enable = true;
    package = helix-steel.packages.${pkgs.stdenv.hostPlatform.system}.default;

    settings = {
      # themes/current.toml links to the active theme's file; see theme.nix.
      theme = "current";

      editor = {
        # Otherwise Helix uses tmux's buffer under $TMUX, bypassing wl-clipboard.
        clipboard-provider = "wayland";

        bufferline = "always";
        auto-format = true;
        line-number = "relative";
        mouse = false;
        preview-completion-insert = false;
        color-modes = true;

        cursor-shape = {
          insert = "bar";
          select = "underline";
        };

        soft-wrap.enable = true;
        smart-tab.enable = false;

        statusline = {
          mode.normal = "NORMAL";
          mode.insert = "INSERT";
          mode.select = "SELECT";
          left = ["mode" "spinner"];
          center = ["file-name"];
          right = ["diagnostics" "position" "version-control" "file-type"];
        };

        lsp.display-color-swatches = true;
      };

      keys = {
        normal = {
          y = ":clipboard-yank";
          p = ":clipboard-paste-before";
        };
        select = {
          y = ":clipboard-yank";
          p = ":clipboard-paste-before";
        };
        insert = {
          "C-space" = "completion";
        };
      };
    };

    languages = {
      language-server = {
        # From the pinned toolchain so it always matches rustc.
        rust-analyzer = {
          command = "${pkgs.rustToolchain}/bin/rust-analyzer";
          config.check.command = "clippy";
        };

        nixd.command = "nixd";

        typescript-language-server = {
          command = "typescript-language-server";
          args = ["--stdio"];
        };

        tailwindcss-ls = {
          command = "tailwindcss-language-server";
          args = ["--stdio"];
        };

        pyright = {
          command = "basedpyright-langserver";
          args = ["--stdio"];
          config = {
            python.analysis.typeCheckingMode = "basic";
          };
        };

        haskell-language-server = {
          command = "haskell-language-server-wrapper";
          args = ["--lsp"];
          config = {};
        };

        tinymist = {
          command = "tinymist";
          config.preview.background = {
            enabled = true;
            args = [
              "--data-plane-host=127.0.0.1:23635"
              "--invert-colors=never"
            ];
          };
        };

        texlab = {
          config.texlab = {
            chktex = {
              onOpenAndSave = true;
              onEdit = true;
            };
            forwardSearch = {
              executable = "zathura";
              args = ["--synctex-forward" "%l:1:%f" "%p"];
            };
            build = {
              forwardSearchAfter = false;
              onSave = true;
              executable = "tectonic";
              args = [
                "-X"
                "compile"
                "--synctex"
                "-Z"
                "shell-escape"
                "%f"
              ];
              auxDirectory = "_build";
              logDirectory = "_build";
            };
          };
        };
      };

      language = [
        {
          name = "rust";
          auto-format = true;
          language-servers = ["rust-analyzer"];
        }
        {
          name = "typescript";
          auto-format = true;
          language-servers = ["typescript-language-server"];
          formatter = {
            command = "prettier";
            args = ["--parser" "typescript"];
          };
        }
        {
          name = "javascript";
          auto-format = true;
          language-servers = ["typescript-language-server"];
        }
        {
          name = "nix";
          auto-format = true;
          language-servers = ["nixd"];
          formatter.command = "alejandra";
        }
        {
          name = "html";
          language-servers = ["vscode-html-language-server" "tailwindcss-ls"];
        }
        {
          name = "css";
          language-servers = [
            "vscode-css-language-server"
            {
              name = "hx-lsp";
              only-features = ["document-colors"];
            }
          ];
        }
        {
          name = "python";
          language-servers = ["pyright"];
          roots = ["app.py" "requirements.txt"];
          indent = {
            tab-width = 4;
            unit = "t";
          };
        }
        {
          name = "haskell";
          scope = "source.haskell";
          injection-regex = "haskell";
          file-types = ["hs"];
          roots = ["Setup.hs" "stack.yaml" "*.cabal" "cabal.project" "package.yaml"];
          auto-format = true;
          language-servers = ["haskell-language-server"];
          formatter = {
            command = "fourmolu";
            args = ["--stdin-input-file" "%{buffer_name}"];
          };
        }
        {
          name = "java";
          language-servers = ["jdt-language-server"];
        }
        {
          name = "latex";
          language-servers = ["texlab"];
        }
        {
          name = "typst";
          auto-format = true;
          language-servers = ["tinymist"];
        }
      ];
    };
  };
}
