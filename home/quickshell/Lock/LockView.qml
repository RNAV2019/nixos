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
  property real rise: 0
  property bool away: false
  property bool leaving: false
  property bool flying: false
  property bool snapping: false

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

    Item {
      id: clockBox

      readonly property string time: Qt.formatDateTime(clock.date, "HH:mm")
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

      // The line as its glyphs advance, less the tracking the last one trails, by the height of
      // a digit: the digits' own box, which is what is centred and scaled.
      width: clockLine.advanceWidth - tracking
      height: bigDigit.tightBoundingRect.height
      x: Math.round(canvas.width / 2 + Bus.pillOffsetX * canvas.outputScale * (1 - t) - width / 2)
      y: fromY + (toY - fromY) * t - height / 2
      transformOrigin: Item.Center
      scale: fromScale + (1 - fromScale) * t
      opacity: canvas.swap
      visible: opacity > 0

      Item {
        id: plate

        x: -clockBox.pad
        y: -clockBox.pad
        width: Math.ceil(clockBox.width) + 2 * clockBox.pad
        height: Math.ceil(clockBox.height) + 2 * clockBox.pad

        // The digits as outlines, filled: text this big is otherwise a small distance field
        // blown up (lumpy curves) or a raster with the panel's subpixel fringes. Never shown as
        // it is; the two textures below are taken from it. The geometry renderer does not
        // antialias (and the curve renderer draws nothing on a lock surface, see
        // StrokeIcon.curve), so the texture the glass reads is multisampled.
        Shape {
          id: outlines

          anchors.fill: parent
          preferredRendererType: Shape.GeometryRenderer

          ShapePath {
            fillColor: "white"
            strokeColor: "transparent"
            strokeWidth: -1

            PathText {
              id: clockFace

              x: clockBox.pad
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

        ShaderEffectSource {
          id: glyphTexture

          sourceItem: outlines
          hideSource: true
          samples: 4
          textureSize: Qt.size(plate.width, plate.height)
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

        // The digits' coverage blurred over the bevel's depth: the glass reads how near the
        // outline is, and which way it faces, off this.
        MultiEffect {
          id: softCover

          anchors.fill: parent
          source: ShaderEffectSource {
            sourceItem: outlines
            textureSize: Qt.size(Math.ceil(plate.width / 2), Math.ceil(plate.height / 2))
          }
          blurEnabled: true
          blur: 1
          blurMax: Math.max(2, Math.round(clockBox.digits * Theme.lockGlassBevel))
          autoPaddingEnabled: false
        }

        ShaderEffectSource {
          id: softTexture

          sourceItem: softCover
          hideSource: true
          textureSize: Qt.size(Math.ceil(plate.width / 2), Math.ceil(plate.height / 2))
          visible: false
        }

        // What lies behind the plate, wherever the flight has put it and at whatever size:
        // the glass looks through at this. Half size and mipmapped; the glass softens it.
        ShaderEffectSource {
          id: backdropTexture

          readonly property real spanX: plate.width * clockBox.scale
          readonly property real spanY: plate.height * clockBox.scale

          sourceItem: groundLayer
          sourceRect: Qt.rect(clockBox.x + clockBox.width / 2 - spanX / 2, clockBox.y + clockBox.height / 2 - spanY / 2, spanX, spanY)
          textureSize: Qt.size(Math.ceil(plate.width / 2), Math.ceil(plate.height / 2))
          mipmap: true
          visible: false
        }

        // The shadow: the digits in black, blurred and dropped.
        MultiEffect {
          y: clockBox.digits * Theme.lockClockShadowDrop
          width: plate.width
          height: plate.height
          source: shadowTexture
          opacity: Theme.lockClockShadowAlpha
          colorization: 1
          colorizationColor: "black"
          blurEnabled: true
          blur: 1
          blurMax: Math.max(2, Math.round(clockBox.digits * Theme.lockClockShadowBlur))
          autoPaddingEnabled: true
        }

        // The digits as frosted glass (Shaders/lockglass.frag).
        ShaderEffect {
          anchors.fill: parent

          property var glyphs: glyphTexture
          property var soft: softTexture
          property var backdrop: backdropTexture
          property size itemSize: Qt.size(width, height)
          property real bevel: clockBox.digits * Theme.lockGlassBevel
          property real rim: Math.max(1.5, clockBox.digits * Theme.lockGlassRim)
          property real bend: clockBox.digits * Theme.lockGlassBend
          property real soften: Theme.lockGlassSoften
          property real lighten: Theme.lockGlassLighten
          property real milk: Theme.lockGlassMilk
          property real shine: Theme.lockGlassShine
          property real solid: clockBox.solid
          property point light: Qt.point(Theme.lockGlassLightX, Theme.lockGlassLightY)
          property point washCentre: Qt.point(clockBox.pad + clockBox.width * Theme.lockClockWashX, clockBox.pad + clockBox.height * Theme.lockClockWashY)
          property size washRadii: Qt.size(clockBox.width * Theme.lockClockWashWidth / 2, clockBox.height * Theme.lockClockWashHeight / 2)
          property real washAngle: Theme.lockClockWashAngle * Math.PI / 180
          property real washCore: Theme.lockClockWashCore
          property real washDepth: Theme.lockClockWashDepth
          property color ink: Theme.lockTextPrimary
          property color tint: Theme.accent

          fragmentShader: Qt.resolvedUrl("../Shaders/lockglass.frag.qsb")
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
