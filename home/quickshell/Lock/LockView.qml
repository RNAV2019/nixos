import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Services
import qs.Ui

// The lock screen's picture only: no session lock, no PAM, no watchdog. Hosted by
// Lock.qml and the IPC preview in LockPreview.qml so visuals can be rehearsed live.
//
// It is the island's own lock: the pill starts exactly where the bar's island rests, the clock
// flies out of it to the middle of the screen while the pill drops and narrows to a lock glyph,
// a typed password grows the pill a dot at a time, and a good one plays it all back
// (Lock/LockReveal.qml holds the clocks, Commons/Theme.qml the measurements).
Item {
  id: view

  // submittedPassword never reaches this file: the field wipes the frame Enter lands.
  property string password: ""
  property bool busy: false
  // Counts the tries that were refused; each one shakes the pill and turns the padlock red.
  property int refusals: 0
  // Counts the tries that were never judged; each one turns the padlock gold, without the shake.
  property int faults: 0

  // The reveal's clocks (Lock/LockReveal.qml).
  property real ground: 0
  property real flight: 0
  property real swell: 0
  property real wobble: 0
  property real rise: 0
  property bool away: false
  property bool leaving: false
  property bool flying: false
  property bool snapping: false

  // A time to show instead of the clock's, "HH:mm" (the rehearsal stage's, to play a change of
  // minute on demand); empty follows the clock.
  property string timeOverride: ""

  // The screen this view draws on - the lock surface's or the preview's.
  property var outputScreen
  property string backgroundSource: Wallpapers.url
  // The background is a capture of the desktop, so it carries the bar's own island.
  property bool captured: false
  // The capture could not be read (an output plugged in while locked has none): the wallpaper
  // stands in, as it does for the boot lock.
  property bool captureLost: false
  readonly property bool standing: captured && !captureLost

  onBackgroundSourceChanged: captureLost = false

  // Up while the reveal waits for this view's first frame; `presented` says it is on screen.
  property bool armed: false

  signal passwordEdited(string text)
  signal accepted
  signal presented

  Connections {
    target: view.Window.window
    enabled: view.armed
    ignoreUnknownSignals: true

    function onFrameSwapped() {
      view.presented();
    }
  }

  // The colour the padlock wears while refusalHold runs.
  property color verdictColor: Theme.love

  onRefusalsChanged: {
    if (refusals <= 0)
      return;
    verdictColor = Theme.love;
    refusalHold.restart();
    if (!Theme.reduceMotion)
      shakeAnimation.restart();
  }

  onFaultsChanged: {
    if (faults <= 0)
      return;
    verdictColor = Theme.gold;
    refusalHold.restart();
  }

  // The lock hides the pointer; moving the mouse brings it back, and the next key hides it
  // again. The first report is the surface entry, not a move.
  property bool pointerShown: false
  property point pointerOrigin: Qt.point(-1, -1)

  MouseArea {
    anchors.fill: parent
    cursorShape: view.pointerShown ? Qt.ArrowCursor : Qt.BlankCursor
    acceptedButtons: Qt.NoButton
    hoverEnabled: true

    onPositionChanged: function (mouse) {
      if (view.pointerOrigin.x < 0) {
        view.pointerOrigin = Qt.point(mouse.x, mouse.y);
        return;
      }
      if (Math.abs(mouse.x - view.pointerOrigin.x) + Math.abs(mouse.y - view.pointerOrigin.y) > 4)
        view.pointerShown = true;
    }
  }

  // The password field: it holds the keyboard and draws nothing; the dots are the pill's.
  TextInput {
    id: input

    // A point, under everything: a field's own I-beam must not show over the lock.
    width: 1
    height: 1
    opacity: 0
    focus: true
    // Read-only rather than disabled while a try is out, so it keeps the focus it needs when PAM
    // asks again.
    readOnly: view.busy || view.leaving
    echoMode: TextInput.NoEcho
    color: "transparent"
    cursorVisible: false
    cursorDelegate: Item {}
    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase

    Accessible.role: Accessible.EditableText
    Accessible.name: "Password"
    Accessible.passwordEdit: true

    text: view.password
    onTextChanged: view.passwordEdited(text)
    onAccepted: view.accepted()

    Keys.onPressed: function (event) {
      view.pointerShown = false;
      event.accepted = false;
    }
  }

  // Laid out in device pixels and scaled back, so the pill lands on the same pixels as the
  // bar's island and the glyphs are crisp under a fractional scale.
  Item {
    id: canvas

    // The screen's devicePixelRatio is rounded up to a whole number, so use Hyprland's
    // fractional scale, or failing that the window's own ratio (as Ui/FrostedSurface.qml does).
    readonly property var monitor: view.outputScreen ? Hyprland.monitorFor(view.outputScreen) : null
    readonly property real windowRatio: view.QsWindow.window && view.QsWindow.window.devicePixelRatio > 0 ? view.QsWindow.window.devicePixelRatio : 0

    readonly property real outputScale: {
      if (monitor && monitor.scale > 0)
        return monitor.scale;
      if (windowRatio > 0)
        return windowRatio;
      return view.outputScreen ? view.outputScreen.devicePixelRatio : 1;
    }

    // A window covering the bar: the capture then has no island in it to stand on.
    readonly property bool covered: !!monitor && !!monitor.activeWorkspace && monitor.activeWorkspace.hasFullscreen === true

    // Logical px to this canvas's device px, on the grid.
    function px(v) {
      return Math.round(v * outputScale);
    }

    function ramp(v, from, to) {
      return Math.max(0, Math.min(1, (v - from) / (to - from)));
    }

    width: view.width * outputScale
    height: view.height * outputScale
    transformOrigin: Item.TopLeft
    scale: 1 / outputScale

    // ---- the island, as the bar draws it and as the lock leaves it ----

    // On the device-pixel grid, as the island's own width is (Ui/FrostedSurface.qml snap).
    readonly property real islandWidth: px(Theme.islandCollapsedWidth(Media.active, Recorder.recording, Privacy.camera, Privacy.microphone))
    readonly property int shownDots: Math.min(view.password.length, Theme.lockIslandMaxDots)
    // The dots as drawn. Enter wipes the password at once, but the row is held as it stood
    // while its dots fade where they are (the pill closes over them), and is emptied after.
    property int heldDots: 0
    property bool dotsSnapping: false
    readonly property bool dotsLit: !view.busy && !view.leaving

    onShownDotsChanged: {
      if (dotsLit)
        heldDots = shownDots;
    }
    onDotsLitChanged: {
      if (!dotsLit) {
        dotsClear.restart();
        return;
      }
      // Lit again before the row was emptied (a quick refusal): the old dots must not return.
      dotsClear.stop();
      dotsSnapping = true;
      heldDots = shownDots;
      dotsSnapping = false;
    }

    Timer {
      id: dotsClear

      interval: Theme.duration(Theme.lockDotPop) + 20
      onTriggered: {
        // Typed again since (a refusal came back first): the row is live, leave it.
        if (canvas.dotsLit && canvas.shownDots > 0)
          return;
        canvas.dotsSnapping = true;
        canvas.heldDots = canvas.shownDots;
        canvas.dotsSnapping = false;
      }
    }
    readonly property real dotsWidth: (2 * Theme.lockIslandPad + Theme.lockIslandDot + (shownDots - 1) * Theme.lockIslandDotPitch) * outputScale
    readonly property real lockedWidth: {
      if (view.busy || view.leaving)
        return px(Theme.lockIslandBusyWidth);
      return Math.max(px(Theme.lockIslandWidth), shownDots > 0 ? Math.round(dotsWidth) : 0);
    }

    // How far the big clock has taken over from the island's own.
    readonly property real swap: ramp(view.flight, Theme.lockClockSwapFrom, Theme.lockClockSwapTo)

    MorphSpring {
      id: widthSpring

      label: "lock.pill.w"
      target: view.away ? canvas.lockedWidth : canvas.islandWidth
      animate: !view.snapping
      // To the island and back out of it the width runs past and settles, as the video's does;
      // typing and checking it only follows.
      readonly property bool closing: view.busy || view.leaving

      omega: !view.away ? Theme.lockWidthOmegaOut : closing ? Theme.lockWidthOmegaBusy : view.flying ? Theme.lockWidthOmegaIn : Theme.lockWidthOmegaType
      damping: !view.away ? Theme.lockWidthDampingOut : view.flying && !closing ? Theme.lockWidthDampingIn : Theme.morphDamping
    }

    Rectangle {
      anchors.fill: parent
      color: Theme.canvas
      z: -2
    }

    // ---- the ground: the capture, softly blurred, under the scrim ----

    Item {
      id: groundLayer

      anchors.fill: parent
      clip: true
      z: -1

      // Drawn through its own layer's effect rather than hidden behind a separate one: what is
      // inside a hidden item is never redrawn, and the patch below comes and goes.
      Item {
        id: blurSource

        anchors.fill: parent
        visible: shot.status === Image.Ready
        layer.enabled: true
        layer.effect: MultiEffect {
          blurEnabled: true
          blur: view.ground * Theme.lockBlur
          blurMax: Theme.lockBlurMax
          blurMultiplier: 1
        }

        Image {
          id: shot

          anchors.fill: parent
          source: view.captureLost ? Wallpapers.url : view.backgroundSource
          fillMode: Image.PreserveAspectCrop
          cache: false
          asynchronous: false

          onStatusChanged: {
            if (status === Image.Error && view.captured && !view.captureLost)
              view.captureLost = true;
          }
        }

        // The wallpaper as the desktop shows it, never drawn itself: the patch below reads it.
        Image {
          id: wallpaperImage

          anchors.fill: parent
          visible: false
          source: view.standing ? Wallpapers.url : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
        }

        // The capture carries the bar's island, its shadow and the phone beside it; left in,
        // they would stay behind as a smudge when the pill drops. Over the stretch they reach,
        // the island's pill and the satellite are filled with the wallpaper (nothing else is
        // ever under the bar) and the island's shadow is lifted off what it fell on, a window's
        // top edge included (Shaders/lockpatch.frag); the rest of the stretch is the capture
        // untouched. It comes as the blur comes up, and goes as it clears.
        ShaderEffect {
          id: patch

          readonly property real room: Theme.surfaceShadowRoom * canvas.outputScale
          readonly property var satellite: view.outputScreen ? Bus.satelliteFor(view.outputScreen.name) : null
          readonly property bool budded: !!satellite && !!satellite.disc && satellite.p > 0.05
          readonly property rect stretch: Qt.rect(x, y, width, height)

          x: Math.round(pill.restX - room)
          y: 0
          width: Math.round(canvas.islandWidth + 2 * room + canvas.px(Theme.phoneSatelliteSize * 2))
          height: Math.round(pill.restY + pill.height + room)
          visible: view.standing && !canvas.covered && view.ground > 0 && wallpaperImage.status === Image.Ready

          property var capture: ShaderEffectSource {
            sourceItem: shot
            sourceRect: patch.stretch
          }
          property var wallpaper: ShaderEffectSource {
            sourceItem: wallpaperImage
            sourceRect: patch.stretch
          }
          property size itemSize: Qt.size(width, height)
          property point boxOrigin: Qt.point(Math.round(pill.restX) - x, Math.round(pill.restY) - y)
          property size boxSize: Qt.size(canvas.islandWidth, pill.height)
          property real radius: pill.height / 2
          property real sigma: Theme.surfaceShadowSigma * canvas.outputScale
          property point offset: Qt.point(0, Theme.surfaceShadowOffsetY * canvas.outputScale)
          property real strength: Theme.surfaceShadowAlpha
          property point discCentre: budded ? Qt.point(satellite.disc.x * canvas.outputScale - x, satellite.disc.y * canvas.outputScale - y) : Qt.point(0, 0)
          property real discRadius: budded ? satellite.disc.z * canvas.outputScale : 0
          property real aa: 1
          property real amount: canvas.ramp(view.ground, 0, 0.6)

          fragmentShader: Qt.resolvedUrl("../Shaders/lockpatch.frag.qsb")
        }
      }

      Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: Theme.lockScrim * view.ground
      }

      Rectangle {
        width: parent.width
        height: parent.height * Theme.lockScrimTopReach
        opacity: view.ground

        gradient: Gradient {
          GradientStop {
            position: 0
            color: Qt.rgba(0, 0, 0, Theme.lockScrimTop)
          }
          GradientStop {
            position: 1
            color: Qt.rgba(0, 0, 0, 0)
          }
        }
      }

      Rectangle {
        y: parent.height - height
        width: parent.width
        height: parent.height * Theme.lockScrimBottomReach
        opacity: view.ground

        gradient: Gradient {
          GradientStop {
            position: 0
            color: Qt.rgba(0, 0, 0, 0)
          }
          GradientStop {
            position: 1
            color: Qt.rgba(0, 0, 0, Theme.lockScrimBottom)
          }
        }
      }
    }

    // ---- the pill ----

    Rectangle {
      id: pill

      // Where the bar's island rests (Bar/Bar.qml), in this canvas's pixels.
      readonly property real restX: (canvas.width - canvas.islandWidth) / 2 + Bus.pillOffsetX * canvas.outputScale
      readonly property real restY: (Theme.barMarginTop + Bus.pillOffsetY) * canvas.outputScale

      x: Math.round((canvas.width - width) / 2 + Bus.pillOffsetX * canvas.outputScale)
      y: Math.round(restY + view.rise * Theme.lockIslandDrop * canvas.outputScale)
      width: widthSpring.value
      height: canvas.px(Theme.barHeight)
      radius: height / 2
      color: Theme.surface
      // Over a window that covered the bar there was no island to take over from, so it comes
      // up with the ground instead of appearing.
      opacity: view.standing && canvas.covered ? canvas.ramp(view.ground, 0, 0.6) : 1

      transform: Translate {
        id: shake
      }

      DropShadow {
        radius: pill.radius
        sigma: Theme.surfaceShadowSigma * canvas.outputScale
        offsetY: Theme.surfaceShadowOffsetY * canvas.outputScale
        room: Theme.surfaceShadowRoom * canvas.outputScale
      }

      // The island's face, as the bar draws it: its clock and its marks, laid out in the bar's
      // own pixels. The clock gives way to the big one as the flight leaves; the marks go with
      // the ground.
      Item {
        id: face

        width: pill.width / canvas.outputScale
        height: Theme.barHeight
        transformOrigin: Item.TopLeft
        scale: canvas.outputScale

        // The same clock the bar's island carries (Bar/Island.qml), placed as it places it, so
        // the one stands exactly where the other did.
        RollingClock {
          id: islandClock

          x: (parent.width - width) / 2
          y: (parent.height - height) / 2
          transformOrigin: Item.Center
          scale: Theme.islandClockSize / Theme.islandDisplaySize
          opacity: 1 - canvas.swap
          visible: opacity > 0
          text: clockBox.time
          color: Theme.text
          font.family: Theme.uiFont
          font.pixelSize: Theme.islandDisplaySize
          font.weight: Theme.weightSemi
        }

        PillMarks {
          anchors.fill: parent
          clockLeft: parent.width / 2 - islandClock.width * islandClock.scale / 2
          clockRight: parent.width / 2 + islandClock.width * islandClock.scale / 2
          mediaActive: Media.active
          playing: Media.playing
          recording: Recorder.recording
          camera: Privacy.camera
          microphone: Privacy.microphone
          opacity: 1 - canvas.ramp(view.ground, 0, 0.6)
          visible: leftExtent + rightExtent > 0 && opacity > 0
        }
      }

      // Locked: the glyph, in love for a moment after a refusal.
      StrokeIcon {
        id: glyph

        readonly property bool wanted: !view.leaving && !view.busy && canvas.shownDots === 0
        property real shown: wanted ? 1 : 0

        anchors.centerIn: parent
        size: canvas.px(Theme.lockIslandGlyph)
        strokeWidth: 1.7 * canvas.outputScale
        // The geometry renderer the lock needs (see StrokeIcon.curve) does not antialias; a
        // multisampled layer does it for it.
        curve: false
        layer.enabled: true
        layer.samples: 4
        path: IconPaths.lockOutline
        color: refusalHold.running ? view.verdictColor : Theme.text
        opacity: shown * canvas.ramp(view.flight, Theme.lockGlyphFrom, Theme.lockGlyphTo)
        scale: Theme.glyphSwapDip + (1 - Theme.glyphSwapDip) * shown
        visible: opacity > 0

        Behavior on shown {
          Morph {
            duration: Theme.duration(Theme.lockStateFade)
          }
        }

        Behavior on color {
          Tint {}
        }
      }

      // The password: a dot a character, the row centred, so each new one pushes the rest left
      // as the pill grows around them.
      Row {
        id: dots

        anchors.centerIn: parent
        height: pill.height

        Repeater {
          model: Theme.lockIslandMaxDots

          Item {
            id: slot

            required property int index

            readonly property bool filled: index < canvas.heldDots
            readonly property bool lit: filled && canvas.dotsLit

            width: filled ? Theme.lockIslandDotPitch * canvas.outputScale : 0
            height: dots.height

            Behavior on width {
              enabled: !view.snapping && !canvas.dotsSnapping

              NumberAnimation {
                duration: Theme.duration(Theme.lockDotPop)
                easing.type: Easing.OutQuad
              }
            }

            Rectangle {
              anchors.centerIn: parent
              width: Theme.lockIslandDot * canvas.outputScale
              height: width
              radius: width / 2
              color: Theme.text

              scale: slot.lit ? 1 : 0.4
              opacity: slot.lit ? 1 : 0
              visible: opacity > 0

              Behavior on scale {
                NumberAnimation {
                  duration: Theme.duration(Theme.lockDotPop)
                  easing.type: slot.lit ? Easing.OutQuad : Easing.InQuad
                }
              }

              Behavior on opacity {
                NumberAnimation {
                  duration: Theme.duration(Theme.lockDotPop)
                }
              }
            }
          }
        }
      }
    }

    // Three swings across the travel, over Theme.lockShake.
    SequentialAnimation {
      id: shakeAnimation

      readonly property real travel: Theme.lockShakeTravel * canvas.outputScale
      readonly property int step: Theme.lockShake / 6

      NumberAnimation {
        target: shake
        property: "x"
        to: -shakeAnimation.travel
        duration: shakeAnimation.step
        easing.type: Easing.OutQuad
      }
      NumberAnimation {
        target: shake
        property: "x"
        to: shakeAnimation.travel
        duration: shakeAnimation.step * 2
        easing.type: Easing.InOutQuad
      }
      NumberAnimation {
        target: shake
        property: "x"
        to: -shakeAnimation.travel
        duration: shakeAnimation.step * 2
        easing.type: Easing.InOutQuad
      }
      NumberAnimation {
        target: shake
        property: "x"
        to: 0
        duration: shakeAnimation.step
        easing.type: Easing.InQuad
      }
    }

    Timer {
      id: refusalHold

      interval: Theme.lockRefusalHold
    }

    // ---- the clock in flight ----

    // The island clock's digits and the big clock's, measured, so the flight starts at exactly
    // the size and place of the one it takes over from.
    TextMetrics {
      id: islandDigit

      font.family: Theme.uiFont
      font.pixelSize: Theme.islandClockSize
      font.weight: Theme.weightSemi
      font.features: ({
          "tnum": 1
        })
      text: "0"
    }

    TextMetrics {
      id: bigDigit

      font: clockFace.font
      text: "0"
    }

    TextMetrics {
      id: clockLine

      font: clockFace.font
      text: clockBox.time
    }

    // Where each character of a line starts, as the line is shaped (kerning, the tracking, the
    // raised colon between digits): the cursor positions of a field never shown.
    TextInput {
      id: penProbe

      visible: false
      font: clockFace.font
    }

    // The exact height of a line's ink, read off its outlines: FontMetrics rounds the ink's
    // edges out to whole pixels, which is enough to lay out a line but not to put one
    // character back exactly where the whole line had it.
    Shape {
      id: inkProbe

      visible: false

      ShapePath {
        strokeColor: "transparent"
        strokeWidth: -1

        PathText {
          id: inkProbeText

          font: rollFont.font
        }
      }

      // How far above the baseline the top of `text`'s ink stands, from a fixed origin. A
      // circumflex set after it stands above every digit and ends above the foot of the raised
      // colon (which floats clear of the baseline), so it takes the top and leaves the bottom:
      // the height it adds is how much lower the text's own top is. The mark's own top is the
      // same every time and cancels in every difference this is used for.
      function topOf(text) {
        inkProbeText.text = text;
        const own = inkProbe.boundingRect.height;
        inkProbeText.text = text + "\u02c6";
        return inkProbe.boundingRect.height - own;
      }
    }

    // The clock's face for one character on its own; `case` gives the colon the raised form it
    // takes between digits in the line.
    FontMetrics {
      id: rollFont

      font.family: Theme.lockClockFont
      font.weight: Theme.lockClockWeight
      font.pixelSize: clockBox.fontSize
      font.letterSpacing: clockBox.tracking
      font.features: ({
          "case": 1
        })
    }

    Item {
      id: clockBox

      readonly property string time: view.timeOverride !== "" ? view.timeOverride : Qt.formatDateTime(clock.date, "HH:mm")
      readonly property real digits: canvas.height * Theme.lockClockDigits
      readonly property int fontSize: Math.round(digits / Theme.lockClockDigitRatio)
      readonly property real tracking: fontSize * Theme.lockClockTracking
      // The share of the way from the pill to the middle; it may run a little past either end
      // of the scale, but never sits above the pill.
      readonly property real t: Math.max(0, view.flight)
      readonly property real fromScale: islandDigit.tightBoundingRect.height * canvas.outputScale / Math.max(1, bigDigit.tightBoundingRect.height)
      readonly property real fromY: pill.restY + pill.height / 2
      readonly property real toY: canvas.height / 2
      // Room round the digits for the ink that overhangs its advance and for the shadow.
      readonly property real pad: Math.ceil(digits * Theme.lockClockPad)
      // Plain ink in and out of the pill, glass once it is clear of it.
      readonly property real solid: 1 - canvas.ramp(t, Theme.lockGlassFrom, Theme.lockGlassTo)
      // Its size, which swells past rest and settles, and its wobble: taller and narrower
      // while it travels, squat and wide as it lands. Nothing wobbles while it is still ink.
      readonly property real size: fromScale + (1 - fromScale) * Math.max(0, view.swell)
      // The lead is toward wherever the flight is headed, so on the way home its sign turns.
      readonly property real stretch: Math.max(-Theme.lockWobbleMax, Math.min(Theme.lockWobbleMax, Theme.lockWobble * view.wobble * (view.leaving ? -1 : 1))) * (1 - solid)
      readonly property real sizeX: size * (1 - stretch)
      readonly property real sizeY: size * (1 + stretch)

      // The line as its glyphs advance, less the tracking the last one trails: its width.
      readonly property real lineWidth: clockLine.advanceWidth - tracking

      // Where a line this wide starts, centred as the box is.
      function leftFor(w) {
        return Math.round(canvas.width / 2 + Bus.pillOffsetX * canvas.outputScale * (1 - t) - w / 2);
      }

      // ---- a new minute rolling in ----
      //
      // Only the characters that changed turn over, upward, as on the pill's clock
      // (Ui/RollingClock.qml), on a longer clock for digits this big. At rest the line is one
      // PathText (clockFace); for the roll each character is drawn on its own, put exactly where
      // its line puts it, so the roll starts on the old line's pixels and ends on the new one's.
      // SF Compact's figures are proportional (a 1 is narrow) and the line is kerned, so a new
      // minute can change where every character stands and how wide the line is: the
      // characters that stay slide to their new places as the line re-centres, and a changing one
      // turns over in a slot that slides and resizes with them (rollLayout).
      //
      // A changing digit slides up and out of the row whole, as its successor slides in from
      // below a row's height behind it, so the two never meet; the row's top and bottom edges
      // fade them. The glass is read off the digits' coverage (a clip would draw a rim along the
      // cut, a faded or overlapping coverage turns to milky film or one merged blob), so the
      // coverage is never touched: the fade is applied to what the glass draws (rollWindow), and
      // the digits on their way out are drawn into a layer of their own (rollLeavingInk), shaded
      // apart from the line coming in (rollLineInk), so nothing they pass near takes their shape.
      //
      // It rolls only on the glass at rest. Into and out of the pill, and with the lock just
      // up, the time changes where it stands, as the pill's clock does under the lock.
      readonly property bool rests: view.away && !view.flying && !view.leaving && !view.snapping && solid === 0
      // The time the line last settled on, the line rolling away (empty at rest), its width,
      // and its characters with where each stands in both lines.
      property string shownTime: ""
      property string rollFrom: ""
      readonly property bool rolling: rollFrom !== ""
      property real rollFromWidth: 0
      property var rollSlots: []
      // Each line's baseline in the plate, less a constant that every use cancels.
      property real rollFromBase: 0
      property real rollToBase: 0
      // The roll's clock in ms, and how long it runs: the last digit to go, plus its own roll.
      property real rollClock: 0
      property int rollSpan: 0
      // Room the plate keeps on either side of the new line while the roll moves and its slots,
      // held wider than the new line has them (rollLayout), reach out past it. Its textures are
      // laid out on the plate, and a change of its size shifts their grid under the glass (the
      // blur's own smaller copies too), so the room comes and goes only while the digits move:
      // none on the roll's first frame, which is still the old line as it stood, and none once
      // the line overhangs the new one by no more than 3 px a side, so the last frames are laid
      // out exactly as the line at rest and handing back to it changes no pixel.
      property real rollRoomWanted: 0
      readonly property real rollRoom: rolling && rollClock > 0 && rollStretch.total / 2 > 3 ? rollRoomWanted : 0
      // What the slots' widths add up to before the roll, less what they add up to after it.
      property real rollSpread: 0
      // The colour channel each layer is drawn in, which is the one its glass reads (`pick`): the
      // line being shown (red, which the white line at rest also fills, so the same glass reads
      // either) and the digits rolling away (green).
      readonly property color rollLineInk: Qt.rgba(1, 0, 0, 1)
      readonly property color rollLeavingInk: Qt.rgba(0, 1, 0, 1)
      // The face a character is drawn in on its own; `case` gives the colon the raised form it
      // takes between digits in the line.
      readonly property font rollFace: rollFont.font
      // The characters a roll can draw (Lock/RollGlyph.qml elements below): "HH:mm".
      readonly property int rollCapacity: 5
      // How far the characters that stay have slid to their places in the new line.
      readonly property real rollSlide: rollSpan > 0 ? 1 - Math.pow(1 - Math.min(1, rollClock / rollSpan), 3) : 1
      // The two lines' starts in the plate, as the box stands now.
      readonly property real rollFromLeft: pad + rollRoom + leftFor(rollFromWidth) - x
      readonly property real rollToLeft: pad + rollRoom + leftFor(lineWidth) - x
      // Where each slot starts in the plate now (`pen`) and how wide it is (`advance`). A slot is
      // as wide as the wider of its two characters (with the kerning against the next one) while
      // either is in the row, so no two characters ever come closer than a line at rest has
      // them: one that widens does so at the start, over lockClockRollWiden of a digit's roll,
      // before the new character is half way up into it; one that narrows does so only once its
      // old character, and the one to its right, have left the row, over the rest of the roll.
      // The line re-centres as its width changes. Each pen is the new line's, plus what the slots
      // before it are still wider than they will be, so the last frame is the new line exactly.
      // How much wider each slot is now than in the new line, and all of them together.
      readonly property var rollStretch: {
        const slots = rollSlots;
        const widen = 1 - Math.pow(1 - Math.min(1, rollClock / Math.max(1, Theme.lockClockRoll * Theme.lockClockRollWiden)), 3);
        const extra = [];
        let total = 0;
        for (let i = 0; i < slots.length; i++) {
          const q = slots[i];
          let lag = 1 - rollSlide;
          if (q.clearAt >= 0 && q.fromAdvance > q.toAdvance)
            lag = Math.pow(1 - Math.max(0, Math.min(1, (rollClock - q.clearAt) / (q.settleAt - q.clearAt))), 3);
          else if (q.clearAt >= 0)
            lag = 1 - widen;
          extra.push((q.fromAdvance - q.toAdvance) * lag);
          total += extra[i];
        }
        return {
          extra: extra,
          total: total
        };
      }
      readonly property var rollLayout: {
        const slots = rollSlots;
        const extra = rollStretch.extra;
        const total = rollStretch.total;
        // The two lines' starts differ by half the change of width and the rounding of each to
        // whole pixels; the rounding is slid away over the roll.
        const start = rollToLeft - total / 2 + (rollFromLeft - rollToLeft + rollSpread / 2) * (1 - rollSlide);
        const layout = [];
        let before = 0;
        for (let i = 0; i < slots.length; i++) {
          layout.push({
            pen: start + slots[i].toX + before,
            advance: slots[i].toAdvance + extra[i]
          });
          before += extra[i];
        }
        return layout;
      }

      // The row's window, in the plate's px down: nothing shows above rollWindow.x, all of it from
      // .y to .z, nothing below .w. Its edges lie in the room round the digits (pad), clear of
      // every digit's ink at rest and of the arriving digit's overshoot, so nothing at rest is
      // ever faded; the bottom edge sits just under the ink, and the top as low as the overshoot
      // allows. A changing digit travels a row and its room: it starts wholly below the plate and
      // ends wholly above it, so before and after its roll it is not in the plate's textures
      // at all (its blurred coverage would reach the digits beside it).
      readonly property real rollOvershoot: Theme.lockClockRollOvershoot
      readonly property real rollTravel: Math.ceil(height) + pad + 1
      readonly property real rollFade: Math.max(1, Math.min(Math.round(digits * Theme.lockClockRollFade), pad - Math.ceil(rollOvershoot * rollTravel) - 2))
      readonly property vector4d rollWindow: {
        const top = pad - Math.ceil(rollOvershoot * rollTravel) - 2;
        const bottom = pad + height + 2;
        return Qt.vector4d(top - rollFade, top, bottom, bottom + rollFade);
      }
      // No window: everything shows (at rest).
      readonly property vector4d openWindow: Qt.vector4d(-1e6, -1e6 + 1, 1e6, 1e6 + 1)
      // The overshoot is an OutBack curve's (Easing.OutBack): it runs this far past, 4s³/27(s+1)²
      // of the travel, once, and settles with no second swing.
      readonly property real rollBack: {
        let lo = 0;
        let hi = 4;
        for (let i = 0; i < 40; i++) {
          const s = (lo + hi) / 2;
          if (4 * s * s * s / (27 * (s + 1) * (s + 1)) < rollOvershoot)
            lo = s;
          else
            hi = s;
        }
        return lo;
      }

      // How far along its travel the changed digit `order` places from the right is (0 to 1,
      // a little past 1 on the way): the last digit goes first, each to its left a stagger later.
      function riseOf(order) {
        const t = Math.max(0, Math.min(1, (rollClock - order * Theme.lockClockRollStagger) / Math.max(1, Theme.lockClockRoll)));
        if (t <= 0)
          return 0;
        const u = t - 1;
        return 1 + (rollBack + 1) * u * u * u + rollBack * u * u;
      }

      // Where each character of `text` starts along the line, and where the line ends.
      function pensOf(text) {
        penProbe.text = text;
        const pens = [];
        for (let i = 0; i <= text.length; i++)
          pens.push(penProbe.positionToRectangle(i).x);
        return pens;
      }

      // The PathText rule below, less its line's own ink top: the baseline.
      function baseOf(text) {
        return pad + rollMetrics.tightBoundingRect(text).y - bigDigit.tightBoundingRect.y - inkProbe.topOf(text);
      }

      function settleRoll() {
        rollAnimation.stop();
        rollFrom = "";
        rollSlots = [];
        rollSpan = 0;
        rollClock = 0;
        rollRoomWanted = 0;
      }

      onTimeChanged: {
        const from = shownTime;
        settleRoll();
        shownTime = time;
        if (!rests || from === "" || from === time || from.length !== time.length || time.length > rollCapacity)
          return;

        const fromPens = pensOf(from);
        const toPens = pensOf(time);
        const slots = [];
        // Counted from the right: the changed digit's place in the ripple.
        let changed = 0;
        for (let i = time.length - 1; i >= 0; i--) {
          const turns = from.charAt(i) !== time.charAt(i);
          // The character whose leaving lets this slot narrow: its own, or (for one that stays,
          // whose kerning changes with its neighbour) the one to its right.
          const next = slots.length > 0 && slots[0].changed ? slots[0].order : -1;
          const gate = turns ? changed : next;
          slots.unshift({
            from: from.charAt(i),
            to: time.charAt(i),
            changed: turns,
            order: turns ? changed : 0,
            fromX: fromPens[i],
            toX: toPens[i],
            fromAdvance: fromPens[i + 1] - fromPens[i],
            toAdvance: toPens[i + 1] - toPens[i],
            fromTop: inkProbe.topOf(from.charAt(i)),
            toTop: inkProbe.topOf(time.charAt(i)),
            // When its old character has left the row (its travel first reaches 1 at
            // 1/(rollBack + 1) of its roll and stays past it), and when its own roll ends.
            clearAt: gate < 0 ? -1 : gate * Theme.lockClockRollStagger + Theme.lockClockRoll / (rollBack + 1),
            settleAt: gate < 0 ? -1 : gate * Theme.lockClockRollStagger + Theme.lockClockRoll
          });
          if (turns)
            changed++;
        }
        rollFromBase = baseOf(from);
        rollToBase = baseOf(time);
        rollFromWidth = rollMetrics.advanceWidth(from) - tracking;
        // The widest the line gets: every slot that widens has, none that narrows has yet.
        let widest = rollFromWidth;
        let spread = 0;
        for (const q of slots) {
          widest += Math.max(0, q.toAdvance - q.fromAdvance);
          spread += q.fromAdvance - q.toAdvance;
        }
        rollSpread = spread;
        rollRoomWanted = 4 * Math.ceil(Math.max(0, (widest - (rollMetrics.advanceWidth(time) - tracking)) / 2 + 2) / 4);
        rollSpan = Math.max(1, Theme.lockClockRoll + (changed - 1) * Theme.lockClockRollStagger);
        rollSlots = slots;
        rollFrom = from;
        rollAnimation.restart();
      }
      // Leaving mid-roll (an unlock): the new minute stands where it is.
      onRestsChanged: {
        if (!rests)
          settleRoll();
      }
      Component.onCompleted: shownTime = time

      FontMetrics {
        id: rollMetrics

        font: clockFace.font
      }

      NumberAnimation {
        id: rollAnimation

        target: clockBox
        property: "rollClock"
        from: 0
        to: clockBox.rollSpan
        duration: clockBox.rollSpan

        onFinished: clockBox.settleRoll()
      }

      // The digits' own box, which is what is centred and scaled: as wide as the line, by the
      // height of a digit. A minute rolling over takes the new line's box from its first step
      // (the plate keeps room round it for the old line, rollRoom).
      width: rolling && rollClock <= 0 ? rollFromWidth : lineWidth
      height: bigDigit.tightBoundingRect.height
      x: leftFor(width)
      y: fromY + (toY - fromY) * t - height / 2
      opacity: canvas.swap
      visible: opacity > 0

      transform: Scale {
        origin.x: clockBox.width / 2
        origin.y: clockBox.height / 2
        xScale: clockBox.sizeX
        yScale: clockBox.sizeY
      }

      Item {
        id: plate

        x: -clockBox.pad - clockBox.rollRoom
        y: -clockBox.pad
        width: Math.ceil(clockBox.width) + 2 * (clockBox.pad + clockBox.rollRoom)
        height: Math.ceil(clockBox.height) + 2 * clockBox.pad

        // The digits as outlines, filled: text this big is otherwise a small distance field
        // blown up (lumpy curves) or a raster with the panel's subpixel fringes. Never shown as
        // it is; the two textures below are taken from it. The geometry renderer does not
        // antialias (and the curve renderer draws nothing on a lock surface, see
        // StrokeIcon.curve), so the texture the glass reads is multisampled.
        Item {
          id: outlines

          anchors.fill: parent

          // The line at rest. Only faded out for a roll, never hidden, so its new outlines
          // are built while the roll plays and are there for the frame it hands back.
          Shape {
            anchors.fill: parent
            preferredRendererType: Shape.GeometryRenderer
            opacity: clockBox.rolling ? 0 : 1

            ShapePath {
              fillColor: "white"
              strokeColor: "transparent"
              strokeWidth: -1

              PathText {
                id: clockFace

                x: clockBox.pad + clockBox.rollRoom
                // PathText hangs the line from the top of its own ink, which a round digit
                // overshoots and a flat one does not; the difference is taken back, so the
                // baseline stays put whatever the time.
                y: clockBox.pad + clockLine.tightBoundingRect.y - bigDigit.tightBoundingRect.y
                text: clockBox.time
                font.family: Theme.lockClockFont
                font.weight: Theme.lockClockWeight
                font.pixelSize: clockBox.fontSize
                font.letterSpacing: clockBox.tracking
              }
            }
          }

          // A minute rolling over, a character at a time (Lock/RollGlyph.qml), in two layers:
          // the line being shown, which is every character standing in it or rising into it,
          // and the characters on their way out. Each layer is one path, as the line at rest is,
          // in its own colour channel (rollLineInk, rollLeavingInk), which its glass reads.
          Shape {
            anchors.fill: parent
            preferredRendererType: Shape.GeometryRenderer
            visible: clockBox.rolling

            ShapePath {
              fillColor: clockBox.rollLineInk
              strokeColor: "transparent"
              strokeWidth: -1

              RollGlyph {
                box: clockBox
                index: 0
                part: "line"
              }
              RollGlyph {
                box: clockBox
                index: 1
                part: "line"
              }
              RollGlyph {
                box: clockBox
                index: 2
                part: "line"
              }
              RollGlyph {
                box: clockBox
                index: 3
                part: "line"
              }
              RollGlyph {
                box: clockBox
                index: 4
                part: "line"
              }
              RollGlyph {
                box: clockBox
                index: 0
                part: "waiting"
              }
              RollGlyph {
                box: clockBox
                index: 1
                part: "waiting"
              }
              RollGlyph {
                box: clockBox
                index: 2
                part: "waiting"
              }
              RollGlyph {
                box: clockBox
                index: 3
                part: "waiting"
              }
              RollGlyph {
                box: clockBox
                index: 4
                part: "waiting"
              }
            }
          }

          Shape {
            anchors.fill: parent
            preferredRendererType: Shape.GeometryRenderer
            visible: clockBox.rolling

            ShapePath {
              fillColor: clockBox.rollLeavingInk
              strokeColor: "transparent"
              strokeWidth: -1

              RollGlyph {
                box: clockBox
                index: 0
                part: "leaving"
              }
              RollGlyph {
                box: clockBox
                index: 1
                part: "leaving"
              }
              RollGlyph {
                box: clockBox
                index: 2
                part: "leaving"
              }
              RollGlyph {
                box: clockBox
                index: 3
                part: "leaving"
              }
              RollGlyph {
                box: clockBox
                index: 4
                part: "leaving"
              }
            }
          }
        }

        // Twice the plate's size and multisampled: at rest every device pixel is the mean of a
        // 2x2 block of 4x-multisampled texels, 16 samples, so a shallow curve's antialiasing
        // ramp runs smooth instead of in the 4 steps the multisampling alone leaves. Mipmapped,
        // because in flight it is drawn at a few percent of its size and would otherwise
        // shimmer.
        ShaderEffectSource {
          id: glyphTexture

          sourceItem: outlines
          hideSource: true
          samples: 4
          mipmap: true
          textureSize: Qt.size(plate.width * 2, plate.height * 2)
          visible: false
        }

        // A quarter-size copy for the shadow, which is blurred anyway. Its own, because
        // MultiEffect pads the texture it is given.
        ShaderEffectSource {
          id: shadowTexture

          sourceItem: outlines
          textureSize: Qt.size(Math.ceil(plate.width / 4), Math.ceil(plate.height / 4))
          visible: false
        }

        // The digits' coverage blurred over about half a stroke: the glass reads each stroke's
        // dome off this, its height and which way it faces, and how near the outline is.
        MultiEffect {
          id: softCover

          anchors.fill: parent
          source: ShaderEffectSource {
            sourceItem: outlines
            textureSize: Qt.size(Math.ceil(plate.width / 2), Math.ceil(plate.height / 2))
          }
          blurEnabled: true
          blur: 1
          blurMax: Math.max(2, Math.min(64, Math.round(clockBox.digits * Theme.lockGlassBevel)))
          autoPaddingEnabled: false
        }

        // Kept in half floats: near a stroke's spine the dome's slope is a difference of a few
        // 8-bit levels, which the light on it would turn into streaks along the stroke.
        ShaderEffectSource {
          id: softTexture

          sourceItem: softCover
          hideSource: true
          format: ShaderEffectSource.RGBA16F
          textureSize: Qt.size(Math.ceil(plate.width / 2), Math.ceil(plate.height / 2))
          visible: false
        }

        // The desktop behind the plate (the blurred capture under the scrim: Ryan wanted to see
        // the desktop through the digits, not the bare wallpaper, 2026-11-12), wherever the
        // flight has put the plate and at whatever size. Half size; the glass blurs it a
        // little more.
        ShaderEffectSource {
          id: backdropTexture

          readonly property real spanX: plate.width * clockBox.sizeX
          readonly property real spanY: plate.height * clockBox.sizeY

          sourceItem: groundLayer
          sourceRect: Qt.rect(clockBox.x + clockBox.width / 2 - spanX / 2, clockBox.y + clockBox.height / 2 - spanY / 2, spanX, spanY)
          textureSize: Qt.size(Math.ceil(plate.width / 2), Math.ceil(plate.height / 2))
          visible: false
        }

        // While a minute rolls, the digits as much as the row's window shows of them
        // (Shaders/lockrollshadow.frag), which is what casts the shadow then: a digit sliding
        // out of the row takes its shadow with it. Only drawn while one rolls.
        ShaderEffect {
          id: rollShadow

          width: plate.width
          height: plate.height
          visible: clockBox.rolling

          property var source: shadowTexture
          property size itemSize: Qt.size(width, height)
          property vector4d window: clockBox.rollWindow

          fragmentShader: Qt.resolvedUrl("../Shaders/lockrollshadow.frag.qsb")
        }

        ShaderEffectSource {
          id: rollShadowTexture

          sourceItem: clockBox.rolling ? rollShadow : null
          hideSource: true
          textureSize: shadowTexture.textureSize
          visible: false
        }

        // The shadow: the digits in black, blurred and dropped.
        MultiEffect {
          y: clockBox.digits * Theme.lockClockShadowDrop
          width: plate.width
          height: plate.height
          source: clockBox.rolling ? rollShadowTexture : shadowTexture
          opacity: Theme.lockClockShadowAlpha
          colorization: 1
          colorizationColor: "black"
          blurEnabled: true
          blur: 1
          blurMax: Math.max(2, Math.round(clockBox.digits * Theme.lockClockShadowBlur))
          autoPaddingEnabled: true
        }

        // The digits as frosted jelly (Shaders/lockglass.frag), with their contact shadow: the
        // line, and while a minute rolls the digits on their way out, each layer read from its
        // own colour channel (rollLineInk, rollLeavingInk) and shaded on its own, so neither
        // takes the other's shape, and both seen through the row's window. At rest only the line
        // is drawn, as it always was.
        Repeater {
          model: 2

          ShaderEffect {
            required property int index

            anchors.fill: parent
            visible: index === 0 || clockBox.rolling

            property var glyphs: glyphTexture
            property var soft: softTexture
            property var backdrop: backdropTexture
            property size itemSize: Qt.size(width, height)
            property real bevel: softCover.blurMax
            property real rim: clockBox.digits * Theme.lockGlassRim
            property real feather: clockBox.digits * Theme.lockGlassFeather
            property real relief: Theme.lockGlassRelief
            property real bend: clockBox.digits * Theme.lockGlassBend
            property real soften: clockBox.digits * Theme.lockGlassSoften
            property real lighten: Theme.lockGlassLighten
            property real milk: Theme.lockGlassMilk
            property real vivid: Theme.lockGlassVivid
            property real glow: Theme.lockGlassGlow
            property real shine: Theme.lockGlassShine
            property real shade: Theme.lockGlassShade
            property real pool: Theme.lockGlassPool
            property real contact: Theme.lockClockContactAlpha
            property real drop: clockBox.digits * Theme.lockClockContactDrop
            property real solid: clockBox.solid
            property point light: Qt.point(Theme.lockGlassLightX, Theme.lockGlassLightY)
            property color ink: Theme.lockTextPrimary
            property vector4d pick: index === 0 ? Qt.vector4d(1, 0, 0, 0) : Qt.vector4d(0, 1, 0, 0)
            property vector4d window: clockBox.rolling ? clockBox.rollWindow : clockBox.openWindow
            // A contact shadow is cast by the stroke just above it, and shows as much as its
            // caster does.
            property real lag: drop + bevel / 2

            fragmentShader: Qt.resolvedUrl("../Shaders/lockglass.frag.qsb")
          }
        }
      }
    }
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Connections {
    target: Bus

    function onClockRefreshed() {
      clock.enabled = false;
      clock.enabled = true;
    }
  }
}
