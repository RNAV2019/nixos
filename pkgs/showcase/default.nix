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
  imagemagick,
  jq,
  libnotify,
  libwebp,
  perl,
  phone-bridge,
  pipewire,
  python3,
  socat,
  wf-recorder,
  wireplumber,
  wlrctl,
  wtype,
}:
writeShellApplication {
  name = "showcase";
  runtimeInputs = [bubblewrap coreutils datefudge dbus fastfetch ffmpeg-headless gawk grim imagemagick jq libnotify libwebp perl phone-bridge pipewire socat wf-recorder wireplumber wlrctl wtype];
  # Hyprland, quickshell, ghostty, helix and helium come from the running system, since
  # they are what is being shown.
  text =
    ''
      export SHOWCASE_FIXTURES=${./fixtures}
      export SHOWCASE_PYTHON=${python3.withPackages (ps: [ps.dbus-next ps.dbus-fast])}/bin/python3
      export SHOWCASE_MOCK_KDECONNECTD=${../phone-bridge/tests/mock-kdeconnectd.py}
    ''
    + builtins.readFile ./showcase.sh;
}
