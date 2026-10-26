# Packages built in this repo, as an overlay so modules can use pkgs.<name>.
final: prev: {
  # Desktop session
  lock-session = final.callPackage ./lock-session {};
  start-desktop = final.callPackage ./start-desktop {};
  # Hyprland plugin: the drag-and-drop card pile.
  dragpile = final.callPackage ./dragpile {};
  rose-pine-gtk-theme = final.callPackage ./rose-pine-gtk-theme {};
  # gtk4 with the user gtk.css reloaded live; grafted in by modules/system.
  gtk4-live-css = final.callPackage ./gtk4-live-css {};
  # The launcher's emoji table, from nixpkgs' Unicode and CLDR data.
  quickshell-emoji = final.callPackage ./quickshell-emoji {};
  # Offline dictation: nixpkgs' build, given its typing tools.
  handy = final.callPackage ./handy {inherit (prev) handy;};

  # Command-line tools
  gen-commit = final.callPackage ./gen-commit {};
  ical-agenda = final.callPackage ./ical-agenda {};
  forward-dev = final.callPackage ./forward-dev {};
  typst-preview-window = final.callPackage ./typst-preview-window {};
  showcase = final.callPackage ./showcase {};
  claude-statusline = final.callPackage ./claude-statusline {};
  claude-usage = final.callPackage ./claude-usage {};
  t3code-nightly = final.callPackage ./t3code-nightly {};

  # Helium extensions
  fetchCrx = final.callPackage ./fetch-crx {};
  helium-bionic-reading = final.callPackage ./helium-bionic-reading {};
  helium-jump-labels = final.callPackage ./helium-jump-labels {};
}
