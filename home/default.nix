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
    ./claude.nix
  ];

  home.username = "ryan";
  home.homeDirectory = "/home/ryan";
  home.stateVersion = "25.11";
  programs.home-manager.enable = true;
  programs.omp.enable = true;
  # Migrated from ~/.omp/agent/config.yml. The module installs this as a
  # writable copy; runtime edits survive until the next rebuild.
  programs.omp.settings = {
    setupVersion = 2;
    modelRoles.default = "openrouter/stealth/ox-alpha:high";

    # Vendored rose-pine copy overriding the nerd-font context icon (U+E70F,
    # the Windows logo) with ◫. Custom themes do not merge with builtins, so
    # home/themes/dark-rose-pine-omp.json carries the full palette.
    theme.dark = "dark-rose-pine-omp";
    symbolPreset = "nerd";

    composer.shape = "claude";

    statusLine.preset = "compact";
    statusLine.transparent = true;

    tui.resizeScrollback = "preserve";
    hideThinkingBlock = true;
  };

  home.file.".omp/agent/themes/dark-rose-pine-omp.json".source = ./themes/dark-rose-pine-omp.json;
  xdg.enable = true;

  # Prevent web links from falling back to Firefox.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "helium.desktop";
      "x-scheme-handler/http" = "helium.desktop";
      "x-scheme-handler/https" = "helium.desktop";
      "x-scheme-handler/about" = "helium.desktop";
      "x-scheme-handler/unknown" = "helium.desktop";
      "application/xhtml+xml" = "helium.desktop";
      # Preserve Claude Code's OAuth handler.
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

  home.sessionVariables = {
    EDITOR = "hx";
    VISUAL = "hx";
    BROWSER = "helium";
    TERMINAL = "ghostty";

    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  # Forward Home Manager variables into UWSM.
  xdg.configFile."uwsm/env".source = "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
}
