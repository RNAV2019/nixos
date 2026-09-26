pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  // The palettes, keyed by the theme id `theme-switch` takes; they mirror
  // home/themes/palettes.nix. The other themes reuse the Rose Pine role names.
  readonly property var palettes: ({
      "rose-pine": {
        label: "Rosé Pine",
        paletteName: "rose-pine",
        base: "#191724",
        surface: "#1f1d2e",
        overlay: "#26233a",
        // Rose Pine's muted #6e6a86 is only 3.2:1 against the panel tint, and carries almost
        // every 11 px label; lifted towards `subtle` to read 4.7:1 on the darkest ground.
        muted: "#8a86a4",
        subtle: "#908caa",
        text: "#e0def4",
        love: "#eb6f92",
        gold: "#f6c177",
        rose: "#ebbcba",
        pine: "#31748f",
        foam: "#9ccfd8",
        iris: "#c4a7e7",
        highlightLow: "#21202e",
        highlightMed: "#403d52",
        highlightHigh: "#524f67",
        accent: "#c4a7e7"
      },
      "dark": {
        label: "Dark",
        paletteName: "ascii-world",
        base: "#0b0b0b",
        surface: "#141414",
        overlay: "#1f1f1f",
        muted: "#8c8c8c",
        subtle: "#a6a6a6",
        text: "#ffffff",
        love: "#ff5c5c",
        gold: "#ffd166",
        rose: "#ffb3b3",
        pine: "#8c8c8c",
        foam: "#d6d6d6",
        iris: "#ffffff",
        highlightLow: "#181818",
        highlightMed: "#303030",
        highlightHigh: "#3f3f3f",
        accent: "#ffffff"
      },
      "ariadne": {
        label: "Ariadne",
        paletteName: "ariadne",
        base: "#002018",
        surface: "#0a0a0a",
        overlay: "#1e1c1a",
        muted: "#707e78",
        subtle: "#8a8a86",
        text: "#e6e4de",
        love: "#e0563b",
        gold: "#d99f66",
        rose: "#d8a8bc",
        pine: "#8c94a9",
        foam: "#7cc4c0",
        iris: "#3eddb8",
        highlightLow: "#141311",
        highlightMed: "#2e4c45",
        highlightHigh: "#3a5a50",
        accent: "#3eddb8"
      }
    })

  // In the order the theme picker shows them.
  readonly property var themeIds: ["rose-pine", "dark", "ariadne"]

  // Which theme is up. `theme-switch` writes the id into this watched file, so a switch
  // recolours in place: Tint colours cross-fade, the rest change on the next frame.
  property string name: "rose-pine"
  readonly property var palette: palettes[name] !== undefined ? palettes[name] : palettes["rose-pine"]

  FileView {
    id: nameFile

    path: Quickshell.env("HOME") + "/.local/state/theme/name"
    watchChanges: true
    printErrors: false

    // Written in place, so an empty read is the gap between truncate and write, not a theme.
    onFileChanged: nameFile.reload()
    onLoaded: {
      var id = nameFile.text().trim();
      if (id !== "" && root.palettes[id] !== undefined)
        root.name = id;
    }
  }

  // A file absent at shell start is not watched, so the switch also asks for an IPC read
  // (`qs ipc call theme sync`).
  function reload() {
    nameFile.reload();
  }

  readonly property color base: palette.base
  readonly property color surface: palette.surface
  readonly property color overlay: palette.overlay
  readonly property color muted: palette.muted
  readonly property color subtle: palette.subtle
  readonly property color text: palette.text
  readonly property color love: palette.love
  readonly property color gold: palette.gold
  readonly property color rose: palette.rose
  readonly property color pine: palette.pine
  readonly property color foam: palette.foam
  readonly property color iris: palette.iris
  readonly property color highlightLow: palette.highlightLow
  readonly property color highlightMed: palette.highlightMed
  readonly property color highlightHigh: palette.highlightHigh

  // Semantic roles, the same in both themes; kept separate from source names, since `base`
  // is the canvas while `inkOnAccent` is the ink on a selected control.
  readonly property color canvas: base
  readonly property color surfaceRaised: overlay
  readonly property color surfaceSubtle: highlightLow
  readonly property color separator: highlightMed
  readonly property color inkPrimary: text
  readonly property color inkSecondary: subtle
  readonly property color inkTertiary: muted
  readonly property color accentFill: accent
  readonly property color inkOnAccent: base
  readonly property color dangerFill: urgent
  readonly property color inkOnDanger: base
  readonly property color focusRing: accent
  readonly property color disabledInk: withAlpha(inkSecondary, 0.45)
  readonly property color surfaceOutline: Qt.rgba(1, 1, 1, 0.10)
  readonly property color surfaceShadow: Qt.rgba(0, 0, 0, 0.24)

  // The palette every colour above comes from, for the surfaces that name it.
  readonly property string paletteName: palette.paletteName

  readonly property color accent: palette.accent
  readonly property color urgent: love

  readonly property real fillNormal: 0.04
  readonly property real fillSelected: 0.18
  readonly property real fillPressed: 0.22
  readonly property real borderNormal: 0.4
  readonly property real borderSelected: 1.0

  // Press feedback and slider stepping, shared by the interactive controls.
  readonly property real pressScale: 0.97
  readonly property real sliderStep: 0.05

  function withAlpha(c, a) {
    return Qt.rgba(c.r, c.g, c.b, a);
  }

  function clamp01(x) {
    return Math.max(0, Math.min(1, x));
  }

  // A stable colour per name, for the services that pick one per calendar or app: hash the
  // characters, then index the five accent roles, so the order events arrive never matters.
  function stableAccent(name) {
    var palette = [foam, iris, gold, rose, pine];
    if (!name)
      return palette[0];
    var h = 0;
    for (var i = 0; i < name.length; i++)
      h = (h * 31 + name.charCodeAt(i)) % 997;
    return palette[h % palette.length];
  }

  // The Nerd Font carries icons and holds digits on a fixed advance, so it stays for icons,
  // identifiers and live readouts; prose and labels use a proportional face.
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
  readonly property int panelSideMargin: 24

  function panelWidth(screen, desired) {
    if (!screen || screen.width <= 0)
      return desired;
    return Math.min(desired, Math.max(280, screen.width - panelSideMargin * 2));
  }

  // Panel surfaces are solid, so shell UI does not depend on the desktop for contrast. Lower
  // surfaces hide during handoff; MultiEffect blur is a fraction of blurMax, not a pixel radius.
  readonly property int surfaceBlurMax: 64
  readonly property real surfaceBlur: 0.53
  readonly property int surfaceShadowOffset: 6
  readonly property int surfaceShadowMax: 32
  readonly property real surfaceShadowBlur: 0.75
  readonly property real surfaceShadowAlpha: 0.24

  // Set QUICKSHELL_REDUCE_MOTION=1 for a short, non-overshooting presentation; an
  // environment switch, not a theme, so it applies to both.
  readonly property bool reduceMotion: Quickshell.env("QUICKSHELL_REDUCE_MOTION") === "1"

  function duration(ms) {
    return reduceMotion ? Math.min(80, Math.round(ms * 0.25)) : ms;
  }

  // SpringAnimation's damping is a Qt friction value, not a normalized ratio. Kept in one
  // place and tuned against a 60 fps surface trace.
  readonly property real surfaceSpring: 5.0
  readonly property real surfaceDamping: 0.65
  readonly property real surfaceMass: 1.0
  readonly property real surfaceEpsilon: 0.5
  readonly property real microSpring: 5.0
  readonly property real microDamping: 0.6
  readonly property real microMass: 0.8
  readonly property real microEpsilon: 0.005

  // Every panel grows from the same column width and corner radius; the per-surface tokens
  // below alias these so each keeps its own name. (The `panelWidth(screen, desired)` clamp
  // above takes the width token as its `desired`.)
  readonly property int panelColumnWidth: 520
  readonly property int panelRadius: 26

  // The island: one pill carrying the clock, growing an equaliser while playing and
  // expanding into a media and status card on hover.
  readonly property int islandRadius: 18
  readonly property int islandIdleWidth: 118
  readonly property int islandPlayingWidth: 140
  readonly property int islandExpandedWidth: panelColumnWidth
  readonly property int islandExpandedHeight: 84
  readonly property int islandExpandedRadius: panelRadius
  readonly property int islandClockSize: 17
  readonly property int islandDisplaySize: 22
  readonly property int islandTitleSize: 13
  readonly property int islandCaptionSize: 11
  readonly property int islandArtSize: 48
  readonly property int islandArtRadius: 10
  readonly property int islandHoverOpenDelay: 70
  readonly property int islandHoverCloseDelay: 120

  // The mini calendar the expanded card carries while nothing plays: five days centred on
  // today on a 32 px pitch; the plate is 1.14 pitches wide, for the three-letter label.
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

  // The app launcher, which the island pill grows into, sharing a top edge and centre line.
  // A 68 px search row, then rows on a 45 px pitch, each 42 px tall with a 3 px gap.
  readonly property int launcherWidth: panelColumnWidth
  readonly property int launcherRadius: panelRadius
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

  // The notification toast: the pill grows into one card, holds while read, then melts back.
  // One card, not a stack; a second notification replaces the first.
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
  readonly property int notifActionGapAbove: 10
  readonly property int notifActionHeight: 30
  readonly property int notifActionRadius: 15
  readonly property int notifActionGap: 10
  readonly property int notifActionPad: 16
  readonly property int notifActionSize: 12
  readonly property real notifActionSecondaryAlpha: 0.85
  readonly property int notifPadBottom: 14

  // The power menu: three tiles on one row. Lock acts on first press; the two that end the
  // session arm first, turning love and relabelling Confirm.
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

  // The on-screen displays: the pill widens in place into a glyph, a bar and a reading, holds,
  // then melts back. Fixed positions in a fixed-width pill, so growth uncovers placed contents.
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
  // two sliders, the media card and notifications. Source frames: 520 x 716 at 1920 px.
  readonly property int controlWidth: panelColumnWidth
  readonly property int controlRadius: panelRadius
  readonly property int controlInset: 13
  readonly property int controlHeaderHeight: 70
  readonly property int controlTitleSize: 18
  readonly property int controlBackSize: 36
  readonly property int controlBackLeft: 20

  // Tiles: two rows on a 71 px pitch, each 59 px tall with a 12 px gutter; row one is a
  // narrow beside a wide tile, row two three equal.
  readonly property int controlTileHeight: 59
  readonly property int controlTileGap: 12
  readonly property int controlTileRadius: 29
  readonly property int controlTileBadge: 34
  readonly property int controlTileBadgeLeft: 10
  readonly property int controlTileGlyphSize: 18
  // Unlit parts of a drawn glyph (a Wi-Fi bar below the signal): half ink, which still reads
  // against a tile badge's tint where a third of it faded into the circle.
  readonly property real controlGlyphDimAlpha: 0.5
  readonly property int controlTileTextLeft: 54
  readonly property int controlTileLabelSize: 13
  readonly property int controlTileSubSize: 11

  // Sliders. Thick pills whose fill is the level, with the glyph riding inside the fill.
  readonly property int controlSliderHeight: 40
  readonly property int controlSliderGap: 17
  readonly property int controlSliderGlyphLeft: 13

  // The media card; the gap separates each block from the next.
  readonly property int controlBlockGap: 15
  readonly property int controlMediaHeight: 140
  readonly property int controlMediaRadius: 16
  readonly property int controlMediaTitleSize: 19
  readonly property int controlMediaArtistSize: 12
  readonly property int controlMediaCaptionSize: 11
  readonly property int controlMediaPlaySize: 52
  readonly property int controlMediaSkipSize: 16
  readonly property real controlMediaProgressHeight: 3

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
  // Past this the list scrolls rather than the panel growing further: about two cards, so the
  // panel tops out near 58% of a 1350 px screen rather than two-thirds.
  readonly property int controlNotifMaxHeight: 180

  // Sub-views. A 46 px pill on a 52 px pitch, under an 11 px section label.
  readonly property int controlRowHeight: 46
  readonly property int controlRowGap: 6
  readonly property int controlRowRadius: 23
  readonly property int controlRowInset: 16
  readonly property int controlViewMaxHeight: 620

  // The wallpaper picker: the pill grows into a wide, short card with one row of previews.
  // The column is 800, not the source's 1008, fitting four wallpapers exactly.
  readonly property int wallpaperWidth: 800
  readonly property int wallpaperHeight: 232
  readonly property int wallpaperRadius: panelRadius
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
  // focus. First is the selected width, last everything else; four come to 720 inside 752.
  readonly property var wallpaperTileWidths: [192, 160]

  // 16:9, as the board draws them; previews are cropped rather than letterboxed, so a tile
  // is never part panel background.
  readonly property real wallpaperTileAspect: 16 / 9

  readonly property real wallpaperTileBorderAlpha: 0.7
  readonly property int wallpaperSelectedBorder: 2

  // The keys' wallpaper is carried by the ring and size; the one that is up is the accent
  // border, held well under the ring's weight.
  readonly property real wallpaperActiveBorderAlpha: 0.55

  // The dot sits on a disc of base, because a bare accent dot is lost in a pale corner.
  readonly property int wallpaperDotSize: 7
  readonly property int wallpaperDotInset: 8
  readonly property int wallpaperDotHalo: 14
  readonly property real wallpaperDotHaloAlpha: 0.7

  // The theme picker is the wallpaper picker's card and row. Each tile is that theme's own
  // wallpaper with a pill carrying five dots in its colours, ringed in its highlightHigh.
  readonly property int themePillHeight: 18
  readonly property int themePillInset: 10
  readonly property int themeSwatchSize: 8
  readonly property int themeSwatchGap: 5
  readonly property int themeSwatchPad: 7
  readonly property var themeSwatchRoles: ["base", "surface", "text", "accent", "love"]

  // The screen recorder's picker. The capture row is the power menu's tile grid to the pixel,
  // so its tile constants alias the power ones; the toggle rows below are this card's own.
  readonly property int recorderWidth: 316
  // Four rows under the capture tiles: three toggles plus the frame-rate row.
  readonly property int recorderHeight: 264
  readonly property int recorderRadius: panelRadius
  readonly property int recorderInset: 11
  readonly property int recorderTileTop: powerTileTop
  readonly property int recorderTileWidth: powerTileWidth
  readonly property int recorderTileHeight: powerTileHeight
  readonly property int recorderTileGap: powerTileGap
  readonly property int recorderTileRadius: powerTileRadius
  readonly property int recorderGlyphSize: powerGlyphSize
  readonly property int recorderGlyphTop: powerGlyphTop
  readonly property int recorderTileLabelTop: powerLabelTop
  readonly property int recorderTileLabelSize: powerLabelSize

  readonly property int recorderRowsTop: 108
  readonly property int recorderRowHeight: 32
  readonly property int recorderRowGap: 4
  readonly property int recorderRowRadius: 16
  readonly property int recorderRowTextLeft: 12
  readonly property int recorderRowLabelSize: 12

  // The frame-rate row is the toggle rows' shape with three small pills at the right where
  // a switch would sit; 120 is only live on an output that can carry it.
  readonly property int recorderFpsSegmentWidth: 46
  readonly property int recorderFpsSegmentHeight: 22
  readonly property int recorderFpsSegmentGap: 4

  // The recording mark the pill carries: love rather than the accent, so it does not read as
  // one more thing merely on.
  readonly property int recorderDotSize: 8
  readonly property int recorderDotGap: 10

  // The calendar. Board 14: a month grid over an agenda for the chosen day.
  readonly property int calWidth: panelColumnWidth
  readonly property int calHeight: 600
  readonly property int calRadius: panelRadius
  readonly property int calInset: 24
  readonly property int calTitleSize: 18
  readonly property int calNavSize: 30
  readonly property int calNavTop: 24
  readonly property int calNavGap: 6
  readonly property int calNavGlyphSize: 15
  readonly property int calTodayBtnHeight: 28
  readonly property real calTodayBtnSize: 11.5

  // Seven columns on a 68 px pitch, six rows on 46; calGridTop is the first row's top, not a
  // baseline. Day centres in its cell, marker on the number, dot under it inside the marker.
  readonly property int calWeekdayTop: 76
  readonly property int calWeekdaySize: 11
  readonly property int calGridTop: 102
  readonly property int calColumnPitch: 68
  readonly property int calRowPitch: 46
  readonly property int calColumnFirst: 56
  readonly property int calDaySize: 13
  readonly property int calTodayMarker: 34
  readonly property int calDotSize: 5
  readonly property int calDotDrop: 12

  // The last grid row ends at 372, so the rule clears it by 20. Below it is a fixed block:
  // room is reserved for calAgendaMax rows regardless, letting calHeight stay constant.
  readonly property int calDividerTop: 392
  readonly property int calSectionTop: 406
  readonly property real calSectionSize: 11.5
  readonly property int calAgendaTop: 430
  readonly property int calAgendaHeight: 38
  readonly property int calAgendaGap: 4
  readonly property int calAgendaRadius: 12
  readonly property int calSpineLeft: 12
  readonly property int calSpineWidth: 3
  readonly property int calSpineHeight: 20
  readonly property int calTimeLeft: 26
  readonly property real calTimeSize: 11.5
  readonly property int calTitleLeft: 86
  readonly property real calEventTitleSize: 12.5
  readonly property real calMetaSize: 11
  readonly property int calAgendaMax: 3
  readonly property int calAgendaBlock: calAgendaMax * calAgendaHeight + (calAgendaMax - 1) * calAgendaGap

  // Board 13: a 1920x1080 lock surface. The surface paints its own background, so the
  // session-lock protocol never exposes a black frame.
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
  // The caret blink on the field, at the standard text-caret period.
  readonly property int lockCaretBlinkMs: 530

  // The veil comes from the captured desktop, not the compositor backdrop, and tints the
  // blurred capture rather than covering it; at 1.0 the background reads as one flat fill.
  readonly property color lockVeilColor: surface
  readonly property real lockVeilOpacity: 0.55
  readonly property color lockTextPrimary: inkPrimary
  readonly property color lockTextSecondary: inkSecondary
  readonly property color lockFieldState: inkPrimary
  readonly property color lockFieldHint: inkTertiary
  readonly property color lockCaretColor: focusRing
  readonly property real lockFieldFill: 0.8
  readonly property real lockFieldStroke: 0.55
  readonly property real lockAvatarFill: 0.85
  readonly property real lockAvatarStroke: 0.5
  readonly property real lockStrokeWidth: 1.5
  readonly property int lockBlurMax: surfaceBlurMax
  readonly property real lockBlur: surfaceBlur
  readonly property int lockIn: 350
  readonly property int lockOut: 350

  // The pill's shut width, one per combination: it grows for a player and again for a
  // recording, but neither moves the clock, which stays centred in the current width.
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

  // Every morph rides one curve for one duration, settled by a survey of ten 1440p60
  // recordings: 186 found, 176 fitted; measured quartiles 36/68/104/148 ms, fit 33/64/103/143.
  readonly property int morphSurface: reduceMotion ? 1 : 190

  // A control changing state rather than shape: a toggle, a slider, a hover or a press.
  readonly property int morphState: reduceMotion ? 1 : 115

  // Content swaps are not morphs. A surface takes ~300 ms to change shape while its contents
  // change over ~five frames, so fading on the geometry's clock would read as a dissolve.
  readonly property int morphContent: reduceMotion ? 1 : 50

  // The outgoing contents dissolve inside the still, short so it finishes before the taker lands.
  readonly property int morphFarewell: reduceMotion ? 1 : 70

  // The still's ground outlives its contents, covering the gap before the taker presents.
  // The taker may land in 147-216 ms, so the fade spans that window; no stacked tint or blink.
  readonly property int morphGround: reduceMotion ? 1 : 70
  readonly property int morphGroundFade: reduceMotion ? 1 : 60

  // The incoming contents wait, then fade, landing just before the shape settles.
  readonly property int morphEnterDelay: reduceMotion ? 0 : 45
  readonly property int morphEnter: reduceMotion ? 1 : 90

  // They settle through a few pixels in the direction the height travels, so a switch between
  // two same-width columns has an axis to read.
  readonly property real morphEnterTravel: 10

  // The clock's digit roll, measured at 60 fps: each digit travels about half a glyph's height
  // and cross-fades; a fraction of font size, so it reads the same at pill and card size.
  readonly property real clockRollTravel: 0.45

  // Its own clock rather than a content swap's five frames, so the roll reads as travel; the
  // arriving digit's fade trails the move, dipping the pair's ink mid-roll.
  readonly property int clockRoll: reduceMotion ? 1 : 110
  readonly property int clockRollFade: reduceMotion ? 1 : 170

  // How long a surface that just handed the island over keeps riding the taker's morph: the
  // taker's first frame lands 147-216 ms later, and 260 covers the bare pill showing through.
  readonly property int morphHold: 240

  // Motion and interaction tokens for things wired across surfaces; each stays literal so
  // callers can wrap it in `duration()` themselves.
  // The buffer after the hold still, used by IslandOrigin's holdTimer.
  readonly property int morphHoldBuffer: 260
  // Short value-fill tween, e.g. the OSD bar filling to the new level.
  readonly property int morphFill: 80
  // A small pause beat in sequences, e.g. LockReveal.
  readonly property int morphBeat: 50
  // The wait after a panel closes and before its chosen action runs, so the pill is back
  // to its resting shape first (session, profiles, recorder launches).
  readonly property int actionSettleDelay: reduceMotion ? 0 : 500

  // The island's equaliser: each bar rises on its own tween, then falls, staggered across
  // the row so the set waves rather than jumps.
  readonly property int eqRiseBase: 320
  readonly property int eqRiseStagger: 60
  readonly property int eqFallBase: 400
  readonly property int eqFallStagger: 50

  // The island's small round gauge (a reading like battery or volume) and where its label sits.
  readonly property int islandGaugeSize: 48
  readonly property int islandGaugeHeight: 52
  readonly property int islandGaugeRadius: 21
  readonly property int islandGaugeLabelY: 38

  // The lock screen's two cross-fades, fitted frame by frame at 60 fps; neither is a morph.
  // One progress drives blur and veil (tracking within 0.02); content lags in and leads out.
  readonly property int lockInClock: 70
  readonly property int lockInLogin: 100
  readonly property int lockInContent: 280
  readonly property int lockOutClock: 20
  readonly property int lockOutContent: 180

  // Fallback curve for direct NumberAnimations not yet on a spring. Never overshoots;
  // geometry uses SurfaceSpring and colour uses Tint.
  readonly property var morphCurve: [0.22, 0.61, 0.36, 1.0]
}
