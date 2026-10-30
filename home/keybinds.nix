# The keybinds as a described table. One row per thing a key does: what it is called, which
# group the cheatsheet files it under, and the Hyprland binds (and touchpad gestures) that
# make it happen. The same rows generate the Hyprland config and the JSON the shell's
# cheatsheet (Super held) reads, so the sheet cannot drift from what is bound.
#
# A row is { group, desc, binds ? [], gestures ? [], keys ? null }:
#   binds     `bind`/`bindWith` values from desktop.nix; every one is registered.
#   gestures  Hyprland gesture specs.
#   keys      the caps shown, as a list of strings; by default the first bind's key string,
#             spelt out ("SUPER + SHIFT + B" is Super Shift B). Set it where one row stands for
#             several binds (the four arrows, 1-9) or for something that is not a key (a swipe).
# A row with no group is bound but left off the sheet.
{lib}: let
  # The sheet's groups, in the order they are drawn.
  groups = ["Apps" "Windows" "Workspaces" "Shell surfaces" "Capture" "Media" "Dictation"];

  # Key names as the cheatsheet spells them; anything missing is shown as it is bound.
  capNames = {
    SUPER = "Super";
    SHIFT = "Shift";
    CTRL = "Ctrl";
    ALT = "Alt";
    RETURN = "Return";
    ESCAPE = "Esc";
    SPACE = "Space";
    TAB = "Tab";
    LEFT = "←";
    RIGHT = "→";
    UP = "↑";
    DOWN = "↓";
    EQUAL = "=";
    MINUS = "−";
    PLUS = "+";
    UNDERSCORE = "_";
    Print = "PrtSc";
    XF86SelectiveScreenshot = "PrtSc";
    XF86Launch7 = "PrtSc";
    XF86AudioPlay = "Play";
    XF86AudioPrev = "Prev";
    XF86AudioNext = "Next";
    XF86AudioMute = "Mute";
    XF86AudioRaiseVolume = "Vol +";
    XF86AudioLowerVolume = "Vol −";
    XF86MonBrightnessUp = "Bri +";
    XF86MonBrightnessDown = "Bri −";
  };

  capsOf = keys: map (k: capNames.${k} or k) (lib.splitString " + " keys);

  # A bind is { _args = [keys dispatcher opts?]; }; the key string is the first argument.
  keysOf = b: builtins.elemAt b._args 0;

  rowKeys = row:
    if row ? keys
    then row.keys
    else capsOf (keysOf (builtins.head row.binds));

  documented = rows: lib.filter (row: (row.group or null) != null) rows;

  # The cheatsheet file: [ { group, rows: [ { desc, keys } ] } ], groups in sheet order.
  sheet = rows:
    lib.filter (g: g.rows != []) (map (group: {
        inherit group;
        rows = map (row: {
          inherit (row) desc;
          keys = rowKeys row;
        }) (lib.filter (row: row.group == group) (documented rows));
      })
      groups);
in {
  binds = rows: lib.concatMap (row: row.binds or []) rows;
  gestures = rows: lib.concatMap (row: row.gestures or []) rows;
  cheatsheet = rows: builtins.toJSON (sheet rows);
}
