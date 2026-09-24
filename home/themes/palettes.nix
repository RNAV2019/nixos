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
      "#0b0b0b"
      "#ff5c5c"
      "#d6d6d6"
      "#ffd166"
      "#a6a6a6"
      "#ffb3b3"
      "#8c8c8c"
      "#d6d6d6"
      "#3f3f3f"
      "#ff8a8a"
      "#ffffff"
      "#ffe09a"
      "#d6d6d6"
      "#ffd1d1"
      "#a6a6a6"
      "#ffffff"
    ];
  };

  # "Ariadne": mint from the teal-sky balloon wallpaper (backgrounds/ariadne), black panels,
  # with the balloon for love. Board 24 of the Ariadne Penpot page is the spec.
  ariadne = {
    label = "Ariadne";
    paletteName = "ariadne";

    base = "#002018";
    surface = "#0a0a0a";
    overlay = "#1e1c1a";
    # muted and highlightMed are lifted into the sage family: the warm greys the design
    # started with measured 1.5:1 and 1.03:1 on the translucent terminal ground.
    muted = "#707e78";
    subtle = "#8a8a86";
    text = "#e6e4de";
    love = "#e0563b";
    gold = "#d99f66";
    rose = "#d8a8bc";
    pine = "#8c94a9";
    foam = "#7cc4c0";
    iris = "#3eddb8";
    highlightLow = "#141311";
    highlightMed = "#2e4c45";
    highlightHigh = "#3a5a50";

    accent = "#3eddb8";

    # Helium's tab strip, a shade of its black chrome rather than the teal ground.
    browserFrame = "#141311";

    # The terminal reads softer than the shell: sage text and a cream cursor.
    terminalText = "#90a8a0";
    cursor = "#fff7eb";

    ansi = [
      "#1e1c1a"
      "#e0563b"
      "#8ce8ac"
      "#c0b468"
      "#8c94a9"
      "#d8a8bc"
      "#7cc4c0"
      "#90a8a0"
      "#3a5a50"
      "#ea7a62"
      "#3eddb8"
      "#d99f66"
      "#a8b0c4"
      "#e6c2d1"
      "#a0dcd8"
      "#f2e8d8"
    ];
  };
}
