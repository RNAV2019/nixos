{
  config,
  pkgs,
  lib,
  ...
}: {
  # Direnv - auto-load .envrc files per project
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableFishIntegration = true;
  };

  # GitHub CLI config
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      editor = "hx";
    };
  };

  # SSH config
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*".addKeysToAgent = "yes";
  };

  # Rustup config
  home.file.".cargo/config.toml".text = ''
    [net]
    git-fetch-with-cli = true
  '';

  # Environment variables for development
  home.sessionVariables = {
    CARGO_HOME = "$HOME/.cargo";
    GOPATH = "$HOME/go";
    GOBIN = "$HOME/go/bin";
    # winit/wgpu use dlopen for wayland, xkbcommon, and vulkan — needed to run GUI binaries outside nix-shell
    LD_LIBRARY_PATH = lib.makeLibraryPath [pkgs.wayland pkgs.libxkbcommon pkgs.vulkan-loader];
  };

  # Add language bin dirs to PATH via fish
  programs.fish.interactiveShellInit = ''
    # Rust
    fish_add_path $HOME/.cargo/bin

    # Go
    fish_add_path $HOME/go/bin

    # Bun
    fish_add_path $HOME/.bun/bin

    # Local Scripts
    fish_add_path $HOME/.local/bin
  '';
}
