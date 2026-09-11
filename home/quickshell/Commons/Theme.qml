pragma Singleton

import QtQuick
import Quickshell

Singleton {
  id: root

  readonly property color base: "#191724"
  readonly property color surface: "#1f1d2e"
  readonly property color overlay: "#26233a"
  // Rose Pine's own muted is #6e6a86, which lands at 3.2:1 against the panel tint. That ink
  // carries almost every 11 px label in the shell, so it is lifted along the line towards
  // `subtle` until it reads 4.7:1 on the darkest ground the shell uses.
  readonly property color muted: "#8a86a4"
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

  // The palette every colour above comes from, for the surfaces that name it.
  readonly property string paletteName: "rose-pine"

  readonly property color accent: iris
  readonly property color urgent: love

  readonly property real fillNormal: 0.04
  readonly property real fillSelected: 0.18
  readonly property real fillPressed: 0.22
  readonly property real borderNormal: 0.4
  readonly property real borderSelected: 1.0

  function withAlpha(c, a) {
    return Qt.rgba(c.r, c.g, c.b, a);
  }

  // The Nerd Font carries the icon glyphs and holds digits on a fixed advance, so it stays
  // for icons, identifiers and live readouts. Prose and labels use a proportional face.
  readonly property string fontFamily: "JetBrainsMono Nerd Font"
  readonly property string iconFont: fontFamily
  readonly property string monoFont: fontFamily
  readonly property string uiFont: "Inter"
  // Inter's large-optical-size cut, for type big enough that the text cut looks loose.
  readonly property string displayFont: "Inter Display"

  readonly property int weightRegular: Font.Normal
  readonly property int weightMedium: Font.Medium
  readonly property int weightSemi: Font.DemiBold
  readonly property int weightBold: Font.Bold

  readonly property int fontSize: 12
  readonly property int fontSizeLarge: 13

  readonly property int spacingLg: 12

  readonly property int gapsOut: 5

  readonly property int panelRowInset: spacingLg
  readonly property int panelRowRadius: 8
  readonly property int panelRowHeight: 34

  readonly property int barHeight: 36
  readonly property int barMarginTop: 8
  readonly property int barMarginLeft: 24

  // Floating surfaces are translucent so Hyprland can blur the desktop behind them. Lower
  // shell surfaces are hidden during handoff instead of entering that blur sample.
  readonly property color surfaceTint: surface
  readonly property real surfaceTintAlpha: 0.55
  readonly property color surfaceBorder: highlightMed
  readonly property real surfaceBorderAlpha: 0.5
  // MultiEffect blur is a fraction of blurMax, not a pixel radius.
  readonly property int surfaceBlurMax: 64
  readonly property real surfaceBlur: 0.53
  readonly property int surfaceShadowOffset: 8
  readonly property int surfaceShadowMax: 32
  readonly property real surfaceShadowBlur: 0.75
  readonly property real surfaceShadowAlpha: 0.2

  // The island: one pill carrying the clock, which grows an equaliser while something is
  // playing and expands into a media and status card on hover.
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

  // The mini calendar the expanded card carries while nothing is playing. Five days centred
  // on today on a 32 px pitch; the plate is 1.14 pitches wide, which gives the three-letter
  // label its room.
  readonly property int islandCalDays: 5
  readonly property int islandCalPitch: 32
  readonly property int islandCalLabelSize: 10
  readonly property int islandCalDaySize: 13
  readonly property int islandCalTodaySize: 18
  readonly property int islandCalPlateWidth: 35
  readonly property int islandCalPlateHeight: 37
  readonly property int islandCalPlateRadius: 12
  // Row centres, measured from the top of the block.
  readonly property real islandCalLabelMid: 10.5
  readonly property real islandCalDayMid: 27.5
  readonly property real islandCalWeekendLabelAlpha: 0.55
  readonly property real islandCalWeekendDayAlpha: 0.75
  readonly property real islandCalPlateAlpha: 0.08

  // The app launcher. The island pill grows into this and shrinks back out of it, so the two
  // share a top edge and a centre line. A 68 px search row above a rule, then rows on a 45 px
  // pitch, each 42 px tall with a 3 px gap.
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

  // The notification toast: the pill grows into one card, holds while it is read, and melts
  // back into the clock. One card, not a stack; a second notification replaces the first.
  readonly property int notifWidth: 450
  readonly property int notifRadius: 28
  readonly property int notifInset: 16
  readonly property int notifTextLeft: 68
  readonly property int notifAvatarSize: 40
  readonly property int notifAvatarLetterSize: 16
  readonly property real notifAvatarAlpha: 0.22
  readonly property int notifAppTop: 17
  readonly property int notifAppSize: 11
  readonly property int notifCloseSize: 14
  readonly property int notifTitleTop: 36
  readonly property int notifTitleSize: 15
  readonly property int notifBodyTopBare: 60
  readonly property real notifBodySize: 12.5
  readonly property int notifBodyLeading: 18
  readonly property int notifBodyLines: 2
  readonly property int notifActionGapAbove: 3
  readonly property int notifActionHeight: 30
  readonly property int notifActionRadius: 15
  readonly property int notifActionGap: 10
  readonly property int notifActionPad: 16
  readonly property int notifActionSize: 12
  readonly property real notifActionSecondaryAlpha: 0.85
  readonly property int notifPadBottom: 14

  // The power menu: three tiles on one row. Lock acts on the first press; the two that end
  // the session arm first, turning love and relabelling themselves Confirm.
  readonly property int powerHeight: 112
  readonly property int powerRadius: 26
  readonly property int powerInset: 11
  readonly property int powerTileWidth: 90
  readonly property int powerTileHeight: 80
  readonly property int powerTileRadius: 16
  readonly property int powerTileGap: 12
  readonly property int powerTileTop: 16
  readonly property int powerGlyphTop: 38
  readonly property int powerGlyphSize: 22
  readonly property int powerLabelTop: 68
  readonly property int powerLabelSize: 12
  readonly property real powerTileFillAlpha: 0.9
  readonly property real powerTileBorderAlpha: 0.7

  // The on-screen displays: the pill widens in place into a glyph, a bar and a reading, holds
  // for a beat and melts back into the clock. Everything is laid out at fixed positions in a
  // fixed-width pill, so the growing shape uncovers contents already where they belong.
  readonly property int osdWidth: 278
  readonly property int osdHeight: 48
  readonly property int osdRadius: 24
  readonly property int osdGlyphLeft: 20
  readonly property int osdGlyphSize: 18
  readonly property int osdTrackLeft: 52
  readonly property int osdTrackWidth: 166
  readonly property int osdTrackHeight: 8
  readonly property int osdValueRight: 20
  readonly property int osdValueSize: 12
  // "after about a second and a half, it just melts back into the clock".
  readonly property int osdDwell: 1500

  // The control centre: the same 520 px column the launcher grows into, carrying a tile grid,
  // two sliders, the media card and the notification list. Measured off the source frames as
  // 520 x 716 on a 1920 px output.
  readonly property int controlWidth: 520
  readonly property int controlRadius: 26
  readonly property int controlInset: 13
  readonly property int controlHeaderHeight: 70
  readonly property int controlTitleSize: 18
  readonly property int controlBackSize: 36
  readonly property int controlBackLeft: 20

  // Tiles. Two rows on a 71 px pitch, each 59 px tall with a 12 px gutter; the first row is
  // one narrow tile beside one wide, the second is three equal.
  readonly property int controlTileHeight: 59
  readonly property int controlTileGap: 12
  readonly property int controlTileRadius: 29
  readonly property int controlTileBadge: 34
  readonly property int controlTileBadgeLeft: 10
  readonly property int controlTileGlyphSize: 18
  readonly property int controlTileTextLeft: 54
  readonly property int controlTileLabelSize: 13
  readonly property int controlTileSubSize: 11

  // Sliders. Thick pills whose fill is the level, with the glyph riding inside the fill.
  readonly property int controlSliderHeight: 40
  readonly property int controlSliderGap: 17
  readonly property int controlSliderGlyphLeft: 13

  // The media card, and the gap that separates each block from the next.
  readonly property int controlBlockGap: 15
  readonly property int controlMediaHeight: 140
  readonly property int controlMediaRadius: 16
  readonly property int controlMediaTitleSize: 19
  readonly property int controlMediaArtistSize: 12
  readonly property int controlMediaCaptionSize: 11
  readonly property int controlMediaPlaySize: 52
  readonly property int controlMediaSkipSize: 16
  readonly property real controlMediaProgressHeight: 3

  // The notification list.
  readonly property int controlSectionGap: 23
  readonly property int controlSectionHeight: 22
  readonly property int controlSectionSize: 11
  readonly property int controlNotifRadius: 14
  readonly property int controlNotifGap: 10
  readonly property int controlNotifAvatar: 28
  readonly property int controlNotifTextLeft: 52
  readonly property int controlNotifTitleSize: 14
  readonly property int controlNotifBodySize: 12
  readonly property int controlPadBottom: 10
  // Past this the list scrolls rather than the panel growing further.
  readonly property int controlNotifMaxHeight: 320

  // Sub-views. A 46 px pill on a 52 px pitch, under an 11 px section label.
  readonly property int controlRowHeight: 46
  readonly property int controlRowGap: 6
  readonly property int controlRowRadius: 23
  readonly property int controlRowInset: 16
  readonly property int controlViewMaxHeight: 620

  // The wallpaper picker: the pill grows into a wide, short card carrying one row of previews.
  // The column is the board's 800 rather than the source's 1008, which is the shell's own
  // proportion of the screen and fits four wallpapers exactly.
  readonly property int wallpaperWidth: 800
  readonly property int wallpaperHeight: 232
  readonly property int wallpaperRadius: 26
  readonly property int wallpaperInset: 24
  readonly property int wallpaperTitleSize: 18
  readonly property int wallpaperMetaSize: 12
  readonly property int wallpaperTitleTop: 28
  readonly property int wallpaperMetaTop: 32
  readonly property int wallpaperFooterTop: 196

  // The row is a carousel, not a grid: clipped by the panel, running on past both edges.
  readonly property int wallpaperRowMid: 130
  readonly property int wallpaperTileGap: 16
  readonly property int wallpaperTileRadius: 10

  // The chosen wallpaper is drawn larger and every other one the same, so the row has one
  // focus rather than a gradient of importance. The first is the selected width, the last is
  // everything else; four at these sizes come to 720, inside the 752 the panel has.
  readonly property var wallpaperTileWidths: [192, 160]

  // 16:9, as the board draws them. Previews are cropped to it rather than letterboxed, so a
  // tile is never part panel background.
  readonly property real wallpaperTileAspect: 16 / 9

  readonly property real wallpaperTileBorderAlpha: 0.7
  readonly property int wallpaperSelectedBorder: 2

  // Which wallpaper the keys are on is carried by the ring and the size; which one is up is
  // the accent border below, held well under the ring's weight.
  readonly property real wallpaperActiveBorderAlpha: 0.55

  // The dot sits on a disc of base, because a bare accent dot is lost in a pale corner.
  readonly property int wallpaperDotSize: 7
  readonly property int wallpaperDotInset: 8
  readonly property int wallpaperDotHalo: 14
  readonly property real wallpaperDotHaloAlpha: 0.7

  // The screen recorder's picker. The capture row is the power menu's own tile grid, to the
  // pixel; the toggle rows below are this card's own.
  readonly property int recorderWidth: 316
  readonly property int recorderHeight: 228
  readonly property int recorderRadius: 26
  readonly property int recorderInset: 11
  readonly property int recorderTileTop: 16
  readonly property int recorderTileWidth: 90
  readonly property int recorderTileHeight: 80
  readonly property int recorderTileGap: 12
  readonly property int recorderTileRadius: 16
  readonly property int recorderGlyphSize: 22
  readonly property int recorderGlyphTop: 38
  readonly property int recorderTileLabelTop: 68
  readonly property int recorderTileLabelSize: 12

  readonly property int recorderRowsTop: 108
  readonly property int recorderRowHeight: 32
  readonly property int recorderRowGap: 4
  readonly property int recorderRowRadius: 16
  readonly property int recorderRowTextLeft: 12
  readonly property int recorderRowLabelSize: 12

  // The recording mark the pill carries: love rather than the accent, so it does not read as
  // one more thing that is merely on.
  readonly property int recorderDotSize: 8
  readonly property int recorderDotGap: 10

  // The calendar. Board 14: a month grid over an agenda for the chosen day.
  readonly property int calWidth: 520
  readonly property int calHeight: 528
  readonly property int calRadius: 26
  readonly property int calInset: 24
  readonly property int calTitleTop: 26
  readonly property int calTitleSize: 18
  readonly property int calNavSize: 30
  readonly property int calNavTop: 24
  readonly property int calNavGap: 6
  readonly property int calNavGlyphSize: 15
  readonly property int calTodayBtnHeight: 28
  readonly property real calTodayBtnSize: 11.5

  // Seven columns on a 68 px pitch, six rows on 46. The day number is drawn at the row top
  // and the marker centres on it; the event dot hangs below.
  readonly property int calWeekdayTop: 74
  readonly property int calWeekdaySize: 11
  readonly property int calGridTop: 110
  readonly property int calColumnPitch: 68
  readonly property int calRowPitch: 46
  readonly property int calColumnFirst: 56
  readonly property int calDaySize: 13
  readonly property int calTodayMarker: 34
  readonly property int calDotSize: 5
  readonly property int calDotDrop: 22

  readonly property int calDividerTop: 360
  readonly property int calSectionTop: 372
  readonly property real calSectionSize: 11.5
  readonly property int calAgendaTop: 386
  readonly property int calAgendaHeight: 38
  readonly property int calAgendaGap: 4
  readonly property int calAgendaRadius: 12
  readonly property int calAgendaInset: 22
  readonly property int calSpineLeft: 12
  readonly property int calSpineWidth: 3
  readonly property int calSpineHeight: 20
  readonly property int calTimeLeft: 26
  readonly property real calTimeSize: 11.5
  readonly property int calTitleLeft: 86
  readonly property real calEventTitleSize: 12.5
  readonly property real calMetaSize: 11
  // Six agenda rows is what the panel has room for below the grid.
  readonly property int calAgendaMax: 3

  // Board 13: a 1920x1080 lock surface. The background is painted by the surface itself, so
  // the session-lock protocol never exposes a black frame.
  readonly property int lockDateTop: 150
  readonly property int lockDateSize: 20
  readonly property int lockClockTop: 175
  readonly property int lockClockSize: 112

  readonly property int lockAvatarTop: 824
  readonly property int lockAvatarSize: 56
  readonly property int lockAvatarGlyphSize: 22
  readonly property int lockUserTop: 894
  readonly property int lockUserSize: 14

  readonly property int lockFieldTop: 928
  readonly property int lockFieldWidth: 280
  readonly property int lockFieldHeight: 44
  readonly property int lockFieldRadius: 22
  readonly property int lockDotInset: 21
  readonly property int lockCaretWidth: 2
  readonly property int lockCaretHeight: 18
  readonly property int lockTextInset: 25
  readonly property int lockFieldTextSize: 13
  readonly property int lockDotSize: 8
  readonly property int lockDotGap: 4
  readonly property int lockDotPop: 80

  // The same tint and blur budget as FrostedSurface, sourced from the captured desktop.
  readonly property color lockVeilColor: surfaceTint
  readonly property real lockVeilOpacity: surfaceTintAlpha
  readonly property color lockTextPrimary: "#e0def4"
  readonly property color lockTextSecondary: "#908caa"
  readonly property color lockFieldState: "#e0def4"
  readonly property color lockFieldHint: "#6e6a86"
  readonly property color lockCaretColor: "#c4a7e7"
  readonly property real lockFieldFill: 0.8
  readonly property real lockFieldStroke: 0.55
  readonly property real lockAvatarFill: 0.85
  readonly property real lockAvatarStroke: 0.5
  readonly property real lockStrokeWidth: 1.5
  readonly property int lockBlurMax: surfaceBlurMax
  readonly property real lockBlur: surfaceBlur
  readonly property int lockIn: 350
  readonly property int lockOut: 350

  // The pill's shut width, one per combination. The widths are the design's: the pill grows
  // for a player and again for a recording, but neither moves the clock. It is centred in
  // whichever width is in play, and the equaliser and the dot sit in the padding either side,
  // so that padding is not always equal.
  function islandCollapsedWidth(media, recording) {
    return (media ? islandPlayingWidth : islandIdleWidth) + (recording ? recorderDotSize + recorderDotGap : 0);
  }

  readonly property int workspacePadding: 14
  readonly property int workspaceRadius: 18
  readonly property int workspaceGap: 6
  readonly property int workspaceSlotWidth: 20
  readonly property int workspaceSlotActiveWidth: 36
  readonly property int workspaceSlotHeight: 16
  readonly property int workspaceSlotRadius: 8

  // Every morph in the shell rides one curve for one duration, both settled by a survey of
  // ten recordings at 1440p60: 186 morphs found, 176 fitted. One duration replaces a split
  // between a 320 ms panel morph and a 240 ms reflex morph the source does not have. The
  // measured quartiles are 36 / 68 / 104 / 148 ms of travel; the fit reproduces 33 / 64 / 103 / 143.
  //
  // A surface changing shape.
  readonly property int morphSurface: 300

  // A control changing state rather than shape: a toggle, a slider, a hover or a press.
  readonly property int morphState: 180

  // Content swaps are not morphs. A surface takes about 300 ms to change shape while the
  // contents it carries change over about five frames, so fading them on the geometry's clock
  // would read as a dissolve rather than a reveal.
  readonly property int morphContent: 80

  // The handover's own content pass, for a surface growing out of another surface rather than
  // out of the island. Out of the pill the clip is the transition; panel to panel there is
  // nothing to uncover, and the 80 ms above fired on the first frame would put the contents at
  // rest while the box is still two thirds from its target.
  //
  // Chosen rather than fitted: the recordings have no panel-to-panel switch to measure.

  // The outgoing contents dissolve inside the still. Short, because it has to be finished
  // before the taker's first frame lands on top of it.
  readonly property int morphFarewell: 120

  // The still's ground outlives its contents: it covers the gap before the taker presents.
  // The taker may land anywhere in 147-216 ms, so the fade is laid across that whole window.
  // Two grounds at once would stack their tint, and a hole would read as a blink.
  readonly property int morphGround: 130
  readonly property int morphGroundFade: 100

  // The incoming contents wait, then fade, landing just before the shape settles.
  readonly property int morphEnterDelay: 90
  readonly property int morphEnter: 150

  // And they settle through a few pixels, taken in the direction the height is travelling, so
  // a switch between two columns of the same width has an axis to read.
  readonly property real morphEnterTravel: 10

  // The clock's digit roll, measured at 60 fps: each digit travels about half a glyph's height
  // and the two cross-fade. Held as a fraction of the font's own size, so the roll reads the
  // same at the pill's size and the card's.
  readonly property real clockRollTravel: 0.45

  // How long a surface that has just handed the island over keeps riding the taker's morph.
  // The taker maps in single-digit milliseconds but its first rendered frame lands 147-216 ms
  // later, and without the hold the bare pill shows through that gap; 260 covers it.
  readonly property int morphHold: 240

  // The lock screen's two cross-fades, fitted frame by frame at 60 fps. Neither is a morph:
  // the digits never move and never change size, so neither direction uses the spring.
  //
  // One progress value drives all of it. The blur radius and the dim veil ride the same curve
  // over the same window: measured as sharpness over contrast, which the veil cannot touch,
  // the radius tracks the veil to within 0.02 of its travel in both directions.
  //
  // The content lags the ground going in and leads it coming out, which is what lets the
  // island pill read as returning partway through the unlock. The clock is the extreme at
  // both ends. The date and the avatar land between the two tiers, so they are grouped by
  // what they are instead.
  readonly property int lockInClock: 70
  readonly property int lockInLogin: 100
  readonly property int lockInContent: 280
  readonly property int lockOutClock: 20
  readonly property int lockOutContent: 180

  // The shell's one motion curve. It is *not* critically damped: every morph in the recordings
  // passes its target by about 1.5 per cent of the travel and decays back over roughly 130 ms,
  // an underdamped spring near zeta = 0.84. Of the 176 fitted morphs, 98 per cent overshoot by
  // more than half a per cent, and forcing zeta = 1 nearly triples the residual.
  //
  // Qt has no spring animation that takes a damping ratio, so the response is fitted here as a
  // cubic bezier, which also lets one curve serve every Behavior in the shell. The third
  // control point sits above 1, which is how the overshoot is expressed. The fit tracks the
  // measured average to 0.46 per cent of the travel.
  readonly property var morphCurve: [0.28, 0.574, 0.302, 1.097, 1.0, 1.0]
}
