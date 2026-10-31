import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets
import qs.Commons
import qs.Ui

// The login pill (Penpot "T / Login pill"): the avatar, a title, the password and the submit
// disc in one 360 x 60 pill. The lock screen draws it with the account's name, and the polkit
// prompt with "<program> needs permission"; both host it and own what it says. The dots, the
// caret, the spinner and the shake are here, laid out in board units that `ui` scales (the lock
// screen's canvas is 1080 units tall; the island is 1:1).
Rectangle {
  id: root

  // Board units to pixels.
  property real ui: 1

  // Line one: the account's name, or who is asking.
  property string title: ""
  // The avatar is `facePath` when it loads, else the first letter of `initial`.
  property string facePath: ""
  property int faceRevision: 0
  property string initial: ""

  // What is typed, kept by the host: it sees every edit and may clear the field.
  property string password: ""
  // Line two while the field is empty.
  property string placeholder: "Password"
  // The latest try was refused, with the words for line two. Shown until the next key.
  property bool failed: false
  property string status: ""
  // An answer is out and nothing has come back: the disc spins and the field takes no more.
  property bool busy: false
  // Whether the pill paints its own ground and outline. A host that is itself the shape (the
  // island) has both already, and only the refusal's outline is drawn over it.
  property bool framed: true

  readonly property bool hasText: input.text.length > 0
  readonly property bool showError: root.failed && !root.hasText && !root.busy
  // How far the shake has carried the pill; a host may carry what hangs under it along.
  readonly property real shakeX: shake.x

  signal passwordEdited(string text)
  signal accepted
  // Every key press and release before the field takes it, for a host that watches modifiers.
  signal keyPressed
  signal keyReleased

  function u(v) {
    return Math.round(v * root.ui);
  }

  function focusInput() {
    input.forceActiveFocus();
  }

  // Three swings across the travel, over Theme.lockShake.
  function shakeOnce() {
    if (!Theme.reduceMotion)
      shakeAnimation.restart();
  }

  implicitWidth: u(Theme.lockPillWidth)
  implicitHeight: u(Theme.lockPillHeight)
  radius: height / 2

  color: root.framed ? Theme.surface : "transparent"
  border.width: Math.max(1, Math.round(root.ui))
  border.color: root.showError ? Qt.rgba(Theme.love.r, Theme.love.g, Theme.love.b, Theme.lockErrorOutline) : root.framed ? Theme.surfaceOutline : "transparent"

  Behavior on border.color {
    ColorAnimation {
      duration: Theme.duration(Theme.lockStateFade)
    }
  }

  transform: Translate {
    id: shake
  }

  SequentialAnimation {
    id: shakeAnimation

    readonly property real travel: root.u(Theme.lockShakeTravel)
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

  TextInput {
    id: input

    anchors.fill: parent

    focus: true
    // Read-only rather than disabled while a try is out, so it keeps the focus it needs when PAM
    // asks again.
    readOnly: root.busy
    // The dots are fixed geometry beside this, so the field itself renders nothing.
    echoMode: TextInput.NoEcho
    color: "transparent"
    cursorVisible: false
    cursorDelegate: Item {}
    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase

    Accessible.role: Accessible.EditableText
    Accessible.name: root.placeholder
    Accessible.passwordEdit: true

    text: root.password
    onTextChanged: root.passwordEdited(text)
    onAccepted: root.accepted()

    Keys.onPressed: function (event) {
      root.keyPressed();
      event.accepted = false;
    }
    Keys.onReleased: function (event) {
      // Caps Lock's own state lands after its press, so a host asks again on the release.
      root.keyReleased();
      event.accepted = false;
    }
  }

  Rectangle {
    id: avatar

    x: root.u(Theme.lockPillInset)
    anchors.verticalCenter: parent.verticalCenter
    width: root.u(Theme.lockAvatarSize)
    height: width
    radius: width / 2
    color: Theme.overlay

    // ~/.face links out of the store to ~/nixos/profile.jpg. The query is bumped on every
    // change so a replaced picture reloads under the same name; cache is off for the same reason.
    ClippingRectangle {
      anchors.fill: parent
      radius: width / 2
      color: "transparent"
      visible: face.status === Image.Ready

      Image {
        id: face

        anchors.fill: parent
        source: root.facePath !== "" ? "file://" + root.facePath + "?" + root.faceRevision : ""
        sourceSize.width: width
        sourceSize.height: height
        fillMode: Image.PreserveAspectCrop
        cache: false
        asynchronous: false
        smooth: true
        mipmap: true
      }
    }

    Text {
      anchors.centerIn: parent
      visible: face.status !== Image.Ready
      text: root.initial.length > 0 ? root.initial.charAt(0).toUpperCase() : "?"
      color: Theme.accent
      font.family: Theme.uiFont
      font.weight: Theme.weightSemi
      font.pixelSize: root.u(Theme.lockAvatarGlyphSize)
      renderType: Text.QtRendering
    }
  }

  Text {
    id: titleLabel

    x: root.u(Theme.lockTextLeft)
    y: root.u(Theme.lockNameTop)
    width: submit.x - x - root.u(Theme.lockPillInset)
    elide: Text.ElideRight

    text: root.title
    color: Theme.lockTextPrimary
    font.family: Theme.uiFont
    font.weight: Theme.weightSemi
    font.pixelSize: root.u(Theme.lockNameSize)
    renderType: Text.QtRendering
  }

  // Line two: the dots and caret while typing, otherwise the placeholder or the state.
  Item {
    id: lineTwo

    x: root.u(Theme.lockTextLeft)
    y: root.u(Theme.lockLineTwoTop)
    width: titleLabel.width
    height: root.u(Theme.lockLineTwoHeight)

    Text {
      anchors.left: parent.left
      anchors.leftMargin: root.busy || root.showError ? 0 : root.u(Theme.lockPlaceholderInset)
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.hasText

      text: {
        if (root.busy)
          return "Checking…";
        if (root.showError)
          return root.status;
        return root.placeholder;
      }
      color: root.showError ? Theme.love : Theme.inkSecondary
      elide: Text.ElideRight
      font.family: Theme.uiFont
      font.weight: root.showError ? Theme.weightMedium : Theme.weightRegular
      font.pixelSize: root.u(Theme.lockLineTwoSize)
      renderType: Text.QtRendering
    }

    Row {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 0
      visible: !root.busy && !root.showError

      Repeater {
        model: 64

        Item {
          id: slot

          readonly property bool filled: index < input.text.length

          width: filled ? root.u(Theme.lockDotSize + Theme.lockDotGap) : 0
          // Every child is the caret's height, so the positioner lines them up
          // without anchors, which it would ignore.
          height: root.u(Theme.lockCaretHeight)

          Behavior on width {
            NumberAnimation {
              duration: Theme.duration(Theme.lockDotPop)
              easing.type: Easing.OutQuad
            }
          }

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: root.u(Theme.lockDotSize)
            height: width
            radius: width / 2
            color: Theme.lockTextPrimary

            scale: slot.filled ? 1 : 0
            opacity: slot.filled ? 1 : 0

            Behavior on scale {
              NumberAnimation {
                duration: Theme.duration(Theme.lockDotPop)
                easing.type: slot.filled ? Easing.OutQuad : Easing.InQuad
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

      Rectangle {
        id: caret

        width: Math.max(1, root.u(Theme.lockCaretWidth))
        height: root.u(Theme.lockCaretHeight)
        radius: width / 2
        color: Theme.lockCaretColor

        SequentialAnimation on opacity {
          loops: Animation.Infinite
          running: !Theme.reduceMotion
          PropertyAction {
            value: 1
          }
          PauseAnimation {
            duration: Theme.lockCaretBlinkMs
          }
          PropertyAction {
            value: 0
          }
          PauseAnimation {
            duration: Theme.lockCaretBlinkMs
          }
        }
      }
    }
  }

  // The submit disc: a plate until there is something to send, then the accent.
  Rectangle {
    id: submit

    readonly property bool live: root.hasText && !root.busy

    anchors.right: parent.right
    anchors.rightMargin: root.u(Theme.lockPillInset)
    anchors.verticalCenter: parent.verticalCenter
    width: root.u(Theme.lockSubmitSize)
    height: width
    radius: width / 2
    color: live ? Theme.accent : Theme.overlay

    Behavior on color {
      ColorAnimation {
        duration: Theme.duration(Theme.lockStateFade)
      }
    }

    StrokeIcon {
      anchors.centerIn: parent
      visible: !root.busy
      size: root.u(Theme.lockArrowSize)
      strokeWidth: 2 * root.ui
      color: submit.live ? Theme.inkOnAccent : Theme.inkTertiary
      path: IconPaths.arrowRight
    }

    // Checking: a quarter arc turning over a faint track.
    Shape {
      id: spinner

      anchors.centerIn: parent
      width: root.u(Theme.lockSpinnerSize)
      height: width
      visible: root.busy
      antialiasing: true
      preferredRendererType: Shape.CurveRenderer

      readonly property real stroke: 2 * root.ui
      readonly property real r: (width - stroke) / 2

      ShapePath {
        fillColor: "transparent"
        strokeColor: Qt.rgba(Theme.inkTertiary.r, Theme.inkTertiary.g, Theme.inkTertiary.b, 0.35)
        strokeWidth: spinner.stroke

        PathAngleArc {
          centerX: spinner.width / 2
          centerY: spinner.height / 2
          radiusX: spinner.r
          radiusY: spinner.r
          startAngle: 0
          sweepAngle: 360
        }
      }

      ShapePath {
        fillColor: "transparent"
        strokeColor: Theme.accent
        strokeWidth: spinner.stroke
        capStyle: ShapePath.RoundCap

        PathAngleArc {
          centerX: spinner.width / 2
          centerY: spinner.height / 2
          radiusX: spinner.r
          radiusY: spinner.r
          startAngle: -90
          sweepAngle: 90
        }
      }

      RotationAnimator on rotation {
        from: 0
        to: 360
        duration: Theme.lockSpinnerTurn
        loops: Animation.Infinite
        running: spinner.visible && !Theme.reduceMotion
      }
    }

    MouseArea {
      anchors.fill: parent
      enabled: submit.live
      cursorShape: Qt.PointingHandCursor
      onClicked: root.accepted()
    }
  }
}
