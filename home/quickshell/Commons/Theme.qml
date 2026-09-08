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

  // Colour is meant to read as derived from the wallpaper, so the accent is
  // the one hue the current background actually contains.
  readonly property color accent: iris
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

  readonly property int barHeight: 36
  readonly property int barMarginTop: 8
  readonly property int barMarginLeft: 24
  readonly property int barMarginRight: 24
  readonly property int barGroupPadding: 8
  readonly property int barItemGap: 8

  // Frosted surfaces. Every floating surface is a blurred crop of the
  // wallpaper under a tint, so the background blooms through wherever it has
  // detail and reads as flat ink wherever it does not.
  readonly property color surfaceTint: surface
  readonly property real surfaceTintAlpha: 0.78
  readonly property color surfaceBorder: highlightMed
  readonly property real surfaceBorderAlpha: 0.5
  // MultiEffect blur is a fraction of blurMax, not a pixel radius.
  readonly property int surfaceBlurMax: 64
  readonly property real surfaceBlur: 0.53
  readonly property int surfaceShadowOffset: 8
  readonly property int surfaceShadowMax: 32
  readonly property real surfaceShadowBlur: 0.75
  readonly property real surfaceShadowAlpha: 0.2

  // The island. One pill that carries the clock, grows an equaliser while
  // something is playing, and expands into a media and status card on hover.
  readonly property int islandRadius: 18
  readonly property int islandIdleWidth: 118
  readonly property int islandPlayingWidth: 140
  readonly property int islandExpandedWidth: 520
  readonly property int islandExpandedHeight: 84
  readonly property int islandExpandedRadius: 26
  readonly property int islandClockSize: 17
  readonly property int islandDisplaySize: 22
  readonly property int islandTitleSize: 13
  readonly property int islandCaptionSize: 11
  readonly property int islandArtSize: 48
  readonly property int islandArtRadius: 10
  readonly property int islandStatusWidth: 72

  // The app launcher. The island pill grows into this and shrinks back out of
  // it, so the two share a top edge and a centre line and read as one surface
  // changing shape rather than one surface replacing another.
  //
  // The metrics below are the source recording's own, carried onto the 520 px
  // column the rest of the shell is drawn against: a 68 px search row above a
  // rule, then rows on a 45 px pitch, each 42 px tall with a 3 px gap.
  readonly property int launcherWidth: 520
  readonly property int launcherRadius: 26
  readonly property int launcherInset: 14
  readonly property int launcherSearchHeight: 68
  readonly property int launcherGlyphLeft: 31
  readonly property int launcherGlyphSize: 18
  readonly property int launcherSearchSize: 15
  readonly property int launcherListTop: 80
  readonly property int launcherRowHeight: 42
  readonly property int launcherRowGap: 3
  readonly property int launcherRowRadius: 10
  readonly property int launcherPadBottom: 14
  readonly property int launcherIconLeft: 27
  readonly property int launcherIconSize: 26
  readonly property int launcherIconRadius: 7
  readonly property int launcherTextLeft: 66
  readonly property int launcherNameSize: 14
  readonly property int launcherDescSize: 11
  readonly property int launcherMarkerWidth: 3
  readonly property int launcherMarkerHeight: 20
  // Past this the list scrolls rather than the panel growing further.
  readonly property int launcherMaxRows: 8

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

  readonly property int workspacePadding: 14
  readonly property int workspaceRadius: 18
  readonly property int workspaceGap: 6
  readonly property int workspaceSlotWidth: 20
  readonly property int workspaceSlotActiveWidth: 36
  readonly property int workspaceSlotHeight: 16
  readonly property int workspaceSlotRadius: 8

  readonly property int animFast: 150
  readonly property int animSlow: 300

  // Every morph in the shell is critically damped: it accelerates, arrives and
  // stops, with no overshoot, wobble or settle bounce. The durations below are
  // the time each kind of surface takes to settle.
  readonly property int morphDuration: 330
  readonly property int morphSurface: 339
  // The launcher's own open, fitted to the source recording frame by frame
  // between 4:23 and 4:50. Both the width and the height ride one curve, and
  // one duration fits the pair to within 4% of their travel; the shared
  // morphCurve below already has the right shape, only the clock was long.
  readonly property int morphLauncher: 308
  readonly property int morphSubView: 311
  readonly property int morphOsd: 295
  readonly property int morphToggle: 269
  readonly property int morphSlider: 249

  // Content swaps are not morphs. Measured off the source recording at 60 fps,
  // a surface takes about 300 ms to change shape while the contents it carries
  // change over about five frames. Fading the contents on the geometry's clock
  // reads as a dissolve; this is what makes it read as a reveal instead.
  readonly property int morphContent: 80

  // Qt has no critically damped spring: SpringAnimation takes its own damping
  // scale rather than a stiffness, a mass and a damping coefficient. So the
  // real step response of a zeta = 1 system, y = 1 - (1 + wt)e^-wt, is fitted
  // here as a cubic bezier instead. The fit tracks that curve to within 0.02
  // across its whole range and, like it, both leaves and arrives at zero
  // velocity.
  readonly property var morphCurve: [0.12, 0.0, 0.22, 1.0, 1.0, 1.0]
}
