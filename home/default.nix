{
  config,
  pkgs,
  hyprland,
  helium-browser,
  llm-agents,
  ...
}: {
  imports = [
    ./packages.nix
    ./shell.nix
    ./terminal.nix
    ./desktop.nix
    ./editors.nix
    ./programs.nix
    ./dev.nix
    ./custom-packages.nix
    ./backgrounds.nix
  ];

  # Home Manager basics
  home.username = "ryan";
  home.homeDirectory = "/home/ryan";
  home.stateVersion = "25.11";
  programs.home-manager.enable = true;

  # XDG directories
  xdg.enable = true;

  # Make Helium the default browser so http(s)/html links don't fall back to Firefox
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "helium.desktop";
      "x-scheme-handler/http" = "helium.desktop";
      "x-scheme-handler/https" = "helium.desktop";
      "x-scheme-handler/about" = "helium.desktop";
      "x-scheme-handler/unknown" = "helium.desktop";
      "application/xhtml+xml" = "helium.desktop";
      # Preserve Claude Code's login/OAuth deep-link handler
      "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
    };
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    documents = "${config.home.homeDirectory}/Documents";
    download = "${config.home.homeDirectory}/Downloads";
    pictures = "${config.home.homeDirectory}/Pictures";
    music = "${config.home.homeDirectory}/Music";
    videos = "${config.home.homeDirectory}/Videos";
  };

  # Session variables
  home.sessionVariables = {
    EDITOR = "hx";
    VISUAL = "hx";
    BROWSER = "helium";
    TERMINAL = "ghostty";

    # Wayland-specific
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  # UWSM environment forwarding
  xdg.configFile."uwsm/env".source = "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
}
