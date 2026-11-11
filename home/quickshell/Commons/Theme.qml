pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  // The palettes, keyed by the theme id `theme-switch` takes, in the order the theme picker
  // shows them. palettes.json is the one source: home/themes/palettes.nix reads the same file
  // for every other program, and this one is read live, so an edit recolours without a rebuild.
  FileView {
    id: paletteFile

    path: Quickshell.shellPath("Commons/palettes.json")
    blockLoading: true
    watchChanges: true

    onFileChanged: paletteFile.reload()
  }

  readonly property var palettes: {
    try {
      return JSON.parse(paletteFile.text());
    } catch (e) {
      console.warn("Theme: palettes.json unreadable:", e);
      return {};
    }
  }

  readonly property var themeIds: Object.keys(palettes)

  // Drawn only if palettes.json cannot be read, so every colour binding still resolves.
  readonly property var fallbackPalette: ({
      label: "Fallback",
      paletteName: "fallback",
      base: "#000000",
      surface: "#111111",
      overlay: "#222222",
      muted: "#888888",
      subtle: "#aaaaaa",
      text: "#ffffff",
      love: "#ff5c5c",
      gold: "#ffd166",
      rose: "#ffb3b3",
      pine: "#888888",
      foam: "#cccccc",
      iris: "#ffffff",
      highlightLow: "#181818",
      highlightMed: "#303030",
      highlightHigh: "#3f3f3f",
      accent: "#ffffff"
    })

  // Which theme is up. `theme-switch` writes the id into this watched file, so a switch
  // recolours in place: Tint colours cross-fade, the rest change on the next frame.
  property string name: "ariadne"
  readonly property var palette: palettes[name] !== undefined ? palettes[name] : palettes[themeIds[0]] !== undefined ? palettes[themeIds[0]] : fallbackPalette

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
  readonly property color muted: palette.shellMuted !== undefined ? palette.shellMuted : palette.muted
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

  // The palette every colour above comes from, for the surfaces that name it.
  readonly property string paletteName: palette.paletteName

  readonly property color accent: palette.accent
  readonly property color urgent: love

  // Inner fills are white laid over the ground in steps (saneAspect's): a tile or grouped row,
  // its hover, a chosen row, a neutral control and its hover, an off switch, the hairline on a
  // tile's edge, a divider, and a level track. White rather than a palette colour, so a fill is
  // the same lift over any theme's ground.
  readonly property real liftTile: 0.05
  readonly property real liftHover: 0.08
  readonly property real liftSelected: 0.11
  readonly property real liftControl: 0.075
  readonly property real liftControlHover: 0.11
  readonly property real liftOff: 0.15
  readonly property real liftEdge: 0.10
  readonly property real liftDivider: 0.12
  readonly property real liftTrack: 0.10

  function lift(a) {
    return Qt.rgba(1, 1, 1, a);
  }

  readonly property real fillNormal: 0.04
  readonly property real fillSelected: 0.18
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

  // The mono face holds digits on a fixed advance, so it stays for identifiers and live
  // readouts; prose and labels use a proportional face.
  readonly property string fontFamily: "JetBrainsMono Nerd Font"
  readonly property string monoFont: fontFamily
  // Icons are Material Symbols Rounded, named by ligature (Commons/Icons.qml): a static
  // instance filled at weight 400 (pkgs/material-symbols-filled), so an icon Text keeps its
  // regular weight.
  readonly property string iconFont: "Material Symbols Rounded Filled"
  // SF Compact (pkgs/sf-compact), as static cuts: Text for UI sizes, Display for type big
  // enough that the Text cut looks loose.
  readonly property string uiFont: "SF Compact Text"
  readonly property string displayFont: "SF Compact Display"

  readonly property int weightRegular: Font.Normal
  readonly property int weightMedium: Font.Medium
  readonly property int weightSemi: Font.DemiBold
  readonly property int weightBold: Font.Bold

  readonly property int fontSize: 12
  readonly property int fontSizeLarge: 13

  // Every section heading (Ui/SectionLabel.qml) and the small labels set beside one.
  readonly property int sectionSize: 11

  // A panel's header (Ui/PanelHeader.qml): 70 px tall, its title and controls on the centre
  // line. Back buttons sit 20 in and pull the trailing controls to 18 from the right edge.
  readonly property int panelHeaderHeight: 70
  readonly property int panelTitleSize: 18
  readonly property int panelHeaderInset: 24
  readonly property int panelHeaderBackInset: 20
  readonly property int panelHeaderTrailInset: 18
  readonly property int panelHeaderGap: 8
  // Where a header's meta line sits on that centre line.
  readonly property int panelHeaderMetaTop: 28
  // And its footer, when the panel has one: the line near the foot of a 232 px card.
  readonly property int panelFooterTop: 196
  // Buttons (Ui/Button.qml). Neutral kinds are white lifts (liftControl, liftControlHover); the
  // danger disc rests at its own alpha and hovers to `groundHoverAlpha`; filled pills lift their
  // fill by `fillLift`.
  readonly property real groundHoverAlpha: 0.95
  readonly property real dangerRestAlpha: 0.8
  readonly property real fillLift: 1.06
  readonly property real washAlpha: 0.06
  readonly property real plainHoverAlpha: 0.2
  readonly property real tonalRestAlpha: 0.12
  readonly property real tonalHoverAlpha: 0.2
  readonly property real onAccentRestAlpha: 0.14
  readonly property real onAccentHoverAlpha: 0.24
  // A control that cannot be used is the same control at this opacity.
  readonly property real disabledAlpha: 0.4
  // Tiles and grouped rows are white lifts (liftTile, liftHover, liftEdge above). Filled tiles
  // lift their fill by `tileLift`, and a chosen tile darkens by `tileDim` while pressed.
  readonly property real tileLift: 1.08
  readonly property real tileDim: 1.12
  // A hairline row's corner and a list's label size, wherever the shell draws one.
  readonly property int rowRadius: 14
  readonly property real rowLabelSize: 12.5
  readonly property int pillHeightCompact: 26
  readonly property int pillHeightRegular: 30
  readonly property int pillHeightLarge: 44
  readonly property int pillPadCompact: 12
  readonly property int pillPadRegular: 14
  readonly property int pillPadLarge: 16
  readonly property int pillLabelCompact: 11
  readonly property int pillLabelRegular: 12
  readonly property int pillLabelLarge: 13
  readonly property int pillIconSize: 13
  readonly property int pillIconLarge: 16
  readonly property int pillIconGap: 6
  readonly property int pillIconGapLarge: 8
  readonly property int discCompact: 30
  readonly property int discRegular: 36
  readonly property int discLarge: 40
  readonly property int discGlyph: 16
  readonly property int discGlyphLarge: 18
  // The switch (Ui/Switch.qml).
  readonly property int switchWidth: 46
  readonly property int switchHeight: 26
  readonly property int switchKnob: 20
  readonly property int switchInset: 3
  // The text field (Ui/TextField.qml); the launcher's bare one takes its height from the type.
  readonly property int textFieldHeight: 30
  // The bare icon buttons' glyph.
  readonly property int headerIconSize: 16
  // The hairline between a panel's sections (Ui/Divider.qml).
  readonly property real dividerAlpha: 0.6

  readonly property int spacingLg: 12

  readonly property int panelRowInset: spacingLg
  readonly property int panelRowRadius: 8
  readonly property int panelRowHeight: 34

  readonly property int barHeight: 36
  // The island floats this far below the screen edge; windows start one gaps_out below the
  // pill. saneAspect's half-pill gap (16) sat too low; Ryan chose 10 on 2026-11-07.
  readonly property int barMarginTop: 10

  // OLED burn-in care (Services/OledCare.qml). The island pill and the workspaces pill never
  // move, so on the OLED panel they would print into it: every few minutes each takes the next
  // step of a slow orbit.
  readonly property int oledShiftInterval: 180000
  // Furthest a pill strays from its nominal spot on either axis, in logical px. The bar window
  // reaches this much above and below its pills so the offset never clips.
  readonly property int oledShiftMax: 2
  // A step is crossed this slowly so it is never seen to move.
  readonly property int oledShiftTravel: 12000
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

  // Surfaces float on a drop shadow rather than an outline (Ui/FrostedSurface.qml), measured off
  // saneAspect's 2026-11 recordings: the shape blurred by a Gaussian, neutral black, sigma about
  // two thirds of the pill's height and offset down about a quarter of it, the same on every
  // surface. His is about 0.68 strong; Ryan wanted it subtler (2026-11-07). `surfaceShadowRoom` is how far it reaches (offset plus about
  // 2.6 sigma); a window must leave that much free around a surface or the shadow is cut off.
  readonly property real surfaceShadowAlpha: 0.4
  readonly property real surfaceShadowSigma: 24
  readonly property real surfaceShadowOffsetY: 9
  readonly property int surfaceShadowRoom: 72

  // Set QUICKSHELL_REDUCE_MOTION=1 for a short, non-overshooting presentation; an
  // environment switch, not a theme, so it applies to both.
  readonly property bool reduceMotion: Quickshell.env("QUICKSHELL_REDUCE_MOTION") === "1"
  // QS_MOTION_LOG=1 makes labelled MorphSprings print a line per frame (see Ui/MorphSpring.qml).
  readonly property bool motionLog: Quickshell.env("QS_MOTION_LOG") === "1"

  function duration(ms) {
    return reduceMotion ? Math.min(80, Math.round(ms * 0.25)) : ms;
  }

  // The island morph's spring (Ui/MorphSpring.qml) at this natural frequency: quartiles about
  // 45/79/128/185 ms and within 1% by about 320 ms. Every shape that grows out of the island
  // rides this, at morphDamping below.
  readonly property real morphOmega: 21
  // Its damping ratio. 0.9 runs about 0.15% past the target and settles back, a hint of the
  // survey's 1.5% (zeta 0.8) without its visible bounce; Ryan chose it 2026-11-07 over the
  // critically damped 1 he had kept since 2026-10-18.
  readonly property real morphDamping: 0.9
  // The pace is by size (Ui/Motion.js pace): morphOmega is a pill's, and a shape with a long way to
  // go eases down to morphOmegaCalm (a full panel is within 1% by about 440 ms), so a panel has more
  // weight than a pill. Opening, the width runs morphWidthLead ahead of the height on a long move:
  // the shape widens, then drops. A close is morphCloseQuicken faster than the open it undoes and
  // critically damped, so nothing dips under the pill.
  readonly property real morphOmegaCalm: 15
  readonly property real morphWidthLead: 1.13
  readonly property real morphCloseQuicken: 1.22
  readonly property real morphCloseDamping: 1
  // Following the hand (Ui/SwipeAway.qml): a card dragged sideways is thrown away when it is let go
  // past swipeDismissAt of its width, or fast enough to coast there (Motion.thrown at a quick
  // throw's friction, swipeThrowRate: about 900 px/s from rest for a history row); short of that it
  // springs back. It fades as it goes and is clear by swipeFadeEnd of its width, which is when its
  // owner is told. The first swipeSlop px of a press move nothing, so a click stays a click.
  readonly property real swipeDismissAt: 0.4
  readonly property real swipeThrowRate: 0.994
  readonly property real swipeFadeEnd: 0.8
  readonly property int swipeSlop: 6

  // The small controls' pace (the switch knob). Chosen as the critically damped spring that reaches
  // 90% at about 249 ms (omega * t = 3.89 there, so omega = 3.89 / 0.249 s = 15.6); the springs that
  // take it inherit morphDamping 0.9, which gets there a little sooner, at about 219 ms.
  readonly property real microOmega: 15.6
  // A control going down under a press (Ui/ButtonBase.qml): quicker than microOmega, 90% of the way
  // to pressScale by about 122 ms, so a click is answered before it is over. Let go, it comes back
  // at pressReleaseOmega (90% by about 170 ms). Both at morphDamping; on a 3% scale its settle
  // cannot be seen. A release in the middle of a press turns round with the speed it had.
  readonly property real pressOmega: 28
  readonly property real pressReleaseOmega: 20
  // The switch knob and the segmented plate stretch as they travel: the edge in front rides a spring
  // this many times quicker than the edge behind (which keeps microOmega, so they arrive when they
  // always did), and the two meet again at rest. 1.55 makes the knob about a quarter wider at its
  // widest, around the middle of its travel; 1.25 makes the plate about an eighth of its travel longer.
  readonly property real switchLead: 1.55
  readonly property real segmentLead: 1.25
  // How far a held switch's knob leans toward the side a click would send it (px).
  readonly property real switchHeldWiden: 3
  // How much taller a slider's bar is while it is held (px), as the control-centre sliders of
  // macOS and iOS answer a press. The bar grows about its middle; nothing around it moves.
  readonly property real sliderPressGrow: 3
  // The keyboard ring's fade in and out, so a ring neither pops in nor trails the focus.
  readonly property int focusFade: reduceMotion ? 1 : 80

  // Every panel grows from the same column width and corner radius; the per-surface tokens
  // below alias these so each keeps its own name. (The `panelWidth(screen, desired)` clamp
  // above takes the width token as its `desired`.)
  readonly property int panelColumnWidth: 520
  // The radius equals the shut pill's height, as saneAspect's cards match his pill.
  readonly property int panelRadius: 36

  // The island: one pill carrying the clock, growing an equaliser while playing and
  // expanding into a media and status card on hover.
  readonly property int islandIdleWidth: 118
  // The shut pill's marks: the equaliser's width (four 2.5 px bars on 1.5 px gaps, see
  // Bar/Widgets/Equaliser.qml), the gap off the clock to the first mark on each side, the gap
  // between two marks, the idle pill's padding either side of the clock, and the least the
  // outermost mark keeps off the pill's end.
  readonly property real islandEqualiserWidth: 14.5
  readonly property int islandMarkClockGap: 12
  readonly property int islandMarkGap: 10
  readonly property int islandSideInset: 34
  readonly property int islandMarkInset: 18
  readonly property int islandExpandedWidth: panelColumnWidth
  readonly property int islandExpandedHeight: 84
  readonly property int islandExpandedRadius: panelRadius
  readonly property int islandClockSize: 17
  readonly property int islandDisplaySize: 22
  readonly property int islandTitleSize: 13
  readonly property int islandCaptionSize: 11
  readonly property int islandArtSize: 48
  readonly property int islandArtRadius: 8
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
  readonly property int islandCalPlateRadius: 14
  // Row centres, measured from the top of the block.
  readonly property real islandCalLabelMid: 10.5
  readonly property real islandCalDayMid: 27.5
  readonly property real islandCalWeekendLabelAlpha: 0.55
  readonly property real islandCalWeekendDayAlpha: 0.75
  readonly property real islandCalPlateAlpha: 0.08

  // The app launcher, which the island pill grows into, sharing a top edge and centre line.
  // A 68 px search row, then rows on a 45 px pitch, each 42 px tall with a 3 px gap, and no
  // section headings between providers: saneAspect's launcher has none.
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
  readonly property int launcherRowRadius: 8
  readonly property int launcherPadBottom: 14
  readonly property int launcherIconLeft: 27
  readonly property int launcherIconSize: 26
  readonly property int launcherIconRadius: 8
  readonly property int launcherTextLeft: 66
  readonly property int launcherNameSize: 14
  readonly property int launcherDescSize: 11
  // Past this the list scrolls rather than the panel growing further.
  readonly property int launcherMaxRows: 8
  // The selected row is a plain fill; no marker, no accent. The accent stays for the caret.
  readonly property real launcherSelectedAlpha: 0.10
  // The scope chip at the search row's right end: the provider's glyph and section in the
  // accent on a quiet pill, so the field keeps its search glyph and its text column.
  readonly property int launcherChipHeight: 28
  readonly property int launcherChipPad: 12
  readonly property int launcherChipGap: 6
  readonly property int launcherChipTextGap: 10
  readonly property int launcherChipSize: 13
  readonly property int launcherChipGlyphSize: 16
  readonly property real launcherChipAlpha: 0.08
  // An emoji row draws the character itself in colour, so its tile stays neutral.
  readonly property string emojiFont: "Noto Color Emoji"
  readonly property int launcherEmojiSize: 17
  readonly property color launcherEmojiTile: withAlpha(text, 0.08)

  // The notification toast: the pill grows into one card, holds while read, then melts back.
  // One card, not a stack; a second notification replaces the first.
  readonly property int notifWidth: 450
  readonly property int notifRadius: panelRadius
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
  readonly property int notifActionGap: 10
  readonly property int notifPadBottom: 14

  // Toasts waiting behind the card: back layers peeking under it, and a "+N" chip in the action row.
  readonly property int notifQueueInset: 14
  readonly property int notifQueuePeek: 8
  readonly property int notifQueueLayers: 2
  readonly property int notifChipWidth: 32
  readonly property int notifChipHeight: 22
  readonly property int notifChipSize: 11

  // The polkit authentication prompt is the login pill (lockPill*) with this after the name of
  // whoever is asking.
  readonly property string authLabelSuffix: " needs permission"

  // The power menu: three tiles on one row. Lock acts on first press; the two that end the
  // session arm first, turning love and relabelling Confirm.
  readonly property int powerHeight: 112
  readonly property int powerRadius: panelRadius
  readonly property int powerInset: 11
  readonly property int powerTileWidth: 90
  readonly property int powerTileHeight: 80
  readonly property int powerTileRadius: 14
  readonly property int powerTileGap: 12
  readonly property int powerTileTop: 16
  readonly property int powerGlyphTop: 38
  readonly property int powerGlyphSize: 22
  readonly property int powerLabelTop: 68
  readonly property int powerLabelSize: 12

  // The island pill row (Ui/IslandPill.qml): every pill that is a single 42 px line, in the
  // eight layouts of the board's `Island pill` set. Left edges and widths are in px from the
  // pill's left, `Inset`s from its right; the glyph slot is 18 x 18 except in the wide layout.
  readonly property int islandPillWidth: 278
  readonly property int islandPillWidthWide: 340
  // The pill hangs from barMarginTop and windows start barHeight + gaps_out below that, so a
  // 48 px row reached into the window under it; 42 leaves 2 px at the orbit low.
  readonly property int islandPillHeight: 42
  readonly property int islandPillRadius: 21
  readonly property int islandPillGlyphLeft: 20
  readonly property int islandPillGlyphTop: 12
  readonly property int islandPillGlyphSize: 18
  readonly property int islandPillGlyphTopWide: 9
  readonly property int islandPillGlyphSizeWide: 24
  readonly property int islandPillTextTop: 14
  readonly property int islandPillTextLeft: 52
  readonly property int islandPillLabelWidthTrack: 72
  readonly property int islandPillLabelWidthWide: 170
  readonly property int islandPillLabelWidthAction: 200
  readonly property int islandPillLabelLeftDetail: 54
  // (Wide enough for "Charging" in the semibold it is set in; 58 elided it with room to spare.)
  readonly property int islandPillLabelWidthDetail: 66
  readonly property int islandPillDetailLeft: 124
  readonly property int islandPillDetailWidth: 44
  readonly property int islandPillLabelWidthDots: 78
  readonly property int islandPillDotsDetailLeft: 133
  readonly property int islandPillDotsDetailWidth: 100
  readonly property int islandPillTrackTop: 17
  readonly property int islandPillTrackHeight: 8
  readonly property int islandPillTrackLeft: 52
  readonly property int islandPillTrackWidth: 166
  readonly property int islandPillTrackWidthAction: 140
  readonly property int islandPillTrackLeftLabel: 128
  readonly property int islandPillTrackWidthLabel: 91
  readonly property int islandPillReadingWidth: 80
  // The least room between the track's end and a reading set over its far end (a word, not a figure).
  readonly property int islandPillReadingGap: 10
  readonly property int islandPillReadingInset: 20
  readonly property int islandPillReadingInsetAction: 48
  readonly property int islandPillReadingInsetWaveform: 45
  readonly property int islandPillNoteTop: 15
  readonly property int islandPillNoteWidth: 100
  readonly property int islandPillNoteInset: 21
  readonly property int islandPillActionTop: 15
  readonly property int islandPillActionSize: 12
  readonly property int islandPillActionInset: 20
  readonly property int islandPillWaveformTop: 12
  readonly property int islandPillWaveformWidth: 107
  readonly property int islandPillWaveformHeight: 19
  readonly property int islandPillDotsInset: 14
  readonly property int islandPillDotsTop: 18
  readonly property int islandPillDotSize: 6
  readonly property int islandPillDotGap: 4
  readonly property real islandPillCaptionSize: 12
  readonly property real islandPillNoteSize: 11
  readonly property real islandPillReadingSize: 12
  // The alert outline: 1 px, in love at lockErrorOutline.
  readonly property int islandPillAlertWidth: 1
  // While a track's total is not known: a segment this share of the track, one pass in this long.
  readonly property real levelTrackSweepShare: 0.25
  readonly property int levelTrackSweep: 1200

  // The on-screen displays hold the island for this long (the pill itself is an IslandPill).
  // "after about a second and a half, it just melts back into the clock".
  readonly property int osdDwell: 1500

  // The sharing pill: a separate transient (not the notification pill) that owns
  // Quick Share consent when the Nearby panel is shut. Offer is a small card with
  // Accept/Decline; progress is an IslandPill row; confirm holds briefly.
  readonly property int sharingOfferWidth: 420
  readonly property int sharingOfferHeight: 64
  readonly property int sharingOfferRadius: panelRadius
  readonly property int sharingConfirmDwell: 2500
  // A failed rebuild holds longer than a finished one; its error is in the terminal.
  readonly property int rebuildFailedDwell: 8000

  // The dictation pill, Handy's recording overlay drawn by the island: an OSD-sized row
  // (mic, the level bars, the time and an ×) that opens into a card once live text arrives,
  // the row staying on top and the transcript flowing under it.
  // The card keeps its own corner; the bare row is the island pill's.
  readonly property int dictationRadius: 24
  readonly property int dictationLiveWidth: 420
  // Handy's lowest 9 spectrum buckets, mirrored about the middle bar.
  readonly property int dictationBuckets: 9
  readonly property real dictationBarWidth: 3
  readonly property real dictationBarGap: 3.5
  readonly property real dictationBarMin: 3
  // The level bars' spring (Ui/MorphSpring.qml): critically damped, quicker than the island's
  // morphOmega (21) since levels land about 30 times a second and the bars must follow them
  // (a tenth of a second to 90%: 3.89 / 40). A bar is at rest within a tenth of a pixel.
  readonly property real levelOmega: 40

  // Scrolling (Ui/ScrollView.qml). The content follows the wheel on a critically damped spring at
  // scrollOmega: 90% of a notch in about 160 ms (3.89 / 24), a touch quicker than the small controls
  // (microOmega), since a held wheel retargets it every notch and it must not feel towed.
  readonly property real scrollOmega: 24
  // Past an end the content gives (Motion.rubberBand) and comes back once the hand has been still
  // for scrollIdle ms. A wheel notch is a click, not a hand, so only this share of what it pushes
  // past the end counts: a nudge at the end of a list, not a lurch.
  readonly property int scrollIdle: 80
  readonly property real scrollWheelGive: 0.3
  // What a touchpad throw keeps of its speed each millisecond (Motion.project): a quick throw, since
  // the panels are short. The coast rides a spring at 2000 * (1 - rate) / rate, the one pace at
  // which a spring let go at the fingers' speed neither speeds up nor brakes at once.
  readonly property real scrollCoastRate: 0.994
  // The scrollbar thumb: its width, the gutter between the rows and it (it sits outside the rows,
  // in the panel's inset, so it never covers them), and how long it stays after the last movement.
  readonly property int scrollThumbWidth: 3
  readonly property int scrollThumbGap: 4
  readonly property int scrollThumbLinger: 700

  // Rows in a list (Control/KeyedList.qml, the launcher, Nearby's staged files). A new row fades in
  // and rises listRise px over listEnter on an ease-out; one that goes fades and shrinks to
  // listExitScale over listExit; the rows around it make room over listSettle on listEase, starting
  // with the change. listEase is a critically damped spring drawn as a curve (omega * t = 7 at its
  // end, so about omega 29 over listSettle, a touch quicker than the island since a typed query
  // moves the launcher's rows on every key:
  // a soft start, most of the way by a third, a long quiet landing), since a view's transitions
  // take a curve and not a spring; nothing in a list runs past its place.
  readonly property int listEnter: reduceMotion ? 1 : 180
  readonly property int listExit: reduceMotion ? 1 : 110
  readonly property int listSettle: reduceMotion ? 1 : 240
  readonly property real listRise: reduceMotion ? 0 : 4
  readonly property real listExitScale: reduceMotion ? 1 : 0.96
  readonly property var listEase: [0.3, 0.4, 0.3, 1, 1, 1]
  // A row that opens or closes its own slot (the control centre's notification history): the slot's
  // height rides a critically damped spring at this pace, and the row is clear by the time the slot
  // is listSlotFade of the way shut, so it never shows as a sliver.
  readonly property real listSlotOmega: 21
  readonly property real listSlotFade: 0.35

  // A moment swapped for another inside the open pill (Activities/Moments.qml): the stage's fade
  // spring, twice the island's pace so the two halves together take about what the old 140 ms
  // pair did (to 2% in about 160 ms), and the opacity at which the contents change.
  readonly property real momentFadeOmega: 42
  readonly property real momentSwapOpacity: 0.02
  readonly property int dictationTextInset: 20
  readonly property int dictationTextTop: 44
  readonly property int dictationTextSize: 13
  readonly property int dictationTextLineHeight: 19
  readonly property int dictationTextLines: 4
  readonly property int dictationTextBottom: 14

  // The control centre: the same 520 px column the launcher grows into, carrying a tile grid,
  // two sliders, the media card and notifications. Source frames: 520 x 716 at 1920 px.
  readonly property int controlWidth: panelColumnWidth
  readonly property int controlRadius: panelRadius
  readonly property int controlInset: 13

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
  // A tile too narrow for its badge and words side by side (the phone panel's 108 px thirds)
  // stacks them: the badge above, the label and the line under it, on a rounded rectangle. The
  // padding is even on all four sides. The radius is the shell's middle step (rows, power tiles):
  // at the card's own 26 the grid read as soft pills. The words may run 8 px short of the edge.
  readonly property int controlTileStackedHeight: 90
  readonly property int controlTileStackedRadius: 14
  readonly property int controlTileStackedBadge: 28
  readonly property int controlTileStackedPad: 12
  readonly property int controlTileStackedLabelTop: 48
  readonly property int controlTileStackedSubTop: 64
  readonly property int controlTileStackedTextSlack: 8

  // Sliders. Thick pills whose fill is the level, with the glyph riding inside the fill.
  readonly property int controlSliderHeight: 40
  readonly property int controlSliderGap: 17
  readonly property int controlSliderGlyphLeft: 13

  // The media card; the gap separates each block from the next.
  readonly property int controlBlockGap: 15
  readonly property int controlMediaHeight: 140
  readonly property int controlMediaRadius: 14
  readonly property int controlMediaTitleSize: 19
  readonly property int controlMediaArtistSize: 12
  readonly property int controlMediaCaptionSize: 11
  // Transport: three equal discs to the right of the title, after One UI 9's player.
  readonly property int controlMediaButtonGap: 8
  // The scrub bar, also after One UI 9: a thick track, a solid thumb, and translucent hills
  // that ride the played part while music plays.
  readonly property int controlMediaTrackY: 98
  readonly property int controlMediaTrackHeight: 6
  readonly property real controlMediaTrackAlpha: 0.2
  readonly property int controlMediaThumbSize: 18
  readonly property real controlMediaThumbShade: 1.3
  // Drawn only as the keyboard focus ring.
  readonly property real controlMediaThumbRing: 2.5
  readonly property real controlMediaThumbPressScale: 1.2
  readonly property int controlMediaHillHeight: 14
  readonly property int controlMediaTimeY: 111

  readonly property int controlSectionGap: 23
  readonly property int controlSectionHeight: 22
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
  // The outer corners of rows stacked as one group, and the seam between them.
  readonly property int controlRowGroupRadius: 14
  readonly property int controlRowGroupGap: 2
  readonly property int controlRowInset: 16
  readonly property int controlViewMaxHeight: 620

  // The Displays sub-view's arrangement canvas: monitors drawn to scale, fitted inside the
  // padding. Thumbnails take the wallpaper tile's radius, the canvas the media card's.
  readonly property int displaysCanvasHeight: 188
  readonly property int displaysCanvasPadX: 32
  readonly property int displaysCanvasPadY: 28
  readonly property int displaysCanvasRadius: controlMediaRadius
  readonly property int displaysTileRadius: wallpaperTileRadius
  readonly property real displaysTileVeil: 0.3
  readonly property int displaysPlateHeight: 22
  readonly property int displaysPlateInset: 8
  readonly property real displaysPlateAlpha: 0.85
  // Within this many canvas pixels of a top, centre or bottom alignment, the drop lands on it.
  readonly property int displaysSnapDistance: 10
  // A dropped monitor keeps at least this share of its shorter edge against the panel.
  readonly property real displaysMinOverlap: 0.15
  // Marks the row of the screen the panel is open on.
  readonly property int displaysHereDot: 8

  // The wallpaper picker: the pill grows into a wide, short card with one row of previews.
  // The column is 800, not the source's 1008, fitting four wallpapers exactly.
  readonly property int wallpaperWidth: 800
  readonly property int wallpaperHeight: 232
  readonly property int wallpaperRadius: panelRadius
  readonly property int wallpaperInset: 24
  readonly property int wallpaperMetaSize: 12
  readonly property int wallpaperHeaderTop: 4

  // The row is a carousel, not a grid: clipped by the panel, running on past both edges.
  readonly property int wallpaperRowMid: 130
  readonly property int wallpaperTileGap: 16
  readonly property int wallpaperTileRadius: 8

  // The chosen wallpaper is drawn larger and every other one the same, so the row has one
  // focus. First is the selected width, last everything else; four come to 720 inside 752.
  readonly property var wallpaperTileWidths: [192, 160]

  // 16:9, as the board draws them; previews are cropped rather than letterboxed, so a tile
  // is never part panel background.
  readonly property real wallpaperTileAspect: 16 / 9

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
  // so ChoiceTiles draws it from the power tokens; the toggle rows below are this card's own.
  readonly property int recorderWidth: 316
  // Four rows under the capture tiles: three toggles plus the frame-rate row.
  readonly property int recorderHeight: 264
  readonly property int recorderRadius: panelRadius
  readonly property int recorderInset: 11

  readonly property int recorderRowsTop: 108
  readonly property int recorderRowHeight: 32
  readonly property int recorderRowGap: 4
  readonly property int recorderRowRadius: 16
  readonly property int recorderRowTextLeft: 12
  readonly property int recorderRowLabelSize: 12

  // The recording mark the pill carries: love rather than the accent, so it does not read as
  // one more thing merely on.
  readonly property int recorderDotSize: 8

  // The privacy marks: a camera in foam left of the clock, a microphone in gold right of it,
  // after macOS's green and orange, so neither reads as the recording's love; see
  // Ui/PillMarks.qml for the split.
  readonly property int privacyGlyphSize: 14
  readonly property real privacyGlyphStroke: 1.75
  readonly property color cameraMark: foam
  readonly property color microphoneMark: gold

  // Moments (Activities/Moments.qml): the sharing pill's row, and an OSD-sized compact one.
  readonly property int momentWidth: sharingOfferWidth
  readonly property int momentHeight: sharingOfferHeight
  readonly property int momentRadius: sharingOfferRadius
  readonly property int momentCompactWidth: 340
  readonly property int momentCompactHeight: 42
  readonly property int momentCompactRadius: 21
  readonly property real momentTitleSize: 12.5
  readonly property real momentSubtitleSize: 10.5
  readonly property int momentDwell: 8000
  readonly property int momentPluggedDwell: osdDwell + 900
  // The gap between a moment's buttons (Activities/MomentRow.qml).
  readonly property int activityButtonGap: 8

  // The calendar: a split card, wide and low so it is plainly another shape than the control centre.
  // The month is on the left (title and nav over a grid), the chosen day's agenda on the right.
  readonly property int calWidth: 680
  readonly property int calHeight: 330
  readonly property int calRadius: panelRadius
  readonly property int calInset: 24
  // The header is the left pane's alone, seated so its title's centre line is 30 px down.
  readonly property int calHeaderTop: -5
  // Where the left pane ends: the rule between the two, and the header's own width.
  readonly property int calSplit: 370
  readonly property int calRuleInset: 26

  // Seven columns on a 46 px pitch, six rows on 38; calGridTop is the first row's top, not a
  // baseline. Day centres in its cell, marker on the number, dot under it inside the marker.
  readonly property int calWeekdayTop: 64
  readonly property int calWeekdaySize: 11
  readonly property int calGridTop: 84
  readonly property int calColumnPitch: 46
  readonly property int calRowPitch: 38
  readonly property int calColumnFirst: 47
  readonly property int calDaySize: 13
  readonly property int calTodayMarker: 30
  readonly property int calDotSize: 4
  readonly property int calDotDrop: 10

  // The right pane: an eyebrow (how far off the day is) over the day's name, then the agenda, whose
  // first row tops out level with the grid's first. Room for calAgendaMax rows; more scroll.
  readonly property int calAgendaLeft: calSplit + 20
  readonly property int calEyebrowTop: 17
  readonly property real calEyebrowSize: 11.5
  readonly property int calHeadingTop: 32
  readonly property int calHeadingSize: 15
  readonly property int calAgendaTop: 66
  readonly property int calAgendaHeight: 36
  readonly property int calAgendaGap: 4
  readonly property int calAgendaRadius: 14
  readonly property int calSpineLeft: 10
  readonly property int calSpineWidth: 3
  readonly property int calSpineHeight: 18
  readonly property int calTimeLeft: 22
  readonly property real calTimeSize: 11.5
  readonly property int calTitleLeft: 70
  readonly property real calEventTitleSize: 12.5
  readonly property real calMetaSize: 11
  readonly property int calMetaMax: 76
  readonly property int calAgendaMax: 6
  // A row under the pointer opens to its whole title and the lines a row has no room for (when it
  // runs to, how long, where, whose calendar). Not at once: the pointer crossing the list on its way
  // elsewhere opens nothing.
  readonly property int calAgendaHoverDelay: 180
  // From an open row to the next: brief, so a pointer run down the list opens the row it stops on
  // and not every row on the way.
  readonly property int calAgendaHoverSwap: 80
  readonly property int calAgendaHoverGrace: 110
  readonly property real calAgendaDetailSize: 11
  readonly property int calAgendaDetailGap: 3
  readonly property int calAgendaDetailPad: 10
  readonly property int calAgendaBlock: calAgendaMax * calAgendaHeight + (calAgendaMax - 1) * calAgendaGap

  // Board 13: a 1920x1080 lock surface. The surface paints its own background, so the
  // session-lock protocol never exposes a black frame.
  readonly property int lockDateTop: 162
  readonly property int lockDateSize: 20
  readonly property int lockClockTop: 175
  readonly property int lockClockSize: 112
  // The longest a manual lock waits for something still coming to rest (Bus.lockHeld) before
  // it captures the desktop anyway: the phone satellite's return takes about 400 ms.
  readonly property int lockSettleMax: 700

  // The login pill: avatar, name over the password line, submit disc. Offsets are from the
  // pill's own top-left; the radius is height / 2.
  readonly property int lockPillTop: 908
  readonly property int lockPillWidth: 360
  readonly property int lockPillHeight: 60
  readonly property int lockPillInset: 8
  readonly property int lockAvatarSize: 44
  readonly property int lockAvatarGlyphSize: 17
  readonly property int lockTextLeft: 64
  readonly property int lockNameTop: 13
  readonly property real lockNameSize: 12.5
  readonly property int lockLineTwoTop: 34
  readonly property int lockLineTwoHeight: 14
  readonly property real lockLineTwoSize: 10.5
  readonly property int lockPlaceholderInset: 5
  readonly property int lockSubmitSize: 44
  readonly property int lockArrowSize: 18
  readonly property int lockSpinnerSize: 20
  readonly property int lockSpinnerTurn: 900
  readonly property int lockCaptionGap: 12
  readonly property int lockCaptionGlyph: 14
  readonly property int lockCaptionGlyphGap: 6
  readonly property int lockCaptionSize: 11
  readonly property real lockErrorOutline: 0.6
  // A refusal shakes the pill three times across 6 units.
  readonly property int lockShakeTravel: 6
  readonly property int lockShake: 240
  readonly property int lockStateFade: 120
  // Caps Lock has no Hyprland event; keys in the field ask too, so this only catches a
  // toggle from another keyboard.
  readonly property int lockCapsPollMs: 1500

  readonly property real lockCaretWidth: 1.5
  readonly property int lockCaretHeight: 12
  readonly property int lockDotSize: 6
  readonly property int lockDotGap: 5
  readonly property int lockDotPop: 80
  // The caret blink on the field, at the standard text-caret period.
  readonly property int lockCaretBlinkMs: 530

  // The veil comes from the captured desktop, not the compositor backdrop, and tints the
  // blurred capture rather than covering it; at 1.0 the background reads as one flat fill.
  readonly property color lockVeilColor: surface
  readonly property real lockVeilOpacity: 0.55
  readonly property color lockTextPrimary: inkPrimary
  readonly property color lockCaretColor: focusRing
  readonly property int lockBlurMax: surfaceBlurMax
  readonly property real lockBlur: surfaceBlur
  readonly property int lockIn: 350
  readonly property int lockOut: 350

  // The Nearby panel (boards 16a-16h). The 520 column carries two segmented tracks over
  // a send body (the Choose files button or the staged rows, then the devices) or a receive
  // body (radar, consent card and arrivals); heights are the boards' measured stacks.
  readonly property int nearbyWidth: panelColumnWidth
  readonly property int nearbyRadius: panelRadius
  readonly property int nearbyInset: 13
  readonly property int nearbyPadTop: 22
  readonly property int nearbyPadBottom: 20

  // The header: two 212 px segmented tracks, 20 px from either edge, each half carrying a
  // glyph and a label. The chosen plate slides on the workspace-slot spring.
  readonly property int nearbyHeaderHeight: 36
  readonly property int nearbyHeaderSide: 20
  readonly property int nearbyTrackWidth: 212
  readonly property int nearbyTrackHeight: 36
  readonly property int nearbyTrackRadius: 18
  readonly property int nearbyChosenInset: 3
  readonly property int nearbyChosenHeight: 30
  readonly property int nearbyChosenRadius: 15
  readonly property int nearbySegmentGlyph: 16
  readonly property int nearbySegmentGap: 8
  // Label-only cells (the platform control) are their label and this much either side.
  readonly property int nearbyFitPad: 12
  // The compact row (the wallpaper picker's source, the frame rates) has no track: fixed cells,
  // 22 px tall and 4 apart.
  readonly property int segmentCompactWidth: 46
  readonly property int segmentCompactHeight: 22
  readonly property int segmentCompactGap: 4
  readonly property int segmentLabelSize: 12

  // The send body (boards 16a, 16e, 16f). With nothing staged it is one full-width accent
  // button; staged files list as 40 px rows under a "Files" section line, and the panel
  // springs taller one row at a time.
  readonly property int nearbyBodyGap: 16
  // With KDE Connect picked and no phone: the header, a glyph, a line and a button, 210 tall.
  readonly property int nearbyAbsentHeight: 210
  readonly property int nearbyChooseHeight: 44
  readonly property int nearbySectionTop: 22
  readonly property int nearbySectionToRows: 6
  readonly property int nearbyFileHeight: 40
  readonly property int nearbyFileGap: 6
  readonly property int nearbyFileThumb: 28
  readonly property int nearbyFileThumbRadius: 8
  readonly property int nearbyFileThumbGlyph: 15
  readonly property int nearbyFileTextLeft: 48
  readonly property int nearbyFileRemove: 12
  readonly property int nearbyFileRemoveRight: 16
  // Staged rows past this many scroll inside the list rather than growing the panel.
  readonly property int nearbyFilesMax: 4

  // The "Nearby" section row and the device tiles under it. A tile is a 56 px disc centred
  // on a 120 px column (centres 140/260/380 for three), ringed by a progress arc while
  // sending and filled with a check when sent.
  readonly property int nearbySectionSize: sectionSize
  readonly property int nearbySectionSide: 16
  readonly property int nearbyDeviceSlot: 120
  readonly property int nearbyDeviceSize: 56
  readonly property int nearbyDeviceGlyph: 22
  readonly property int nearbyDeviceNameGap: 10
  readonly property real nearbyDeviceNameSize: 11.5
  readonly property real nearbyDeviceSubSize: 10.5
  readonly property real nearbyDeviceSubGap: 2
  readonly property int nearbyDeviceSubHeight: 13
  readonly property int nearbyDeviceNameLine: 14
  readonly property int nearbyRingSize: 64
  readonly property real nearbyRingWidth: 2.5
  readonly property int nearbyCancelSize: 20
  readonly property int nearbyCancelGlyph: 12
  readonly property int nearbyCancelStroke: 2
  readonly property int nearbyCheckSize: 24
  // A delivered tile holds its check this long, then the tile and the staged files reset.
  readonly property int nearbySentDwell: 1600
  // A failed send says so on its tile this long before the tile is tappable again.
  readonly property int nearbyFailDwell: 2600

  // The file picker (boards 16b, 16c): the panel grows to 960 x 412 around three columns -
  // parent 200, current 320, preview 360 - on 30 px rows at a 32 px pitch.
  readonly property int pickerWidth: 960
  readonly property int pickerHeight: 412
  readonly property int pickerHeaderHeight: 56
  readonly property int pickerSide: 14
  readonly property int pickerColumnsTop: 68
  readonly property int pickerColumnsBottom: 12
  readonly property int pickerParentX: 14
  readonly property int pickerParentWidth: 200
  readonly property int pickerCurrentX: 230
  readonly property int pickerCurrentWidth: 320
  readonly property int pickerPreviewX: 576
  readonly property int pickerPreviewWidth: 360
  readonly property int pickerRuleOneX: 222
  readonly property int pickerRuleTwoX: 558
  readonly property int pickerRowHeight: 30
  readonly property int pickerRowPitch: 32
  readonly property int pickerRowRadius: 8
  readonly property int pickerGlyph: 15
  readonly property int pickerGlyphLeft: 12
  readonly property int pickerTextLeft: 36
  readonly property int pickerMetaRight: 12
  readonly property int pickerMarkSize: 13
  readonly property int pickerMetaSize: 11
  readonly property int pickerFocusMarkWidth: 3
  readonly property int pickerFocusMarkHeight: 16
  readonly property int pickerPreviewImageHeight: 270
  readonly property int pickerPreviewRadius: 14
  // The wallpaper chooser previews a 16:9 picture: 340 x 191 at (586, 76).
  readonly property int pickerWallpaperPreviewInset: 10
  readonly property int pickerWallpaperPreviewTop: 8
  readonly property int pickerWallpaperPreviewWidth: 340
  readonly property int pickerWallpaperPreviewHeight: 191
  readonly property int pickerWallpaperPreviewRadius: 12
  readonly property int pickerChipHeight: 26
  readonly property int pickerChipGlyph: 14

  // The receive body: three rings rippling out of a filled core, the name and the timer
  // chip; an inbound consent card and the arrivals list below.
  readonly property int nearbyRadarTop: 20
  readonly property int nearbyRadarOuter: 156
  readonly property int nearbyRadarMid: 120
  readonly property int nearbyRadarInner: 86
  readonly property int nearbyRadarCore: 56
  readonly property int nearbyRadarGlyph: 24
  readonly property int nearbyRadarNameGap: 4
  readonly property int nearbyNameSize: 14
  readonly property int nearbyChipGap: 7
  readonly property int nearbyChipHeight: 26
  readonly property int nearbyChipRadius: 13
  readonly property real nearbyChipSize: 11.5
  readonly property int nearbyChipGlyph: 14
  readonly property int nearbyPeerChipGlyph: 13
  readonly property int nearbyChipInnerGap: 6
  readonly property int nearbyChipPairGap: 8
  // One ripple out of the core to past the outer ring; three ripples ride it a third apart.
  readonly property int nearbyRadarLoop: 2700

  readonly property int nearbyIncomingTop: 18
  readonly property int nearbyIncomingHeight: 64
  readonly property int nearbyIncomingRadius: 14
  readonly property int nearbyIncomingGlyph: 20
  readonly property real nearbyIncomingSenderSize: 12.5
  readonly property real nearbyIncomingMetaSize: 10.5
  readonly property int nearbyPinSize: 12

  readonly property int nearbyReceivedGap: 24
  readonly property int nearbyReceivedAfterCard: 22
  readonly property int nearbyRowHeight: 44
  readonly property int nearbyRowGap: 8
  readonly property int nearbyRowMetaSize: 12
  readonly property int nearbyRowGlyph: 18
  readonly property int nearbyRowTextLeft: 48
  readonly property int nearbyRowInset: 16
  readonly property int nearbyRowsMax: 4
  readonly property int nearbyReceiveBottom: 12
  // The newest arrival wears the accent ground and edge (board 16h) this long.
  readonly property int nearbyArrivalGlow: 4000

  // The hover preview that trails the cursor over a received image: its largest edge, its
  // offset down and to the right of the pointer, and the spring that chases the pointer.
  readonly property int nearbyPreviewMax: 220
  readonly property int nearbyPreviewOffset: 18
  readonly property real nearbyPreviewStiffness: 400
  readonly property real nearbyPreviewDamping: 0.8

  // Board 16e: a file drag over the island turns the pill into a 248 x 52 drop well.
  readonly property int nearbyDropTargetWidth: 248
  readonly property int nearbyDropTargetHeight: 52
  readonly property real nearbyDropStroke: 1.5
  readonly property int nearbyDropWellInset: 6
  readonly property int nearbyDropWellHeight: 40
  readonly property int nearbyDropWellRadius: 20
  readonly property real nearbyDropWellStroke: 1.25
  readonly property int nearbyDropWellGlyph: 24

  // The pill's shut width, one per combination. The clock stays centred: the equaliser and
  // camera sit left of it, the recording dot and microphone right. Marks first fill the idle
  // pill's own side padding, keeping islandMarkInset clear of the end, and the pill only
  // widens, evenly, once the heavier side outgrows it.
  function islandCollapsedWidth(media, recording, camera, microphone) {
    function side(widths) {
      var room = 0;
      for (var i = 0; i < widths.length; i++)
        room += (i === 0 ? islandMarkClockGap : islandMarkGap) + widths[i];
      return room > 0 ? room + islandMarkInset : 0;
    }
    var left = side((media ? [islandEqualiserWidth] : []).concat(camera ? [privacyGlyphSize] : []));
    var right = side((recording ? [recorderDotSize] : []).concat(microphone ? [privacyGlyphSize] : []));
    var overflow = Math.max(0, Math.max(left, right) - islandSideInset);
    return islandIdleWidth + 2 * overflow;
  }

  readonly property int workspacePadding: 14
  readonly property int workspaceRadius: 18
  readonly property int workspaceGap: 6
  readonly property int workspaceSlotWidth: 20
  readonly property int workspaceSlotActiveWidth: 36
  readonly property int workspaceSlotHeight: 16
  readonly property int workspaceSlotRadius: 8
  // The active slot's soft accent bloom, the only glow in the shell (saneAspect's).
  readonly property real workspaceGlowBlur: 8
  readonly property real workspaceGlowAlpha: 0.55

  // Every morph rides one curve, its pace from a survey of ten 1440p60 recordings: 186 found,
  // 176 fitted; measured quartiles 36/68/104/148 ms. The survey's +1.5% overshoot was left out.
  // The shapes ride it as a spring (morphOmega above), so this is no animation's length:
  // it is what a claim reports as its morph, and the nominal length of the Morph easing.
  readonly property int morphSurface: reduceMotion ? 1 : 190

  // A control changing state rather than shape: a toggle, a slider, a hover or a press.
  readonly property int morphState: reduceMotion ? 1 : 115

  // A colour changing with that state: a tile lighting, a hover tint, a button's ink. Slower
  // than the press it answers, at saneAspect's 250 ms, and never overshooting (Ui/Tint.qml).
  readonly property int tintFade: reduceMotion ? 1 : 250

  // Content swaps are not morphs. A surface takes ~300 ms to change shape while its contents
  // change over ~five frames, so fading on the geometry's clock would read as a dissolve.
  readonly property int morphContent: reduceMotion ? 1 : 50

  // The outgoing contents dissolve inside the still, short so it finishes before the taker lands.
  readonly property int morphFarewell: reduceMotion ? 1 : 70

  // The content morph between two surfaces (Ui/MorphLayer.qml). What pairs flies on the shape's
  // own progress; what the surface before had with no partner is cut once the clock passes
  // morphCut ms (on the next frame, never half faded under what arrives); what the new one has
  // with no partner arrives in a cascade, row by row, morphArriveDelay after its first frame and
  // morphArriveStep apart (at most morphArriveSteps steps), each over morphArriveFade. Words that
  // change roll morphRoll px; the mask holding an anchor back reaches morphMaskBleed px past it,
  // for glyphs that overhang.
  readonly property int morphCut: 6
  // How long into a morph the taker is read again for contents that lay out late (MorphLayer).
  readonly property int morphRescanFor: 180
  // A pair travelling this far flies on a backing of the card's own ground (MorphGhost), so it hides
  // what it crosses rather than print over it.
  readonly property int morphBackingTravel: 120
  // How long a plate takes to turn another colour in a morph (Ui/MorphPart.qml).
  readonly property int morphPlateTint: 120
  // How long what waited for a pair that leads a panel takes to come up (Ui/MorphLayer.qml).
  readonly property int morphWaitedFade: 50
  // How far short of landing a pair that leads a panel down is when what lies below its landing comes.
  readonly property int morphLeadBelow: 36
  // Milliseconds per pixel: how what lies below where that pair lands comes, top to bottom.
  readonly property real morphLeadStagger: 0.05
  // How far a carousel's tile on its way may overlap a tile with no partner beside it as that comes:
  // less than nothing, it has to leave that much of a gap.
  readonly property int morphCarouselRoom: -10
  // A pill whose words change where it stands: the old are gone over morphPillOut ms, the new start
  // morphPillIn ms in, so one frame has the old faint and none has neither.
  readonly property int morphPillOut: 45
  readonly property int morphPillIn: 30
  // ...and come up over morphPillRoll ms: a roll, not a swap in a frame or two.
  readonly property int morphPillRoll: 130
  // How long a pill's glyph takes from where the old one sat to where the new one sits.
  readonly property int morphGlyphTravel: 150
  readonly property int morphArriveDelay: 6
  readonly property int morphArriveStep: 10
  readonly property int morphArriveSteps: 12
  readonly property int morphArriveFade: 90
  readonly property real morphRoll: 8
  readonly property int morphTitleRoll: 14
  // How long a changed word takes to roll out, and to roll in (MorphPart).
  readonly property int morphRollOut: 60
  readonly property int morphRollIn: 110
  // How long the fill or picture of a pair that only the panel before had takes to go (a row's card
  // around a notification that becomes a toast).
  readonly property int morphPlateFade: 130
  readonly property real morphMaskBleed: 2

  // The still's ground outlives its contents, and only starts to go once the taker reports a
  // frame on screen (Ui/IslandOrigin.qml), so it covers however long that takes.
  readonly property int morphGroundFade: reduceMotion ? 1 : 60

  // The longest anything waits on a surface's first frame before going ahead without it. A
  // mapped surface lands in a frame or two; this only catches a compositor that never answers.
  readonly property int morphPresentFallback: 250

  // How long a still stays once its taker is on screen: its ground fade and two frames over.
  readonly property int morphHoldLinger: 100

  // How long a closed surface keeps its window full size before parking it, so the bar's pill
  // has a frame on screen under the surface's last one.
  readonly property int surfacePark: 80
  // How long a panel holds the keyboard exclusively after opening (Ui/IslandSurface.qml), and tints
  // snap (Ui/IslandSurfaceBase.qml): past the shape's settle, as both cost a frame.
  readonly property int surfaceFocusPrime: 350

  // A close hands its drop shadow to the bar's pill over this long, one fading out as the other
  // fades in, so the two never stack (two at once read as a dark bloom under the pill). Inside
  // surfacePark, so the surface's has gone before its window parks.
  readonly property int shadowHandover: reduceMotion ? 1 : 64

  // How long a parked surface keeps its window before letting it go (Ui/IslandSurfaceBase.qml).
  readonly property int surfaceRetain: 300000

  // Still used by Calendar/Arrival (morphEnter; Moments and Toast ride springs now), and by the content cross-fades
  // (ContentFade, KeyedList, chips, PhoneSatellite, PillState, DictationPill: morphContent); not by the surfaces' contents.
  readonly property int morphEnter: reduceMotion ? 1 : 90

  // Contents fade as a function of the card's shape progress (0 at the shape the card left,
  // 1 at the one it is going to; Ui/Motion.js progress), so a retarget can never pull them
  // apart from the shape. Each is [start, end]: the progress where the fade begins and ends.
  // Out of the pill: about as quick as the 50 ms fade they replace.
  readonly property var fadeOpenIn: [0.08, 0.6]
  // The least an open surface's contents are drawn at, so they are drawn (IslandSurfaceBase).
  readonly property real bodyPrime: 0.004
  // Panel to panel: the entering contents start late, as the 45 ms delay did, and land before the shape settles.
  readonly property var fadeEnterIn: [0.15, 0.45]
  // Closing: the contents are gone by the time the shape has travelled this far, or in
  // morphContent ms (IslandSurfaceBase.closeT), whichever is first; never in under a few frames.
  readonly property var fadeCloseOut: [0.05, 0.68]
  // Closing: the collapsed pill's clock and marks arrive as the card nears the pill.
  readonly property var fadePillIn: [0.7, 1.0]
  // A pill going back has next to no shape to travel, so its clock starts as its contents go:
  // waiting for 0.7 left the pill bare for a few frames in between.
  readonly property var fadePillInSmall: [0.4, 1.0]

  // They settle through a few pixels in the direction the height travels, so a switch between
  // two same-width columns has an axis to read.
  readonly property real morphEnterTravel: 10

  // Contents grow with the card (IslandSurfaceBase.growRatio): out of the pill they are drawn at the
  // card's share of its open width, never smaller than morphGrowMin, and through a blur of up to
  // morphGrowBlur px that has cleared by morphGrowSharp of the way from that floor to full size, so
  // the panel comes out of the island as one thing and goes back into it the same way.
  readonly property real morphGrowMin: 0.6
  readonly property real morphGrowBlur: 7
  readonly property real morphGrowSharp: 0.8
  // The longest a closing surface's contents stay, however its shape is travelling (closeT).
  readonly property int morphCloseFade: reduceMotion ? 1 : 240

  // One panel into another (Ui/MorphLayer.qml): what the panel before had with no partner softens
  // and fades over morphDissolveOut ms; this panel's contents come up through a blur over
  // morphDissolve ms, starting morphDissolveDelay in, so the two overlap and neither is cut. They
  // start morphDissolveScale larger and settle; the blur on either is at most morphDissolveBlur px.
  readonly property int morphDissolveOut: 150
  readonly property int morphDissolveDelay: 50
  readonly property int morphDissolve: 220
  readonly property real morphDissolveScale: 1.025
  readonly property real morphDissolveBlur: 7

  // The clock's digit roll, measured at 60 fps: each digit travels about half a glyph's height
  // and cross-fades; a fraction of font size, so it reads the same at pill and card size.
  readonly property real clockRollTravel: 0.45

  // Its own clock rather than a content swap's five frames, so the roll reads as travel; the
  // arriving digit's fade trails the move, dipping the pair's ink mid-roll.
  readonly property int clockRoll: reduceMotion ? 1 : 110
  readonly property int clockRollFade: reduceMotion ? 1 : 170

  // A glyph that turns into another in place (the OSD's speaker gaining its cross, the login
  // disc's arrow giving way to the spinner) dips to this scale as the two cross-fade, so the
  // change reads as one mark turning over rather than two overlapping.
  readonly property real glyphSwapDip: 0.8

  // A state's contents giving way to another's where they stand (the hover card's track block
  // and its week, the phone's screen starting to ring): PillState's cross-fade, twice a content
  // swap, so both are seen to pass.
  readonly property int stateSwap: morphContent * 2

  // The equaliser's bars easing down to their resting heights when the music pauses.
  readonly property int eqSettle: reduceMotion ? 1 : 260

  // The dictation transcript moving up one line as a new one arrives under it.
  readonly property int dictationLineSlide: reduceMotion ? 1 : 160

  // How long a still holds when nothing claimed the island from it: a deliberate beat.
  readonly property int morphHold: 240

  // Motion and interaction tokens for things wired across surfaces; each stays literal so
  // callers can wrap it in `duration()` themselves.
  // The hard stop on a still whose taker never reports a frame, past the claim's duration.
  // Normally a still goes morphHoldLinger after its taker's first frame, long before this.
  readonly property int morphHoldBuffer: 260
  // Short value-fill tween, e.g. the OSD bar filling to the new level.
  readonly property int morphFill: 80
  // A small pause beat in sequences, e.g. LockReveal.
  readonly property int morphBeat: 50
  // The wait after a panel closes and before its chosen action runs, so the pill is back
  // to its resting shape first (session, profiles, recorder launches). A close on the morph
  // spring is within half a pixel of the pill by about 450 ms.
  readonly property int actionSettleDelay: reduceMotion ? 0 : 560

  // Ambient state rather than a control answering: the media card's hills swelling, the
  // radar going live, each half of a pending pulse. Slower than morphState, so it reads as
  // mood rather than feedback.
  readonly property int morphAmbient: 420
  // A transfer's progress fill catching up with the reported fraction.
  readonly property int morphProgress: 250
  // One loop of the sharing pill's three connecting dots.
  readonly property int sharingPulse: 1200
  // The Nearby hover preview fading in.
  readonly property int nearbyPreviewFade: 140
  // A Nearby device card's progress catching up: live and dismissed, neither overshooting.
  readonly property int nearbyCardLive: 260
  readonly property int nearbyCardDismiss: 200
  // The phone panel's ringing pulse: one ring's expansion, and the wait between rings.
  readonly property int phoneRingPulse: 1200
  readonly property int phoneRingStagger: 600

  // The island's equaliser: each bar rises on its own tween, then falls, staggered across
  // the row so the set waves rather than jumps.
  readonly property int eqRiseBase: 320
  readonly property int eqRiseStagger: 60
  readonly property int eqFallBase: 400
  readonly property int eqFallStagger: 50

  // The island's small round gauge (a reading like battery or volume) and where its label sits.
  readonly property int islandGaugeSize: 48
  readonly property int islandGaugeRadius: 21
  readonly property int islandGaugeLabelY: 38

  // The lock screen's two cross-fades, fitted frame by frame at 60 fps; neither is a morph.
  // One progress drives blur and veil (tracking within 0.02); content lags in and leads out.
  readonly property int lockInClock: 70
  readonly property int lockInLogin: 100
  readonly property int lockInContent: 280
  readonly property int lockOutClock: 20
  readonly property int lockOutContent: 180
  // The date, time and field slide as they fade: the time trails the date by lockStagger going in and leads it
  // coming out; the travel is in the lock canvas's reference units (LockView scales it).
  readonly property int lockStagger: 50
  readonly property int lockSlideTravel: 12

  // ---- the phone (Bar/PhoneSatellite.qml, Phone/PhonePanel.qml) ----

  // The satellite: a pill-tall disc this far off the right edge of whatever the island is
  // wearing, with the battery as a ring inside its rim.
  readonly property int phoneSatelliteSize: barHeight
  readonly property int phoneSatelliteGap: 8
  readonly property int phoneSatelliteGlyph: 14
  readonly property real phoneRingRadius: 15.5
  readonly property real phoneRingWidth: 2
  // At or below this, discharging, the ring and glyph turn love.
  readonly property int phoneLowBattery: 20
  // The satellite is a drop of liquid on a neck, not a spring: Motion.satelliteStep. Ryan, 2026-11-06:
  // "more physical liquid" (main's metaball bridge, a little exaggerated) and "surface tension"
  // (held back, then snapping free). Distances are px, rates 1/s or px/s^2; the sim runs in its own
  // time and reduce-motion skips it (the satellite snaps), so none of these go through duration().
  //
  // Unlike the island's morphs, the satellite settles into its dock with a little give: the dock
  // spring, damping ratio 0.7, which gives about 4.6% of a run it makes from rest (less here:
  // the disc arrives already near the dock).
  readonly property real phoneSpringOmega: 17
  readonly property real phoneSpringDamping: 0.7
  // How far past the dock the pull would take the disc if the neck did not hold it: the neck
  // stretches until it snaps, 8 px being a neck about as long again as the gap it ends on.
  readonly property real phoneReach: 8
  // The pull builds from this share of its strength to full over phoneRampTime ms, so the disc
  // starts slowly (the neck holds it) and speeds up as it stretches.
  readonly property real phoneRampFrom: 0.15
  readonly property int phoneRampTime: 140
  // The neck's pull back, per px of stretch from phoneTensionLead px before contact. Tuned with
  // phoneReach so the disc has all but stopped as the neck lets go (under 3 px/s), which keeps
  // the give at the dock under 1.5 px. The normal exit is the sim's stuck guard (the disc has
  // stopped beyond the dock gap), not the break gap: phoneBridgeBreak is a ceiling the neck
  // would snap at if the pull still carried the disc that far, and phoneMaxHold (ms) a last
  // resort. Tension of about 200 and up makes the neck stall until phoneMaxHold: the node test
  // "first snap before 400 ms" fails there, so retune with it.
  readonly property real phoneTension: 148
  readonly property real phoneTensionLead: 10
  readonly property int phoneMaxHold: 600
  // The neck is a ball of this radius rolling between pill and disc (Shaders/satellite.frag): it
  // thins as they part and would pinch off at about 10 px, with phoneBridgeBreak (px of clear gap)
  // where the sim would snap it, a little past the 8 px dock gap and longer than main's 6 (a ceiling: see phoneTension).
  readonly property real phoneNeckK: 5.1
  readonly property real phoneBridgeBreak: 9.5
  // A neck re-forming on contact swells in over this long (ms), not in one frame.
  readonly property int phoneNeckOn: 50
  // Coming in: the pull on a loose disc, px/s^2, and what is added as the gap closes (squared),
  // with a little drag; then, joined, a critically damped spring home.
  readonly property real phonePull0: 500
  // The same when a panel takes the island or the disc is clicked: it is wanted in now, so it
  // sets off at once rather than gathering way (the gap closes in about 80 ms, not 170).
  readonly property real phonePull0Taken: 2600
  readonly property real phonePull1: 7000
  readonly property real phonePullDrag: 6
  readonly property real phoneMergeOmega: 22
  // The ends of a snapped neck recoil: they start this fast (1/s of their length), ringing a
  // little (damping 0.55) so they overshoot into rounded tips and are gone in about 150 ms. They
  // reach phoneStubLength px past their bodies at first and are phoneStubRadius px thick.
  readonly property real phoneStubOmega: 30
  readonly property real phoneStubDamping: 0.55
  readonly property real phoneStubKick: 25
  readonly property real phoneStubLength: 4.75
  readonly property real phoneStubRadius: 1.4
  // The pill's end swells by this much (px) when the disc is drawn in at speed phoneBulgeVRef
  // (px/s) or more, and relaxes with a lightly damped spring in about 200 ms.
  readonly property real phoneBulge: 2.5
  readonly property real phoneBulgeOmega: 30
  readonly property real phoneBulgeDamping: 0.45
  readonly property real phoneBulgeVRef: 200
  // Rests within this many px of its end (so the settling hand-off to the snapped grid is not
  // chasing a tail).
  readonly property real phoneRestEps: 0.05
  // How far back into its retreat a clicked satellite is before the panel grows, as satellite
  // progress: as it touches the pill, so the panel grows out as the disc sinks in; at half way,
  // the disc was home and the pill had swelled and settled before anything grew. The panel is
  // asked for on the click and held until here (Bar/PhoneSatellite.qml): its first frame stalls
  // every window for a frame or more, and asked for here that froze the disc in mid flight.
  readonly property real phoneOpenAt: 0.7

  // The panel (board "Phone panel"): the phone drawn on the left, a 3 x 2 grid beside it (readings
  // above, stacked control tiles for the actions below) with the grid's foot on the phone's, so
  // the card is the phone and its inset, top and bottom. One rhythm: 20 round the card and
  // between the phone and the grid, 16 from the header to the grid, 12 between tiles and inside
  // them, 8 from a badge to its words.
  readonly property int phoneWidth: panelColumnWidth
  readonly property int phoneRadius: panelRadius
  readonly property int phoneInset: 20
  readonly property int phoneDeviceWidth: 112
  readonly property int phoneDeviceHeight: 224
  readonly property int phoneDeviceRadius: 9
  readonly property int phoneScreenInset: 4
  readonly property int phoneScreenRadius: 5
  readonly property int phoneStatusLeft: phoneInset + phoneDeviceWidth + phoneInset
  readonly property int phoneRowHeight: 44
  readonly property real phoneCaptionSize: 11.5
  // The header: the name's box top puts its cap top on the phone's top edge; the status line sits
  // 4 px under the name's box.
  readonly property int phoneNameTop: 16
  readonly property int phoneStatusTop: 40
  // On the lock screen the date is 11 px at 0.9, and the disc that opens the wallpaper picker
  // sits at the foot of the screen, on its axis, with the notification stubs 8 above it. The
  // camera gets a hairline ring so it shows on a black picture.
  readonly property int phoneDateSize: 11
  readonly property int phoneDiscSize: 32
  readonly property int phoneDiscBottom: 10
  readonly property real phoneCameraRingAlpha: 0.2
  readonly property real phoneDiscRingAlpha: 0.22
  // A reading (battery, mobile, Wi-Fi): flat, 72 tall, a bare glyph beside its label (the glyph
  // row's top, the value's top), and an ink wash that lifts it off the card.
  readonly property int phoneReadingHeight: 72
  readonly property int phoneReadingGlyphTop: 14
  readonly property int phoneReadingValueTop: 38
  readonly property int phoneReadingGlyphGap: 7
  readonly property int phoneReadingBarHeight: 3
  readonly property real phoneReadingWashAlpha: 0.03
  readonly property real phoneReadingValueAlpha: 0.8
  // Browse's tile and glyph take the note's gold while the phone refuses it.
  readonly property real phoneBlockedOutlineAlpha: 0.5
  readonly property real phoneBlockedGlyphAlpha: 0.9
  readonly property real phoneActionGlyphAlpha: 0.9
  // The note Browse leaves when the phone refuses: 36 tall, 12 under the grid, 12 inside, and the
  // card 48 taller while it is up.
  readonly property int phoneNoteBarHeight: 36
  readonly property int phoneNoteBarGap: 12
  readonly property int phoneNotePad: 12
  // How many of the phone's notifications the preview's screen draws as stubs.
  readonly property int phoneNotesMax: 2

  // The keybinds cheatsheet (Keys/KeysSheet.qml). A keycap is 22 tall and 6 round, with 7 either
  // side of a word and 4 to the next cap. A line is 30 tall, its label 12 after the last cap; a
  // section's title has 24, sections sit 20 apart and columns 40. The card keeps 28 clear all
  // round, and its columns start 76 down, under the title.
  readonly property int keycapHeight: 22
  readonly property int keycapRadius: 6
  readonly property int keycapPad: 7
  readonly property int keycapGap: 4
  readonly property real keycapLabelSize: 11.5
  readonly property int keysRowHeight: 30
  readonly property int keysLabelSize: 13
  readonly property int keysChordGap: 12
  readonly property int keysTitleHeight: 24
  readonly property int keysSectionGap: 20
  readonly property int keysColumnGap: 40
  readonly property int keysPad: 28
  readonly property int keysHeaderHeight: 76
  // It comes up over a dimmed desktop, from a little under its size, at the press's pace: it is
  // a glance, so it has to be there by the time the eye is.
  readonly property real keysScrimAlpha: 0.45
  readonly property real keysGrowFrom: 0.97
  readonly property real keysOmega: pressOmega
}
