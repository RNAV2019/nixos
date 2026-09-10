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
  // The palette every colour above comes from, for the surfaces that name it.
  readonly property string paletteName: "rose-pine"

  readonly property color accent: iris
  readonly property color urgent: love

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

  readonly property int gapsOut: 5

  readonly property int panelRowInset: spacingLg
  readonly property int panelRowRadius: 8
  readonly property int panelRowHeight: 34

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

  // The mini calendar the expanded card carries on its left while nothing is
  // playing, in the room the track block would have taken. Board 02b, and the
  // board is a transcription of the reference frame: five days centred on
  // today, on a 32 px pitch, single-letter labels over their numbers, today
  // spelled out in three letters on a plate with its number in the accent.
  //
  // The plate is wider than the pitch, which is what gives the three-letter
  // label its room; measured off the reference at 1.14 pitches.
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
  // The weekend is the one thing in the strip that is not about today.
  readonly property real islandCalWeekendLabelAlpha: 0.55
  readonly property real islandCalWeekendDayAlpha: 0.75
  readonly property real islandCalPlateAlpha: 0.08

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

  // The notification toast. Board 10, and the island's sixth shape: the pill
  // grows into one card, holds while it is read, and melts back into the clock.
  //
  // One card, not a stack. The island is one surface and can only be one shape,
  // so a second notification arriving replaces the one on screen rather than
  // queueing below it; the control centre's list is where the run of them
  // lives.
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
  readonly property int notifSourceTop: 58
  readonly property int notifSourceSize: 11
  readonly property int notifBodyTop: 82
  // Where the body starts when there is no source line to sit under.
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

  // The power menu. Board 11: three tiles on one row, and no dimmed screen
  // behind them. Lock acts on the first press; the two that end the session arm
  // first, turning love and relabelling themselves Confirm.
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

  // The on-screen displays. Board 09, and the island's fourth shape: the pill
  // widens in place into a glyph, a bar and a reading, holds for a beat and
  // melts back into the clock.
  //
  // The source recording settles what the board could only assert. Between 3:05
  // and 3:20 the OSD is never a second surface: the same pill that carries the
  // clock becomes the bar, and one frame of the return has the clock drawn back
  // over the bar as the two cross-fade.
  //
  // Everything is laid out at fixed positions in a fixed-width pill, so the
  // contents are already where they belong on the first frame and the growing
  // shape uncovers them, as the launcher's and the control centre's do.
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

  // The control centre. The island's third shape, and the same 520 px column
  // the launcher grows into, carrying a tile grid, two sliders, the media card
  // and the notification list.
  //
  // Every measurement below is board 04's, and the board is a transcription of
  // the source recording: the panel was measured off the frames at 3:26 as
  // 520 x 716 on a 1920 px output, which is the board's 520 x 718 to within the
  // border.
  readonly property int controlWidth: 520
  readonly property int controlRadius: 26
  readonly property int controlInset: 13
  readonly property int controlHeaderHeight: 70
  readonly property int controlTitleSize: 18
  readonly property int controlBackSize: 36
  readonly property int controlBackLeft: 20
  readonly property int controlIconBtnSize: 32

  // Tiles. Two rows on a 71 px pitch, each 59 px tall with a 12 px gutter; the
  // first row is one narrow tile beside one wide, the second is three equal.
  readonly property int controlTileHeight: 59
  readonly property int controlTileGap: 12
  readonly property int controlTileRadius: 29
  readonly property int controlTileBadge: 34
  readonly property int controlTileBadgeLeft: 10
  readonly property int controlTileGlyphSize: 18
  readonly property int controlTileTextLeft: 54
  readonly property int controlTileLabelSize: 13
  readonly property int controlTileSubSize: 11

  // Sliders. Thick pills whose fill is the level, with the glyph riding inside
  // the fill at the left.
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
  readonly property int controlNotifBodyTop: 68
  readonly property int controlNotifBase: 80
  readonly property int controlPadBottom: 10
  // Past this the list scrolls rather than the panel growing further.
  readonly property int controlNotifMaxHeight: 320

  // Sub-views. Rows in the source's own vocabulary: a 46 px pill on a 52 px
  // pitch, under an 11 px section label.
  readonly property int controlRowHeight: 46
  readonly property int controlRowGap: 6
  readonly property int controlRowRadius: 23
  readonly property int controlRowInset: 16
  readonly property int controlViewMaxHeight: 620

  // The wallpaper picker. Board 08, and the island's fifth shape: the pill
  // grows into a wide, short card carrying one row of previews.
  //
  // The source recording settles what the board could not. Between 3:58 and
  // 4:05 the picker is measured growing out of the pill in the island's own
  // place, from a fixed top edge, 118 px wide to 1008 x 231 - the same shape
  // language as the launcher and the control centre, at roughly twice their
  // width. The board's own column is 800, which is what is used here: it is
  // the shell's proportion of the screen rather than the source's, and four
  // wallpapers fit it exactly.
  readonly property int wallpaperWidth: 800
  readonly property int wallpaperHeight: 232
  readonly property int wallpaperRadius: 26
  readonly property int wallpaperInset: 24
  readonly property int wallpaperTitleSize: 18
  readonly property int wallpaperMetaSize: 12
  readonly property int wallpaperTitleTop: 28
  readonly property int wallpaperMetaTop: 32
  readonly property int wallpaperFooterTop: 196

  // The row is a carousel, not a grid: it is clipped by the panel and runs on
  // past both edges when there are more wallpapers than fit.
  readonly property int wallpaperRowMid: 130
  readonly property int wallpaperTileGap: 16
  readonly property int wallpaperTileRadius: 10

  // The chosen wallpaper is drawn larger and every other one the same, so the
  // row has one focus rather than a gradient of importance. The board ramps
  // through a middle size either side of the selection; a ramp says a tile two
  // along matters less than its neighbour, which is not true of a row you are
  // stepping through one at a time. The source does not size its previews at
  // all - only the ring says which is chosen there.
  //
  // The first is the selected width; the last is everything else. Four
  // wallpapers at these two sizes come to 720, which is inside the 752 the
  // panel has, so the row is centred and nothing is clipped until there are
  // five.
  readonly property var wallpaperTileWidths: [192, 160]

  // 16:9, as the board draws them. Previews are cropped to it rather than
  // letterboxed, so a tile is never part panel background.
  readonly property real wallpaperTileAspect: 16 / 9

  readonly property real wallpaperTileBorderAlpha: 0.7
  readonly property int wallpaperSelectedBorder: 2

  // Two things are true of a tile at once and the row has to say both: which
  // wallpaper the keys are on, and which one is actually up. The ring and the
  // size carry the first. The second is the accent border below, held well
  // under the ring's weight so a tile that is merely active never competes
  // with the one being chosen.
  readonly property real wallpaperActiveBorderAlpha: 0.55

  // The dot sits on a disc of base, because the corner it lands in belongs to
  // the picture and a bare accent dot is lost in a pale one.
  readonly property int wallpaperDotSize: 7
  readonly property int wallpaperDotInset: 8
  readonly property int wallpaperDotHalo: 14
  readonly property real wallpaperDotHaloAlpha: 0.7

  // The screen recorder's picker. Board 08, and the island's sixth shape.
  //
  // The capture row is the power menu's own tile grid, to the pixel: same 90
  // by 80 tile, same 16 px radius, same 12 px gap, same 11 px side inset. Two
  // surfaces that ask "which of these three" should not ask it in two
  // different shapes. The toggle rows below are this card's own.
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

  // The recording mark the pill carries. Board 09: love rather than the
  // accent, because it is the one thing in the bar that says something is
  // being captured, and it must not read as one more thing that is merely on.
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

  // Seven columns on a 68 px pitch, six rows on 46. The day number is drawn at
  // the row top and the marker centres on it; the event dot hangs below.
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

  // The lock screen, and its second transcription. The first one came off the
  // board; this one comes off the source recording itself (10:33-10:43 of
  // saneAspect's "It's done. Everything's using Quickshell now."), measured
  // per-pixel off the frames at native 1080p. The recording's lock carries no
  // accent colour anywhere: the ground is a neutral black veil over the blur,
  // and every surface on it is white translucency under warm-white type. The
  // numbers below are the recording's own glyph and pill boxes, with the
  // item-top y each one needs so its glyphs land where the frames put them -
  // the clock's, for instance, at 144 so its digits span 180 to 285.
  //
  // The board still settles the motion (the cross-fades, the staggers and the
  // spring are its), and the board's blur radius stays: the recording's own
  // radius is not separable from its compression.
  readonly property int lockDateTop: 125
  readonly property int lockDateSize: 22
  readonly property int lockClockTop: 144
  readonly property int lockClockSize: 146

  readonly property int lockAvatarTop: 836
  readonly property int lockAvatarSize: 58
  readonly property int lockAvatarGlyphSize: 24
  readonly property int lockUserTop: 915
  readonly property int lockUserSize: 18

  readonly property int lockFieldTop: 956
  readonly property int lockFieldWidth: 200
  readonly property int lockFieldHeight: 32
  readonly property int lockFieldRadius: 16
  // The field starts hidden. The recording shows no pill until the first
  // keystroke - a centred hint floats where the field will be - and the pill
  // then fades in around the first dot.
  readonly property int lockFieldReveal: 100
  // The caret rides the dot row: 16 in from the field edge, where the first
  // dot starts, and the state text follows it 7 further in.
  readonly property int lockDotInset: 16
  readonly property int lockCaretWidth: 2
  readonly property int lockCaretHeight: 14
  readonly property int lockTextInset: 23
  readonly property int lockFieldTextSize: 14

  // The dots are the recording's: 8 px on a 12 px pitch, white, popping in
  // without overshoot in about 80 ms.
  readonly property int lockDotSize: 8
  readonly property int lockDotGap: 4
  readonly property int lockDotPop: 80

  // The now-playing line the recording does not draw. Kept from the surface
  // this replaces, in the recording's own type, below the login cluster.
  readonly property int lockNowPlayingBottom: 50
  readonly property int lockNowPlayingSize: 14

  // The ground's veil and the lock's neutrals, sampled off the recording.
  // The veil is a flat black at 22.5 per cent - patch-averaged per channel
  // across the mid-frame, where the blur's edge bleed cannot reach - and the
  // type is warm white, each colour the core average of its glyphs.
  readonly property color lockVeilColor: "#000000"
  readonly property real lockVeilOpacity: 0.225
  readonly property color lockTextPrimary: "#f0ebe8"
  readonly property color lockTextSecondary: "#ddd7d3"
  readonly property color lockFieldState: "#d1cccb"
  readonly property color lockFieldHint: "#a9a4a0"
  readonly property color lockCaretColor: "#c2bdbd"
  readonly property real lockFieldFill: 0.27
  readonly property real lockFieldStroke: 0.1
  readonly property real lockAvatarFill: 0.2
  readonly property real lockAvatarStroke: 0.5
  readonly property real lockStrokeWidth: 1.5
  readonly property int lockBlurMax: 28

  // The pill's shut width. Board 09 draws all four combinations.
  //
  // The widths are the design's and are not derived: the pill grows for a
  // player and grows again for a recording. What the extras do not do is move
  // the clock. It is centred in whichever of these widths is in play, and the
  // equaliser and the dot sit in the padding either side of it - so that
  // padding is not always equal, and the clock never moves, which is the trade
  // worth making for the one element on the bar the eye returns to.
  function islandCollapsedWidth(media, recording) {
    return (media ? islandPlayingWidth : islandIdleWidth) + (recording ? recorderDotSize + recorderDotGap : 0);
  }

  readonly property int barPillPadding: 12
  // Character limits alone do not constrain wide glyphs.
  readonly property int barMprisMaxWidth: 320

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
  // The control centre's own open, re-fitted frame by frame at 60 fps against
  // the source recording at 6:20 (the Alt+A open): the width track fits a
  // critically damped spring at w = 20.2 and the height track at w = 19.4, a
  // shared morphCurve duration of 318 and 336 ms. The old 295 ran ahead of the
  // source by about two frames in the middle third, where the eye tracks the
  // edge.
  readonly property int morphControl: 325
  readonly property int morphSubView: 311
  // The wallpaper picker's own open, fitted frame by frame at 60 fps against
  // the source recording at 4:00. Its width and its height ride one curve: the
  // two tracks agree on their progress at every sample to within 1.5% of their
  // travel, and the fit to the shared morphCurve lands within 3.5%.
  //
  // The source overshoots. It runs 7 px past its resting width on each side
  // about 230 ms in and takes another 130 ms to come back, which is 1.6% of
  // the travel - a spring at about zeta 0.8 rather than the critically damped
  // one every other surface here uses. It is not reproduced: one bouncing
  // surface among five that arrive and stop reads as a fault rather than as a
  // flourish. This is the fit to the rise, which is the part the eye follows.
  readonly property int morphWallpaper: 228
  // The OSD's own open, re-fitted at 60 fps against the source recording's
  // volume morph at 2:49. The travel fits a spring at w = 26.6, a morphCurve
  // duration of 246 ms - the OSD is measurably snappier than the panels, and
  // holding it on the panel clock reads as lag on a surface that answers a
  // key press. The melt back into the clock fits the panel spring (w = 21.2,
  // 308 ms) but on a 157 px travel the difference is under two frames, so one
  // duration carries both directions.
  readonly property int morphOsd: 250
  // The island's own hover expand, re-fitted at 60 fps against the source
  // recording at 1:33: w = 28.4, a morphCurve duration of 234 ms. Like the
  // OSD this is a reflex surface - the pointer is already on it when it moves
  // - and the panel clock read as a sluggish card.
  readonly property int morphIsland: 240
  readonly property int morphToggle: 269
  readonly property int morphSlider: 249

  // Content swaps are not morphs. Measured off the source recording at 60 fps,
  // a surface takes about 300 ms to change shape while the contents it carries
  // change over about five frames. Fading the contents on the geometry's clock
  // reads as a dissolve; this is what makes it read as a reveal instead.
  readonly property int morphContent: 80

  // The clock's digit roll. Measured at 60 fps off the source recording at
  // 1:37, where 21:48 rolls to 21:49: the outgoing digit leaves upward and
  // the incoming one rises from below, each travelling about half a glyph's
  // height, and the two cross-fade as they go - the pair's total ink dips
  // mid-roll because the outgoing fade runs on the content clock while the
  // incoming one trails it on the fast one. As a fraction of the font's own
  // size, so the roll reads the same at the pill's size and the card's.
  readonly property real clockRollTravel: 0.45

  // How long a surface that has just handed the island over keeps riding the
  // taker's morph before it is taken down. The surface taking over maps in
  // single-digit milliseconds but its first rendered frame lands 147-216 ms
  // later (probed for the pill-blink fix), and the handover has no cut to
  // hide that: without the hold, the bare pill shows through the gap. The
  // holder's still rides the taker's own curve - same shape, target, duration
  // and start frame - so it is covered from the taker's first presented frame
  // on, and the hold only has to outlive the travel plus a margin; 260 covers
  // the measured first-frame latency with room to spare.
  readonly property int morphHold: 240

  // The lock screen's two cross-fades, fitted frame by frame at 60 fps against
  // the source recording between 10:33 and 10:42. Neither is a morph: stepping
  // the clock block frame by frame, the digits never move and never change
  // size, so neither direction uses the spring.
  //
  // One progress value drives all of it. The blur radius and the dim veil ride
  // the same curve over the same window - board 15 records the blur as a
  // single-frame step, and it is not one. Raw gradient energy does collapse in
  // one frame, but only because the veil is crushing the image's contrast at
  // the same time. Measured as sharpness over contrast, which the veil cannot
  // touch, the radius tracks the veil to within 0.02 of its travel at every
  // sample, in both directions.
  readonly property int lockIn: 350
  // The source runs a longer ramp out and then destroys its surface partway
  // through it, so its last frame jumps the remaining eight per cent. This is
  // the fit to the part the eye follows, closed so nothing snaps.
  readonly property int lockOut: 270

  // The content lags the ground going in and leads it coming out, which is
  // what lets the island pill read as returning partway through the unlock
  // rather than arriving after it. The clock is the extreme at both ends: it
  // is the last thing in and the last thing out.
  //
  // The date and the avatar land between the two tiers and swap places
  // between the two directions, so which tier each belongs to is inside the
  // measurement's noise. They are grouped by what they are instead.
  readonly property int lockInClock: 70
  readonly property int lockInLogin: 100
  readonly property int lockInContent: 280
  readonly property int lockOutClock: 20
  readonly property int lockOutContent: 180

  // Qt has no critically damped spring: SpringAnimation takes its own damping
  // scale rather than a stiffness, a mass and a damping coefficient. So the
  // real step response of a zeta = 1 system, y = 1 - (1 + wt)e^-wt, is fitted
  // here as a cubic bezier instead. The fit tracks that curve to within 0.02
  // across its whole range and, like it, both leaves and arrives at zero
  // velocity.
  readonly property var morphCurve: [0.12, 0.0, 0.22, 1.0, 1.0, 1.0]
}
