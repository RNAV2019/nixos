{
  config,
  pkgs,
  ...
}: {
  xdg.configFile."helix/themes/rose_pine_transparent.toml".source = ./themes/rose_pine_transparent.toml;

  programs.helix = {
    enable = true;

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

    # Languages
    languages = {
      language-server = {
        # Rust
        rust-analyzer.config.check.command = "clippy";

        # Nix
        nixd.command = "nixd";

        # Typescript
        typescript-language-server = {
          command = "typescript-language-server";
          args = ["--stdio"];
        };

        # TailwindCSS
        tailwindcss-ls = {
          command = "tailwindcss-language-server";
          args = ["--stdio"];
        };

        # Python
        pyright = {
          command = "basedpyright-langserver";
          args = ["--stdio"];
          config = {
            python.analysis.typeCheckingMode = "basic";
          };
        };

        # Haskell
        haskell-language-server = {
          command = "haskell-language-server-wrapper";
          args = ["--lsp"];
          config = {};
        };

        # Typst
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

        # LaTeX
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
