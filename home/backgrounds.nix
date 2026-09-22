{
  config,
  lib,
  pkgs,
  ...
}: let
  # backgrounds/<theme>/<file> is installed to Pictures/backgrounds; just `git add` new ones.
  root = ../backgrounds;
  themes = lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir root));
  filesOf = theme: lib.attrNames (lib.filterAttrs (_: type: type == "regular") (builtins.readDir (root + "/${theme}")));

  # Wallpaper for a fresh session; checked at build time so a rename can't dangle.
  defaultTheme = "rose-pine";
  defaultWallpaper = let
    file = "nbhd_v2.jpg";
  in
    lib.throwIf (!lib.elem file (filesOf defaultTheme))
    "backgrounds: the default wallpaper ${defaultTheme}/${file} is no longer in the tree"
    file;
in {
  home.file = lib.listToAttrs (lib.concatMap (theme:
    map (file: {
      name = "Pictures/backgrounds/${theme}/${file}";
      value.source = root + "/${theme}/${file}";
    }) (filesOf theme))
  themes);

  # `current` is the active wallpaper; per-theme links remember each theme's last one.
  # Seeds both with the default when missing.
  home.activation.initWallpaper = lib.hm.dag.entryAfter ["linkGeneration"] ''
    dir="$HOME/.local/share/wallpaper"
    fallback="$HOME/Pictures/backgrounds/${defaultTheme}/${defaultWallpaper}"
    mkdir -p "$dir"
    if [ ! -e "$dir/current" ]; then
      ln -sfn "$fallback" "$dir/current.new" && mv -T "$dir/current.new" "$dir/current"
    fi
    if [ ! -e "$dir/${defaultTheme}" ]; then
      case "$(readlink "$dir/current")" in
        "$HOME/Pictures/backgrounds/${defaultTheme}/"*) target="$(readlink "$dir/current")" ;;
        *) target="$fallback" ;;
      esac
      ln -sfn "$target" "$dir/${defaultTheme}.new" && mv -T "$dir/${defaultTheme}.new" "$dir/${defaultTheme}"
    fi
  '';

  # Supervised by systemd so a crash doesn't break every later `awww img`.
  systemd.user.services.awww-daemon = {
    Unit = {
      Description = "awww wallpaper daemon";
      PartOf = ["graphical-session.target"];
      After = ["graphical-session.target"];
    };

    Service = {
      ExecStart = "${pkgs.awww}/bin/awww-daemon";
      Restart = "always";
      RestartSec = 1;
    };

    Install.WantedBy = ["graphical-session.target"];
  };
}
