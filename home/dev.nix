{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableFishIntegration = true;
  };

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      editor = "hx";
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*".addKeysToAgent = "yes";
  };

  home.file.".cargo/config.toml".text = ''
    [net]
    git-fetch-with-cli = true
  '';

  home.sessionVariables = {
    CARGO_HOME = "$HOME/.cargo";
    GOPATH = "$HOME/go";
    GOBIN = "$HOME/go/bin";
    # winit/wgpu dlopen these libraries outside nix-shell.
    LD_LIBRARY_PATH = lib.makeLibraryPath [pkgs.wayland pkgs.libxkbcommon pkgs.vulkan-loader];
  };

  programs.fish.interactiveShellInit = ''
    fish_add_path $HOME/.cargo/bin
    fish_add_path $HOME/go/bin
    fish_add_path $HOME/.bun/bin
    fish_add_path $HOME/.local/bin
  '';
}
