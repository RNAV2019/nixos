# Godot with Helix-style modal editing (normal / insert / select, multiple cursors) built
# into its code editors: nixpkgs' godot plus helix-mode.patch. Off until it is enabled
# under Editor Settings > Text Editor > Helix Mode, or with "Toggle Helix Mode" in the
# command palette. The patch leaves the scripting API and everything Godot writes into a
# project the same as stock, so projects shared with people on stock Godot are unaffected.
#
# helix-mode-tests.patch (unit tests and a corpus recorded from Helix 25.07.1) is not
# applied; it is kept for refreshing helix-mode.patch when nixpkgs moves to a new Godot.
{godot}:
godot.overrideAttrs (old: {
  patches = (old.patches or []) ++ [./helix-mode.patch];
})
