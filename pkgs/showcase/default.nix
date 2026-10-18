# README screenshots and showcase.webp, shot on a sandboxed nested Hyprland; see showcase.sh.
{
  writeShellApplication,
  bubblewrap,
  coreutils,
  datefudge,
  dbus,
  fastfetch,
  ffmpeg-headless,
  gawk,
  grim,
  jq,
  libnotify,
  libwebp,
  perl,
  python3,
  wf-recorder,
  wtype,
}:
writeShellApplication {
  name = "showcase";
  runtimeInputs = [bubblewrap coreutils datefudge dbus fastfetch ffmpeg-headless gawk grim jq libnotify libwebp perl wf-recorder wtype];
  # Hyprland, quickshell, ghostty, helix and helium come from the running system, since
  # they are what is being shown.
  text =
    ''
      export SHOWCASE_FIXTURES=${./fixtures}
      export SHOWCASE_PYTHON=${python3.withPackages (ps: [ps.dbus-next])}/bin/python3
    ''
    + builtins.readFile ./showcase.sh;
}
