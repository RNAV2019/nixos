# Theme palettes keyed by id, using Rose Pine role names; ../theme.nix generates every
# program's colours from these and Commons/Theme.qml mirrors them.
{
  rose-pine = {
    label = "Rosé Pine";
    paletteName = "rose-pine";

    base = "#191724";
    surface = "#1f1d2e";
    overlay = "#26233a";
    muted = "#6e6a86";
    subtle = "#908caa";
    text = "#e0def4";
    love = "#eb6f92";
    gold = "#f6c177";
    rose = "#ebbcba";
    pine = "#31748f";
    foam = "#9ccfd8";
    iris = "#c4a7e7";
    highlightLow = "#21202e";
    highlightMed = "#403d52";
    highlightHigh = "#524f67";

    accent = "#c4a7e7";
  };

  # "ASCII world": monochrome from the Creation of Adam dot-matrix wallpaper, with three warm
  # colours kept for alerts, warnings and tints. Board 15 of the dark Penpot page.
  dark = {
    label = "Dark";
    paletteName = "ascii-world";

    base = "#0b0b0b";
    surface = "#141414";
    overlay = "#1f1f1f";
    muted = "#8c8c8c";
    subtle = "#a6a6a6";
    text = "#ffffff";
    love = "#ff5c5c";
    gold = "#ffd166";
    rose = "#ffb3b3";
    pine = "#8c8c8c";
    foam = "#d6d6d6";
    iris = "#ffffff";
    highlightLow = "#181818";
    highlightMed = "#303030";
    highlightHigh = "#3f3f3f";

    accent = "#ffffff";

    # Greys in place of hues, keeping red, yellow and magenta warm.
    ansi = [
      "#0b0b0b" # black
      "#ff5c5c" # red
      "#d6d6d6" # green
      "#ffd166" # yellow
      "#a6a6a6" # blue
      "#ffb3b3" # magenta
      "#8c8c8c" # cyan
      "#d6d6d6" # white
      "#3f3f3f" # bright black
      "#ff8a8a" # bright red
      "#ffffff" # bright green
      "#ffe09a" # bright yellow
      "#d6d6d6" # bright blue
      "#ffd1d1" # bright magenta
      "#a6a6a6" # bright cyan
      "#ffffff" # bright white
    ];
  };
}
