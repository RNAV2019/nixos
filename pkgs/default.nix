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
  # The screen-share portal, telling the share picker which app is asking.
  xdg-desktop-portal-hyprland = final.callPackage ./xdg-desktop-portal-hyprland {inherit (prev) xdg-desktop-portal-hyprland;};
  # The picker xdph runs: the shell's surface, or the stock one without it.
  share-picker = final.callPackage ./share-picker {};

  # Command-line tools
  gen-commit = final.callPackage ./gen-commit {};
  ical-agenda = final.callPackage ./ical-agenda {};
  phone-bridge = final.callPackage ./phone-bridge {};
  forward-dev = final.callPackage ./forward-dev {};
  typst-preview-window = final.callPackage ./typst-preview-window {};
  showcase = final.callPackage ./showcase {};
  claude-statusline = final.callPackage ./claude-statusline {};
  claude-usage = final.callPackage ./claude-usage {};
  t3code = final.callPackage ./t3code {};
  # Claude Code hooks that tell the island a session needs the user, and raise its terminal.
  claude-island = final.callPackage ./claude-island {};
  # nixos-rebuild with nom, a saved diff and progress for the island.
  rebuild = final.callPackage ./rebuild {};
  # The island's view of udisks2: removable filesystems, mount, eject.
  island-usb = final.callPackage ./island-usb {};
  # The shell's interface sounds, synthesised with sox (Services/Sounds.qml plays them).
  quickshell-sounds = final.callPackage ./quickshell-sounds {};

  # Helium extensions
  fetchCrx = final.callPackage ./fetch-crx {};
  helium-bionic-reading = final.callPackage ./helium-bionic-reading {};
  helium-jump-labels = final.callPackage ./helium-jump-labels {};
}
