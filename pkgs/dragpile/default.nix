{
  lib,
  hyprland,
  hyprlandPlugins,
  meson,
  ninja,
}:
hyprlandPlugins.mkHyprlandPlugin {
  pluginName = "dragpile";
  version = "0.1";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [./meson.build ./src];
  };

  nativeBuildInputs = [meson ninja] ++ hyprland.nativeBuildInputs;
  mesonBuildType = "release";

  meta = {
    description = "A cursor-chasing pile of file cards for every Wayland drag and drop";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
}
