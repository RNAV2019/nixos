# Theme palettes keyed by id, using Rose Pine role names. The data lives in
# ../quickshell/Commons/palettes.json so the shell reads the same file live (it is linked out
# of store); ../theme.nix and ./helium.nix generate every other program's colours from it.
#
# Notes on the values:
# - rose-pine: `shellMuted` is the shell's muted. Rose Pine's #6e6a86 is only 3.2:1 against
#   the panel tint and carries almost every 11 px label, so the shell lifts it towards
#   `subtle` to read 4.7:1 on the darkest ground. Terminals keep the stock value.
# - dark ("ASCII world"): monochrome from the Creation of Adam dot-matrix wallpaper, with
#   three warm colours kept for alerts, warnings and tints. Board 15 of the dark Penpot page.
#   Its `ansi` puts greys in place of hues, keeping red, yellow and magenta warm.
# - ariadne: mint from the teal-sky balloon wallpaper (backgrounds/ariadne), black panels,
#   with the balloon for love. Board 24 of the Ariadne Penpot page is the spec. muted and
#   highlightMed are lifted into the sage family: the warm greys the design started with
#   measured 1.5:1 and 1.03:1 on the translucent terminal ground. `browserFrame` is Helium's
#   tab strip, a shade of its black chrome rather than the teal ground. The terminal reads
#   softer than the shell: sage `terminalText` and a cream `cursor`.
builtins.fromJSON (builtins.readFile ../quickshell/Commons/palettes.json)
