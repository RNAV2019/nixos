import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Services
import qs.Ui

// The lock screen's picture only: no session lock, no PAM, no watchdog. Hosted by
// Lock.qml and the IPC preview in LockPreview.qml so visuals can be rehearsed live.
Item {
  id: view

  // submittedPassword never reaches this file: the field wipes the frame Enter lands.
  property string password: ""
  property string status: ""
  property bool statusIsError: false
  property bool busy: false
  // Board 13 draws the field from its first frame rather than waiting for a keystroke.
  property bool inputStarted: false
  property real ground: 0
  property real clockAlpha: 0
  property real loginAlpha: 0

  // The screen this view draws on - the lock surface's or the preview's.
  property var outputScreen
  property string backgroundSource: Wallpapers.url

  signal passwordEdited(string text)
  signal accepted

  // The account and its picture, and Caps Lock, come from Services (Account, Keyboard).
  readonly property string facePath: Account.facePath
  readonly property int faceRevision: Account.faceRevision
  readonly property string displayName: Account.displayName

  readonly property bool capsLock: Keyboard.capsLock
  // Lets the IPC preview rehearse the caption without a physical Caps Lock.
  property bool forceCapsLock: false

  function checkCapsLock() {
    Keyboard.check();
  }

  Timer {
    interval: Theme.lockCapsPollMs
    running: view.visible && view.loginAlpha > 0
    repeat: true
    triggeredOnStart: true
    onTriggered: view.checkCapsLock()
  }

  // The lock hides the pointer; moving the mouse brings it back so the submit disc can be
  // reached, and the next key hides it again. The first report is the surface entry, not a move.
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

  // Board 13's layout is in board units; scale the canvas into Qt's.
  Item {
    id: canvas

    // Qt rounds devicePixelRatio, so use Hyprland's fractional scale.
    readonly property var monitor: view.outputScreen ? Hyprland.monitorFor(view.outputScreen) : null

    readonly property real outputScale: {
      if (monitor && monitor.scale > 0)
        return monitor.scale;
      return view.outputScreen ? view.outputScreen.devicePixelRatio : 1;
    }

    // The board draws 1080 units tall, so the block keeps its proportions on any panel.
    readonly property real ui: height / 1080

    function u(v) {
      return Math.round(v * ui);
    }

    width: view.width * outputScale
    height: view.height * outputScale
    transformOrigin: Item.TopLeft
    scale: 1 / outputScale

    Rectangle {
      anchors.fill: parent
      color: Theme.canvas
      z: -2
    }

    Item {
      id: groundLayer

      anchors.fill: parent
      clip: true
      z: -1

      Image {
        id: blurSource

        anchors.fill: parent
        source: view.backgroundSource
        fillMode: Image.PreserveAspectCrop
        cache: false
        asynchronous: false
        visible: false
        layer.enabled: true
      }

      MultiEffect {
        anchors.fill: parent
        source: blurSource
        visible: blurSource.status === Image.Ready
        blurEnabled: true
        blur: view.ground * Theme.lockBlur
        blurMax: Theme.lockBlurMax
        blurMultiplier: 1
      }

      Rectangle {
        anchors.fill: parent
        color: Theme.lockVeilColor
        opacity: Theme.lockVeilOpacity * view.ground
      }
    }

    Text {
      id: date

      anchors.horizontalCenter: parent.horizontalCenter
      y: canvas.u(Theme.lockDateTop)
      opacity: view.clockAlpha

      // Keep the board's weekday-first date order independent of locale.
      text: Qt.formatDate(clock.date, "dddd, MMMM d")
      color: Theme.lockTextPrimary
      font.family: Theme.uiFont
      font.weight: Theme.weightMedium
      font.pixelSize: canvas.u(Theme.lockDateSize)
      // Avoid RGB subpixel fringes from native text rendering.
      renderType: Text.QtRendering
    }

    Text {
      id: time

      anchors.horizontalCenter: parent.horizontalCenter
      y: canvas.u(Theme.lockClockTop)
      opacity: view.clockAlpha

      text: Qt.formatDateTime(clock.date, "HH:mm")
      color: Theme.lockTextPrimary
      font.family: Theme.displayFont
      font.weight: Theme.weightBold
      font.pixelSize: canvas.u(Theme.lockClockSize)
      renderType: Text.QtRendering
    }

    // Board 13: one pill carrying the avatar, the name, the password and the submit disc,
    // with the Caps Lock caption hanging under it. States are board 13b's five.
    Item {
      id: login

      anchors.horizontalCenter: parent.horizontalCenter
      y: canvas.u(Theme.lockPillTop)
      width: canvas.u(Theme.lockPillWidth)
      height: canvas.u(Theme.lockPillHeight + Theme.lockCaptionGap) + caption.height
      opacity: view.loginAlpha

      LoginPill {
        id: pill

        width: parent.width
        height: canvas.u(Theme.lockPillHeight)
        ui: canvas.ui

        title: view.displayName
        initial: view.displayName
        facePath: view.facePath
        faceRevision: view.faceRevision
        password: view.password
        failed: view.statusIsError
        status: view.status
        busy: view.busy

        onPasswordEdited: text => view.passwordEdited(text)
        onAccepted: view.accepted()
        onKeyPressed: {
          view.pointerShown = false;
          view.checkCapsLock();
        }
        // Caps Lock's own state lands after its press, so ask again on the release.
        onKeyReleased: view.checkCapsLock()
      }

      Connections {
        target: view

        function onStatusIsErrorChanged() {
          if (view.statusIsError)
            pill.shakeOnce();
        }
      }

      Row {
        id: caption

        anchors.horizontalCenter: parent.horizontalCenter
        y: pill.height + canvas.u(Theme.lockCaptionGap)
        spacing: canvas.u(Theme.lockCaptionGlyphGap)
        opacity: view.capsLock || view.forceCapsLock ? 1 : 0

        // Hangs from the pill, so it shakes with it.
        transform: Translate {
          x: pill.shakeX
        }

        Behavior on opacity {
          NumberAnimation {
            duration: Theme.duration(Theme.lockStateFade)
          }
        }

        StrokeIcon {
          anchors.verticalCenter: parent.verticalCenter
          size: canvas.u(Theme.lockCaptionGlyph)
          strokeWidth: 1.5 * canvas.ui
          color: Theme.gold
          path: IconPaths.capsLock
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "Caps Lock is on"
          color: Theme.gold
          font.family: Theme.uiFont
          font.weight: Theme.weightMedium
          font.pixelSize: canvas.u(Theme.lockCaptionSize)
          renderType: Text.QtRendering
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
