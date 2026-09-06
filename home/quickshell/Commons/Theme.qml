pragma Singleton

import QtQuick
import Quickshell

Singleton {
  id: root

  readonly property color base: "#191724"
  readonly property color surface: "#1f1d2e"
  readonly property color overlay: "#26233a"
  readonly property color muted: "#6e6a86"
  readonly property color subtle: "#908caa"
  readonly property color text: "#e0def4"
  readonly property color love: "#eb6f92"
  readonly property color gold: "#f6c177"
  readonly property color rose: "#ebbcba"
  readonly property color pine: "#31748f"
  readonly property color foam: "#9ccfd8"
  readonly property color iris: "#c4a7e7"
  readonly property color highlightLow: "#21202e"
  readonly property color highlightMed: "#403d52"
  readonly property color highlightHigh: "#524f67"

  // Bar modules sit on the wallpaper, which is often the same ink as base.
  // Lift them one step so each pill reads as its own surface.
  readonly property color barModule: surface

  readonly property color accent: love
  readonly property color urgent: love

  readonly property color lockFail: "#cc2222"

  readonly property real fillNormal: 0.04
  readonly property real fillHover: 0.08
  readonly property real fillSelected: 0.18
  readonly property real fillPressed: 0.22
  readonly property real borderNormal: 0.4
  readonly property real borderHover: 0.25
  readonly property real borderSelected: 1.0

  function withAlpha(c, a) {
    return Qt.rgba(c.r, c.g, c.b, a);
  }

  function rowFill(hovered, selected) {
    if (selected)
      return withAlpha(accent, fillSelected);
    if (hovered)
      return withAlpha(text, fillHover);
    return "transparent";
  }

  function controlFill(hovered, focused) {
    if (focused)
      return withAlpha(text, fillHover);
    if (hovered)
      return withAlpha(text, fillHover);
    return withAlpha(text, fillNormal);
  }

  function controlBorder(hovered, focused) {
    if (focused || hovered)
      return withAlpha(accent, borderSelected);
    return withAlpha(overlay, borderNormal);
  }

  // The Nerd Font carries the icon glyphs and holds digits on a fixed advance,
  // so it stays for icons, hardware identifiers and live readouts. Prose and
  // labels move to a proportional face, which reads better than monospace at
  // bar and panel sizes.
  readonly property string fontFamily: "JetBrainsMono Nerd Font"
  readonly property string iconFont: fontFamily
  readonly property string monoFont: fontFamily
  readonly property string uiFont: "Inter"
  // Inter's large-optical-size cut, for type big enough that the text cut
  // looks loose.
  readonly property string displayFont: "Inter Display"

  readonly property int weightRegular: Font.Normal
  readonly property int weightMedium: Font.Medium
  readonly property int weightSemi: Font.DemiBold

  // Small labels want a little air; large numerals want less.
  readonly property real trackingLabel: 0.2
  readonly property real trackingDisplay: -0.4

  readonly property int fontSize: 12
  readonly property int fontSizeSmall: 10
  readonly property int fontSizeLarge: 13
  readonly property int fontSizeXl: 16
  readonly property int fontSizeDisplay: 24
  readonly property int fontSizeDisplayLg: 28

  readonly property int spacingXs: 2
  readonly property int spacingSm: 4
  readonly property int spacingMd: 8
  readonly property int spacingLg: 12
  readonly property int spacingXl: 16
  readonly property int spacingXxl: 24

  readonly property int cornerRadius: 6
  readonly property int gapsOut: 5

  readonly property int panelPadding: spacingXl
  readonly property int panelRowInset: spacingLg
  readonly property int panelRowRadius: 8
  readonly property int panelRowHeight: 34
  readonly property int panelWidthNarrow: 300
  readonly property int panelWidthWide: 380
  readonly property int panelWidthWidest: 440
  // Keep long device lists inside a scrolling card.
  readonly property int panelMaxHeight: 460

  // The display layout map. Monitor rectangles are drawn in logical Hyprland
  // coordinates scaled to fit this box.
  readonly property int displayCanvasHeight: 150
  readonly property int displayRadius: 4
  // Drag snap threshold, in canvas pixels rather than layout pixels, so the
  // pull feels the same however far out the map is zoomed.
  readonly property int displaySnapDistance: 12

  readonly property int barHeight: 26
  readonly property int barMarginTop: 6
  readonly property int barMarginLeft: 3
  readonly property int barMarginRight: 9
  readonly property int barGroupPadding: 8
  readonly property int barItemGap: 8

  // Widgets own this padding; the containing row must not add spacing.
  readonly property int barIconPadding: 6
  readonly property int barLabelGap: 6

  readonly property int barPillPadding: 12
  readonly property int barPillPaddingWide: 14
  // Character limits alone do not constrain wide glyphs.
  readonly property int barMprisMaxWidth: 320
  readonly property int barNixPadding: 7
  readonly property int barNixMinWidth: 15
  readonly property int barNixFontSize: 15

  readonly property int workspacePadding: 4
  readonly property int workspaceRadius: 18
  readonly property int workspaceGap: 6

  readonly property int animFast: 150
  readonly property int animSlow: 300
}
