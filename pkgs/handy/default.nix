# Handy, the offline dictation app, patched to publish its overlay events on a socket
# so the island can draw the overlay (see shell-bridge.patch), and given its typing and
# clipboard tools. It finds those with `which`, so they go on its own PATH rather than
# relying on whatever the systemd user manager inherited.
{
  lib,
  handy,
  symlinkJoin,
  makeWrapper,
  which,
  wtype,
  wl-clipboard,
}: let
  patched = handy.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./shell-bridge.patch];
  });
in
  symlinkJoin {
    inherit (patched) name version meta;
    paths = [patched];
    nativeBuildInputs = [makeWrapper];
    postBuild = ''
      rm $out/bin/handy
      makeWrapper ${lib.getExe patched} $out/bin/handy --prefix PATH : ${lib.makeBinPath [which wtype wl-clipboard]}
    '';
  }
