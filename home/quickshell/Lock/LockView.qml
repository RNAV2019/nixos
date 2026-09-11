import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Services

// The lock screen's picture, and nothing else: no session lock, no PAM, no
// watchdog - those live in the host. Everything here is hosted twice, by the
// real session-lock surface in Lock.qml and by the IPC preview in
// LockPreview.qml, so every visual change can be rehearsed on a live desktop
// before it ever has to work on a screen that can lock you out.
//
// The current wallpaper is always mounted and opaque. Its blur increases into
// the locked state and decreases back to the regular session on unlock.
Item {
  id: view

  // Host-driven state. password is what the dot row draws; submittedPassword
  // never reaches this file - the field wipes the frame Enter lands, while
  // the conversation the host feeds keeps the copy.
  property string password: ""
  property string status: ""
  property bool statusIsError: false
  property bool busy: false
  // Retained as host state for the input flow; board 13 renders the field from
  // its first frame rather than waiting for a keystroke.
  property bool inputStarted: false
  property real ground: 0
  property real clockAlpha: 0
  property real loginAlpha: 0

  // The screen this view draws on - the lock surface's or the preview's.
  property var outputScreen
  property string backgroundSource: Wallpapers.url

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

    Rectangle {
      anchors.fill: parent
      color: Theme.base
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
      font.weight: Theme.weightBold
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

        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, Theme.lockAvatarFill)
        border.width: Math.max(1, Theme.lockStrokeWidth * canvas.ui)
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, Theme.lockAvatarStroke)

        Text {
          anchors.centerIn: parent
          text: view.userName.length > 0 ? view.userName.charAt(0).toUpperCase() : "?"
          color: Theme.accent
          font.family: Theme.uiFont
          font.weight: Theme.weightSemi
          font.pixelSize: canvas.u(Theme.lockAvatarGlyphSize)
          renderType: Text.QtRendering
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: canvas.u(Theme.lockUserTop - Theme.lockAvatarTop)

        text: view.userName
        color: Theme.lockTextPrimary
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

        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, Theme.lockFieldFill)
        border.width: Math.max(1, Theme.lockStrokeWidth * canvas.ui)
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, Theme.lockFieldStroke)

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

        // Keep the board's placeholder in the field from the first frame.
        Text {
          anchors.left: parent.left
          anchors.leftMargin: canvas.u(Theme.lockTextInset)
          anchors.right: parent.right
          anchors.rightMargin: canvas.u(Theme.lockTextInset)
          anchors.verticalCenter: parent.verticalCenter
          visible: input.text.length === 0

          text: {
            if (view.busy)
              return "Authenticating....";
            if (view.statusIsError)
              return view.status;
            return "Enter password";
          }
          color: view.statusIsError ? Theme.love : view.busy ? Theme.lockFieldState : Theme.lockFieldHint
          elide: Text.ElideRight
          font.family: Theme.uiFont
          font.weight: Theme.weightRegular
          font.pixelSize: canvas.u(Theme.lockFieldTextSize)
          font.italic: view.statusIsError
          renderType: Text.QtRendering
        }

        // Dots then caret, left-aligned, matching the board's caret inset.
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
            visible: true

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

    }
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }
}
