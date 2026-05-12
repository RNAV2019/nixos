{
  config,
  lib,
  ...
}: {
  home.file."Pictures/backgrounds/ching-yeh.png".source = ../backgrounds/ching-yeh.png;
  home.file."Pictures/backgrounds/blade.png".source = ../backgrounds/blade.png;
  home.file."Pictures/backgrounds/evangelion-cross.jpg".source = ../backgrounds/evangelion-cross.jpg;
  home.file."Pictures/backgrounds/reactor.png".source = ../backgrounds/reactor.png;
  home.file."Pictures/backgrounds/smoking.png".source = ../backgrounds/smoking.png;
  home.file."Pictures/backgrounds/symbols.jpg".source = ../backgrounds/symbols.jpg;
  home.file."Pictures/backgrounds/nasa.png".source = ../backgrounds/nasa.png;

  home.activation.initWallpaper = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p "$HOME/.local/share/wallpaper"
    if [ ! -L "$HOME/.local/share/wallpaper/current" ]; then
      ln -sf "$HOME/Pictures/backgrounds/ching-yeh.png" "$HOME/.local/share/wallpaper/current"
    fi
  '';
}
