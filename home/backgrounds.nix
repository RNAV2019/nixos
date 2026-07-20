{
  config,
  lib,
  ...
}: {
  home.file."Pictures/backgrounds/ching-yeh.png".source = ../backgrounds/rosepine/ching-yeh.png;
  home.file."Pictures/backgrounds/symbols.jpg".source = ../backgrounds/rosepine/symbols.jpg;
  home.file."Pictures/backgrounds/nasa.png".source = ../backgrounds/rosepine/nasa.png;
  home.file."Pictures/backgrounds/nbhd_v2.jpg".source = ../backgrounds/rosepine/nbhd_v2.jpg;

  home.activation.initWallpaper = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p "$HOME/.local/share/wallpaper"
    if [ ! -L "$HOME/.local/share/wallpaper/current" ]; then
      ln -sf "$HOME/Pictures/backgrounds/ching-yeh.png" "$HOME/.local/share/wallpaper/current"
    fi
  '';
}
