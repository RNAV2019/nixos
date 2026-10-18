# Packages built in this repo, as an overlay so modules can use pkgs.<name>.
final: _prev: {
  # Desktop session
  lock-session = final.callPackage ./lock-session {};
  start-desktop = final.callPackage ./start-desktop {};
  # Hyprland plugin: the drag-and-drop card pile.
  dragpile = final.callPackage ./dragpile {};
  rose-pine-gtk-theme = final.callPackage ./rose-pine-gtk-theme {};

  # Command-line tools
  gen-commit = final.callPackage ./gen-commit {};
  ical-agenda = final.callPackage ./ical-agenda {};
  forward-dev = final.callPackage ./forward-dev {};
  typst-preview-window = final.callPackage ./typst-preview-window {};
  claude-statusline = final.callPackage ./claude-statusline {};
  claude-usage = final.callPackage ./claude-usage {};
  t3code-nightly = final.callPackage ./t3code-nightly {};

  # Helium extensions
  fetchCrx = final.callPackage ./fetch-crx {};
  helium-bionic-reading = final.callPackage ./helium-bionic-reading {};
}
