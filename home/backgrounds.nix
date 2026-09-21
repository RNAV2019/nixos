{
  config,
  lib,
  pkgs,
  ...
}: let
  # One folder per theme, each installed as Pictures/backgrounds/<theme>/<file>. Read off
  # the tree rather than listed, so a new wallpaper only needs a `git add`.
  root = ../backgrounds;
  themes = lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir root));
  filesOf = theme: lib.attrNames (lib.filterAttrs (_: type: type == "regular") (builtins.readDir (root + "/${theme}")));
in {
  home.file = lib.listToAttrs (lib.concatMap (theme:
    map (file: {
      name = "Pictures/backgrounds/${theme}/${file}";
      value.source = root + "/${theme}/${file}";
    }) (filesOf theme))
  themes);

  # `current` is the wallpaper that is up. Next to it, one link per theme records the last
  # wallpaper used with that theme, so switching back reopens on it. The wallpapers used to
  # sit flat in the folder; a link still pointing there dangles once they move, and is sent
  # to the Rose Pine default rather than left for awww to fail on. After linkGeneration, so
  # the old links are already gone and the new ones already there.
  home.activation.initWallpaper = lib.hm.dag.entryAfter ["linkGeneration"] ''
    dir="$HOME/.local/share/wallpaper"
    fallback="$HOME/Pictures/backgrounds/rose-pine/nbhd_v2.jpg"
    mkdir -p "$dir"
    if [ ! -e "$dir/current" ]; then
      ln -sfn "$fallback" "$dir/current.new" && mv -T "$dir/current.new" "$dir/current"
    fi
    if [ ! -e "$dir/rose-pine" ]; then
      case "$(readlink "$dir/current")" in
        "$HOME/Pictures/backgrounds/rose-pine/"*) target="$(readlink "$dir/current")" ;;
        *) target="$fallback" ;;
      esac
      ln -sfn "$target" "$dir/rose-pine.new" && mv -T "$dir/rose-pine.new" "$dir/rose-pine"
    fi
  '';

  # A bare `awww-daemon &` from start-desktop dies unsupervised, and every
  # later `awww img` then fails with exit 1. systemd owns it instead.
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
