import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Hyprland
import qs.Commons
import qs.Services

// The lock screen's picture, and nothing else: no session lock, no PAM, no
// watchdog - those live in the host. Everything here is hosted twice, by the
// real session-lock surface in Lock.qml and by the IPC preview in
// LockPreview.qml, so every visual change can be rehearsed on a live desktop
// before it ever has to work on a screen that can lock you out.
//
// The ground is the blurred wallpaper and the veil over it, which move
// together. The two content tiers ride their own clocks either side of it.
Item {
  id: view

  // Host-driven state. password is what the dot row draws; submittedPassword
  // never reaches this file - the field wipes the frame Enter lands, while
  // the conversation the host feeds keeps the copy.
  property string password: ""
  property string status: ""
  property bool statusIsError: false
  property bool busy: false
  // False until the first keystroke. The recording draws no field before it:
  // a centred hint floats where the pill will be, and the pill then fades in
  // around the first dot. It stays up from there on, through Authenticating
  // and the reset after it.
  property bool inputStarted: false
  property real ground: 0
  property real clockAlpha: 0
  property real loginAlpha: 0

  // The screen this view draws on - the lock surface's or the preview's.
  property var outputScreen

  signal passwordEdited(string text)
  signal accepted

  readonly property string userName: {
    var name = Quickshell.env("USER") || Quickshell.env("LOGNAME") || "";
    if (name.length > 0)
      return name;
    // Neither is set under some session managers; the home directory is named
    // after the account either way.
    var home = Quickshell.env("HOME") || "";
    return home.substring(home.lastIndexOf("/") + 1);
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.BlankCursor
    acceptedButtons: Qt.NoButton
  }

  // The blur and the veil composite as one texture before they fade, so the
  // ramp cross-fades a finished frosted screen over the desktop rather than
  // fading each layer onto the other's half-drawn output.
  Item {
    id: groundLayer

    anchors.fill: parent
    opacity: view.ground
    layer.enabled: true

    // Overscan and clip MultiEffect's transparent edge samples.
    Item {
      anchors.fill: parent
      clip: true

      Image {
        id: blurSource

        anchors.fill: parent
        anchors.margins: -Theme.lockBlurMax * 2
        source: Wallpapers.url
        fillMode: Image.PreserveAspectCrop
        cache: false
        asynchronous: false
        // Expose this layer as MultiEffect's texture source.
        layer.enabled: true
      }

      MultiEffect {
        anchors.fill: blurSource
        source: blurSource
        visible: blurSource.status === Image.Ready
        blurEnabled: true
        // The radius rides the same progress as the veil, as the recording's
        // does: measured as sharpness over contrast, which the veil cannot
        // touch, its radius tracks the veil to within 0.02 of its travel in
        // both directions. The per-frame re-render is only paid across the
        // two short fade windows.
        blur: view.ground
        blurMax: Theme.lockBlurMax
        blurMultiplier: 1
      }
    }

    Rectangle {
      anchors.fill: parent
      color: Theme.lockVeilColor
      opacity: Theme.lockVeilOpacity
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

    // The board draws 1080 units tall, so one unit is this many device
    // pixels and the whole block keeps its proportions on any panel.
    readonly property real ui: height / 1080

    function u(v) {
      return Math.round(v * ui);
    }

    width: view.width * outputScale
    height: view.height * outputScale
    transformOrigin: Item.TopLeft
    scale: 1 / outputScale

    Text {
      id: date

      anchors.horizontalCenter: parent.horizontalCenter
      y: canvas.u(Theme.lockDateTop)
      opacity: view.clockAlpha

      // The recording's own order - "Thursday, September 3" - pinned so the
      // user's locale cannot put the day first.
      text: Qt.formatDate(clock.date, "dddd, MMMM d")
      color: Theme.lockTextSecondary
      font.family: Theme.uiFont
      font.weight: Theme.weightRegular
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
      font.weight: Theme.weightSemi
      font.pixelSize: canvas.u(Theme.lockClockSize)
      renderType: Text.QtRendering
    }

    Item {
      id: login

      anchors.horizontalCenter: parent.horizontalCenter
      y: canvas.u(Theme.lockAvatarTop)
      width: canvas.u(Theme.lockFieldWidth)
      height: canvas.u(Theme.lockFieldTop + Theme.lockFieldHeight - Theme.lockAvatarTop)
      opacity: view.loginAlpha

      Rectangle {
        id: avatar

        anchors.horizontalCenter: parent.horizontalCenter
        width: canvas.u(Theme.lockAvatarSize)
        height: width
        radius: width / 2

        // The recording's login cluster is neutral: a white translucency
        // with a lighter ring, over the veil.
        color: Qt.rgba(1, 1, 1, Theme.lockAvatarFill)
        border.width: Math.max(1, Theme.lockStrokeWidth * canvas.ui)
        border.color: Qt.rgba(1, 1, 1, Theme.lockAvatarStroke)

        Text {
          anchors.centerIn: parent
          text: Icons.person
          color: "white"
          font.family: Theme.iconFont
          font.pixelSize: canvas.u(Theme.lockAvatarGlyphSize)
          renderType: Text.QtRendering
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: canvas.u(Theme.lockUserTop - Theme.lockAvatarTop)

        text: view.userName
        color: "white"
        font.family: Theme.uiFont
        font.weight: Theme.weightMedium
        font.pixelSize: canvas.u(Theme.lockUserSize)
        renderType: Text.QtRendering
      }

      Rectangle {
        id: field

        anchors.horizontalCenter: parent.horizontalCenter
        y: canvas.u(Theme.lockFieldTop - Theme.lockAvatarTop)
        width: canvas.u(Theme.lockFieldWidth)
        height: canvas.u(Theme.lockFieldHeight)
        radius: canvas.u(Theme.lockFieldRadius)

        // The recording shows no pill until the first keystroke; the reveal
        // from then on - through Authenticating and the reset - never comes
        // back down.
        opacity: view.inputStarted ? 1 : 0
        Behavior on opacity {
          NumberAnimation {
            duration: Theme.lockFieldReveal
            easing.type: Easing.OutQuad
          }
        }

        color: Qt.rgba(1, 1, 1, Theme.lockFieldFill)
        border.width: Math.max(1, Theme.lockStrokeWidth * canvas.ui)
        border.color: Qt.rgba(1, 1, 1, Theme.lockFieldStroke)

        TextInput {
          id: input

          anchors.fill: parent

          focus: true
          enabled: !view.busy
          // The dots are drawn as fixed geometry beside this, so the field
          // itself renders nothing.
          echoMode: TextInput.NoEcho
          color: "transparent"
          cursorVisible: false
          cursorDelegate: Item {}

          text: view.password
          onTextChanged: view.passwordEdited(text)
          onAccepted: view.accepted()
        }

        // Whatever the conversation last said, or the reset's prompt. Left
        // aligned, so the caret leading it sits where the first dot would:
        // the recording draws the caret at 16 in from the field edge and the
        // text 7 further in, in both the busy state and the one after it.
        Text {
          anchors.left: parent.left
          anchors.leftMargin: canvas.u(Theme.lockTextInset)
          anchors.right: parent.right
          anchors.rightMargin: canvas.u(Theme.lockTextInset)
          anchors.verticalCenter: parent.verticalCenter
          visible: view.inputStarted && input.text.length === 0

          text: {
            if (view.busy)
              return "Authenticating....";
            if (view.statusIsError)
              return view.status;
            return "Enter Password";
          }
          color: view.statusIsError ? Theme.love : Theme.lockFieldState
          elide: Text.ElideRight
          font.family: Theme.uiFont
          font.weight: Theme.weightRegular
          font.pixelSize: canvas.u(Theme.lockFieldTextSize)
          font.italic: view.statusIsError
          renderType: Text.QtRendering
        }

        // Dots then caret, left-aligned, so the caret is always at the
        // insertion point and trails the last dot by the dot's own gap - the
        // recording's row: a dot at 16 in, the next at 28, the caret at 40.
        Row {
          anchors.left: parent.left
          anchors.leftMargin: canvas.u(Theme.lockDotInset)
          anchors.verticalCenter: parent.verticalCenter
          spacing: 0

          Repeater {
            model: 64

            Item {
              id: slot

              readonly property bool filled: index < input.text.length

              width: filled ? canvas.u(Theme.lockDotSize + Theme.lockDotGap) : 0
              // Every child of the row is the caret's height, so the row
              // lines them up without anchors, which a positioner ignores.
              height: canvas.u(Theme.lockCaretHeight)

              Behavior on width {
                NumberAnimation {
                  duration: Theme.lockDotPop
                  easing.type: Easing.OutQuad
                }
              }

              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: canvas.u(Theme.lockDotSize)
                height: width
                radius: width / 2
                color: "white"

                scale: slot.filled ? 1 : 0
                opacity: slot.filled ? 1 : 0

                Behavior on scale {
                  NumberAnimation {
                    duration: Theme.lockDotPop
                    easing.type: slot.filled ? Easing.OutQuad : Easing.InQuad
                  }
                }

                Behavior on opacity {
                  NumberAnimation {
                    duration: Theme.lockDotPop
                  }
                }
              }
            }
          }

          Rectangle {
            id: caret

            width: Math.max(1, canvas.u(Theme.lockCaretWidth))
            height: canvas.u(Theme.lockCaretHeight)
            radius: width / 2
            color: Theme.lockCaretColor
            // Up from the first keystroke on, busy included: the recording
            // never drops it while the conversation runs. Hide rather than
            // stop the blink: a stopped animation leaves the opacity wherever
            // the last frame put it.
            visible: view.inputStarted

            SequentialAnimation on opacity {
              loops: Animation.Infinite
              running: true
              PropertyAction {
                value: 1
              }
              PauseAnimation {
                duration: 530
              }
              PropertyAction {
                value: 0
              }
              PauseAnimation {
                duration: 530
              }
            }
          }
        }
      }

      // The fresh state has no pill at all: a centred hint floats where the
      // field will be, and goes the frame the first dot lands.
      Text {
        anchors.horizontalCenter: field.horizontalCenter
        anchors.verticalCenter: field.verticalCenter
        visible: !view.inputStarted

        text: "Press Any Key to Enter Password"
        color: Theme.lockFieldHint
        font.family: Theme.uiFont
        font.weight: Theme.weightRegular
        font.pixelSize: canvas.u(Theme.lockFieldTextSize)
        renderType: Text.QtRendering
      }
    }

    // Kept from the surface this replaces; the recording does not draw it.
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: canvas.u(Theme.lockNowPlayingBottom)
      opacity: view.loginAlpha

      color: Theme.lockTextSecondary
      font.family: Theme.uiFont
      font.weight: Theme.weightMedium
      font.pixelSize: canvas.u(Theme.lockNowPlayingSize)
      renderType: Text.QtRendering
      text: {
        for (var i = 0; i < Mpris.players.values.length; i++) {
          var p = Mpris.players.values[i];
          if (p.playbackState === MprisPlaybackState.Stopped)
            continue;
          var title = p.trackTitle || "";
          var artist = p.trackArtist || "";
          if (title.length === 0)
            continue;
          return artist.length > 0 ? title + " - " + artist : title;
        }
        return "";
      }
    }
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }
}