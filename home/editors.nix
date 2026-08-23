{
  config,
  pkgs,
  helix-steel,
  ...
}: let
  # Cogs the Steel module resolver finds under $STEEL_HOME/cogs. Vendored here
  # rather than installed with `forge`, so activation stays declarative.
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
  xdg.configFile."helix/themes/rose_pine_transparent.toml".source = ./themes/rose_pine_transparent.toml;

  # Steel looks for `helix.scm` first and writes an empty one if it is missing;
  # keep it managed so nothing lands in the config dir at startup.
  xdg.configFile."helix/helix.scm".text = "";
  xdg.configFile."helix/init.scm".source = ./helix/init.scm;

  # `(require "forest/forest.scm")` resolves relative to the requiring file, then
  # against $STEEL_HOME/cogs. $STEEL_HOME defaults to $XDG_DATA_HOME/steel unless
  # ~/.steel exists, so pin it rather than depend on which one wins.
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
      theme = "rose_pine_transparent";

      editor = {
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
        rust-analyzer.config.check.command = "clippy";

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
