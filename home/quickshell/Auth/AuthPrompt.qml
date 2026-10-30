import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Services
import qs.Ui

// The polkit prompt: the island grown into a card that asks for a password. It opens by
// itself when polkitd asks (Services/Polkit.qml), holds the keyboard exclusively until it is
// answered, and goes away on approval, Cancel, Escape, a lock, or polkitd withdrawing the
// request. Another panel taking the island only moves it aside; the request is still pending,
// so the card comes back when that panel lets go.
Variants {
  id: root

  model: Quickshell.screens

  IslandSurface {
    id: win

    key: "auth"
    exclusiveKeyboard: true
    // Only the card is a target: a click off it reaches whatever is below, and never answers
    // or dismisses a request.
    passThrough: true

    openWidth: Theme.panelWidth(modelData, Theme.authWidth)
    openHeight: win.openActionsTop + Theme.authActionHeight + Theme.authPadBottom
    openRadius: Theme.panelRadius

    // ---- which output, and when ----

    // The output that was focused when the request arrived, else the first one.
    readonly property bool mine: {
      var screens = Quickshell.screens;
      for (var i = 0; i < screens.length; i++) {
        if (screens[i].name === Polkit.screenName)
          return win.screen !== null && win.screen.name === Polkit.screenName;
      }
      return win.screen === screens[0];
    }

    // Another panel holds the island here. The request waits behind it, as the transients do
    // behind this one.
    readonly property bool blocked: {
      var holder = Bus.holderKey(Bus.lookup(Bus.islandHolders, win.screen ? win.screen.name : "", null));
      return holder !== "" && holder !== win.key && !Bus.isTransient(holder);
    }

    readonly property bool wanted: Polkit.pending && win.mine && !Bus.locking && !win.blocked

    onWantedChanged: evaluateLater.restart()
    onOpenChanged: {
      // Closed by anything but the answer (a panel on another output took the island): still
      // wanted, so it comes back.
      if (!win.open)
        evaluateLater.restart();
    }
    Component.onCompleted: evaluateLater.restart()

    // Decided a turn later, never inside the change that prompted it; see Ui/TransientSurface.qml.
    Timer {
      id: evaluateLater

      interval: 0
      onTriggered: {
        if (win.wanted && !win.open)
          win.show();
        else if (!win.wanted && win.open)
          win.hide();
      }
    }

    // ---- the request, as it is laid out ----

    readonly property var identity: Polkit.identities.length > 0 ? Polkit.identities[Polkit.selectedIndex] : null
    readonly property bool choosesIdentity: Polkit.identities.length > 1
    readonly property var rows: Polkit.detailRows

    // The message the card shows, for the line count and the text: polkit's own words, else a
    // plain line.
    readonly property string message: Polkit.message !== "" ? Polkit.message : "An application is asking for permission to continue."

    readonly property int messageHeight: Math.max(1, Math.min(Theme.authMessageLines, Math.round(messageText.contentHeight / Theme.authMessageLeading))) * Theme.authMessageLeading

    property bool detailsOpen: false
    readonly property bool canOpenDetails: win.rows.length > 0
    readonly property real plateTarget: win.detailsOpen && win.canOpenDetails ? Theme.authDetailsHeight + win.rows.length * Theme.authDetailsRowHeight + Theme.authDetailsPad : Theme.authDetailsHeight

    // The text under the pill: the error held from the last failed try, else what PAM said.
    readonly property string caption: Polkit.errorText !== "" ? Polkit.errorText : Polkit.notice
    readonly property bool captionIsError: Polkit.errorText !== "" || Polkit.noticeIsError
    readonly property real captionTarget: win.caption !== "" ? Theme.authPillGap + Theme.authCaptionHeight : 0

    // Both spring on the surface's own curve, so what sits below them rides down with the card
    // instead of jumping ahead of it.
    MorphSpring {
      id: plateSpring

      animate: win.open && !win.parked
      target: win.plateTarget
    }

    MorphSpring {
      id: captionSpring

      animate: win.open && !win.parked
      target: win.captionTarget
    }

    readonly property real plateTop: Theme.authMessageTop + win.messageHeight + Theme.authBlockGap
    readonly property real identityTop: win.plateTop + plateSpring.value + Theme.authPillGap
    readonly property real pillTop: win.identityTop + (win.choosesIdentity ? Theme.authIdentityHeight + Theme.authPillGap : 0)
    readonly property real captionTop: win.pillTop + Theme.lockPillHeight + Theme.authPillGap
    readonly property real actionsTop: win.pillTop + Theme.lockPillHeight + captionSpring.value + Theme.authActionTop

    // The same, at rest: what the card settles at. The springs above are what is drawn.
    readonly property real openActionsTop: win.plateTop + win.plateTarget + Theme.authPillGap + (win.choosesIdentity ? Theme.authIdentityHeight + Theme.authPillGap : 0) + Theme.lockPillHeight + win.captionTarget + Theme.authActionTop

    // ---- keyboard ----

    // 0 the field, 1 the details plate, 2 the identity chooser, 3 Cancel, 4 Authenticate.
    property int stop: 0

    readonly property var stops: {
      var list = [0];
      if (win.canOpenDetails)
        list.push(1);
      if (win.choosesIdentity)
        list.push(2);
      list.push(3);
      list.push(4);
      return list;
    }

    readonly property bool hasText: field.text.length > 0
    readonly property bool canSubmit: win.hasText && !Polkit.checking

    function focusStop(n) {
      win.stop = n;
      if (n === 0)
        field.forceActiveFocus();
      else
        catcher.forceActiveFocus();
    }

    function step(delta) {
      var i = win.stops.indexOf(win.stop);
      if (i < 0)
        i = 0;
      focusStop(win.stops[(i + delta + win.stops.length) % win.stops.length]);
    }

    function submit() {
      if (!win.canSubmit)
        return;
      // The password is out of the field in the frame Enter lands.
      var text = field.text;
      field.text = "";
      Polkit.submit(text);
    }

    function cancel() {
      Polkit.cancel();
      win.hide();
    }

    function cycleIdentity(delta) {
      var n = Polkit.identities.length;
      if (n > 1)
        Polkit.selectIdentity((Polkit.selectedIndex + delta + n) % n);
    }

    function activate(n) {
      switch (n) {
      case 1:
        win.detailsOpen = !win.detailsOpen;
        break;
      case 2:
        win.cycleIdentity(1);
        break;
      case 3:
        win.cancel();
        break;
      case 4:
        win.submit();
        break;
      }
    }

    function handleKey(event) {
      switch (event.key) {
      case Qt.Key_Escape:
        win.cancel();
        break;
      case Qt.Key_Tab:
        win.step(1);
        break;
      case Qt.Key_Backtab:
        win.step(-1);
        break;
      case Qt.Key_Return:
      case Qt.Key_Enter:
      case Qt.Key_Space:
        // On the field Enter submits through the input itself, and Space is a character.
        if (win.stop === 0)
          return;
        win.activate(win.stop);
        break;
      case Qt.Key_Left:
      case Qt.Key_Right:
        if (win.stop !== 2)
          return;
        win.cycleIdentity(event.key === Qt.Key_Right ? 1 : -1);
        break;
      default:
        // Typing with a button focused is typing the password.
        if (win.stop !== 0 && event.text !== "" && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
          win.focusStop(0);
          field.insert(field.cursorPosition, event.text);
          break;
        }
        return;
      }
      event.accepted = true;
    }

    onKeyPressed: function (event) {
      win.handleKey(event);
    }

    // A new request (the queue moving on, or another identity) starts from a clean card.
    function reset() {
      win.detailsOpen = false;
      field.text = "";
      win.focusStop(0);
    }

    onOpening: {
      win.detailsOpen = false;
      field.text = "";
      win.stop = 0;
    }

    Connections {
      target: win

      // The surface takes its own focus a frame after it opens; the field takes it from that.
      function onOpenChanged() {
        if (win.open)
          Qt.callLater(win.focusStop, 0);
      }
    }

    Connections {
      target: Polkit

      function onFlowChanged() {
        if (win.open)
          win.reset();
      }

      function onPreviewChanged() {
        if (win.open)
          win.reset();
      }

      function onFailedCountChanged() {
        if (!Theme.reduceMotion && win.open)
          shakeAnimation.restart();
      }

      // The answer is back from PAM: a retry or a second question, so the field wants the keys.
      function onCheckingChanged() {
        if (!Polkit.checking && win.open)
          win.focusStop(0);
      }
    }

    // ---- the card ----

    Item {
      id: body

      anchors.fill: parent

      // Takes the keys while a button, the plate or the chooser has the focus.
      Item {
        id: catcher

        Keys.onPressed: function (event) {
          win.handleKey(event);
        }
      }

      // The requester: its icon when polkit names one, else a lock.
      Rectangle {
        x: Theme.authInset
        y: Theme.authInset
        width: Theme.authDisc
        height: width
        radius: width / 2
        color: Theme.withAlpha(Theme.accent, Theme.notifAvatarAlpha)

        StrokeIcon {
          anchors.centerIn: parent
          visible: !requesterIcon.shown
          size: Theme.authGlyph
          strokeWidth: 1.75
          color: Theme.accent
          path: IconPaths.lock
        }

        NotificationIcon {
          id: requesterIcon

          anchors.centerIn: parent
          width: parent.width - 12
          height: width
          source: Polkit.iconName !== "" ? Quickshell.iconPath(Polkit.iconName, true) : ""
        }
      }

      Text {
        x: Theme.authTextLeft
        y: 21
        width: Theme.authWidth - x - Theme.authInset
        text: Polkit.requester !== "" ? Polkit.requester : "System"
        color: Theme.accent
        elide: Text.ElideRight
        font.family: Theme.uiFont
        font.pixelSize: Theme.authAppSize
        font.weight: Theme.weightMedium
      }

      Text {
        x: Theme.authTextLeft
        y: 40
        text: "Authentication required"
        color: Theme.inkPrimary
        font.family: Theme.uiFont
        font.pixelSize: Theme.authTitleSize
        font.weight: Theme.weightSemi
      }

      // polkit quotes the program in its action text; those runs are set in the mono face. "The
      // super user" is joined so a lone word never wraps onto a line of its own.
      Text {
        id: messageText

        x: Theme.authInset
        y: Theme.authMessageTop
        width: Theme.authWidth - Theme.authInset * 2
        textFormat: Text.RichText
        text: {
          var html = win.message.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
          html = html.replace(/`([^`']+)['`]/g, function (whole, run) {
            return "<span style=\"font-family:'" + Theme.monoFont + "'; font-size:" + Theme.authMessageCodeSize + "px; color:" + Theme.inkPrimary + ";\">" + run + "</span>";
          });
          return html.replace(/the super user/g, "the super user");
        }
        color: Theme.inkSecondary
        wrapMode: Text.WordWrap
        maximumLineCount: Theme.authMessageLines
        elide: Text.ElideRight
        // Fixed leading, so the height follows from a line count and the card's own height can too.
        lineHeightMode: Text.FixedHeight
        lineHeight: Theme.authMessageLeading
        font.family: Theme.uiFont
        font.pixelSize: Theme.authMessageSize
      }

      // The details plate: the action id always, and what could be read out of the request
      // when it is opened.
      Rectangle {
        id: plate

        x: Theme.authInset
        y: win.plateTop
        width: Theme.authWidth - Theme.authInset * 2
        height: plateSpring.value
        radius: Theme.authDetailsRadius
        color: Theme.surfaceSubtle
        clip: true
        border.width: 1
        border.color: win.stop === 1 ? Theme.focusRing : Theme.withAlpha(Theme.separator, Theme.authDetailsBorderAlpha)

        Accessible.role: Accessible.Button
        Accessible.name: win.detailsOpen ? "Hide details" : "Show details"

        Behavior on border.color {
          ColorAnimation {
            duration: Theme.duration(Theme.lockStateFade)
          }
        }

        StrokeIcon {
          x: 10
          y: (Theme.authDetailsHeight - height) / 2
          size: Theme.authDetailsChevron
          visible: win.canOpenDetails
          strokeWidth: 1.75
          color: Theme.inkTertiary
          path: win.detailsOpen ? IconPaths.chevronDown : IconPaths.chevronRight
        }

        Text {
          x: Theme.authDetailsIdLeft - Theme.authInset
          y: 9.5
          width: parent.width - x - 12
          text: Polkit.actionId
          color: Theme.inkTertiary
          elide: Text.ElideRight
          font.family: Theme.monoFont
          font.pixelSize: Theme.authDetailsSize
        }

        Repeater {
          model: win.rows

          Item {
            required property int index
            required property var modelData

            y: Theme.authDetailsHeight + index * Theme.authDetailsRowHeight + 4
            width: plate.width
            height: Theme.authDetailsRowHeight
            opacity: win.detailsOpen ? 1 : 0

            Behavior on opacity {
              NumberAnimation {
                duration: Theme.duration(Theme.lockStateFade)
              }
            }

            Text {
              x: Theme.authDetailsLabelLeft - Theme.authInset
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.label
              color: Theme.inkTertiary
              font.family: Theme.uiFont
              font.pixelSize: Theme.authDetailsSize
              font.weight: Theme.weightMedium
            }

            Text {
              x: Theme.authDetailsValueLeft - Theme.authInset
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - x - 12
              text: modelData.value
              color: Theme.inkSecondary
              elide: Text.ElideRight
              font.family: Theme.monoFont
              font.pixelSize: Theme.authDetailsSize
            }
          }
        }

        MouseArea {
          width: parent.width
          height: Theme.authDetailsHeight
          enabled: win.canOpenDetails
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            win.detailsOpen = !win.detailsOpen;
            win.focusStop(0);
          }
        }
      }

      // Several accounts can approve: pick one. Absent with a single account.
      Row {
        id: chooser

        x: Theme.authInset
        y: win.identityTop
        width: Theme.authWidth - Theme.authInset * 2
        spacing: 6
        visible: win.choosesIdentity

        Repeater {
          model: win.choosesIdentity ? Polkit.identities.slice(0, 4) : []

          Rectangle {
            id: chip

            required property int index
            required property var modelData
            readonly property bool current: index === Polkit.selectedIndex

            width: (chooser.width - chooser.spacing * (Math.min(4, Polkit.identities.length) - 1)) / Math.min(4, Polkit.identities.length)
            height: Theme.authIdentityHeight
            radius: height / 2
            color: current ? Theme.withAlpha(Theme.accent, Theme.notifAvatarAlpha) : Theme.withAlpha(Theme.highlightMed, Theme.notifActionSecondaryAlpha)
            border.width: win.stop === 2 && current ? 1 : 0
            border.color: Theme.focusRing

            Text {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              text: modelData.displayName !== "" ? modelData.displayName : modelData.name
              color: chip.current ? Theme.accent : Theme.inkPrimary
              elide: Text.ElideRight
              font.family: Theme.uiFont
              font.pixelSize: Theme.authDetailsSize
              font.weight: chip.current ? Theme.weightSemi : Theme.weightMedium
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                Polkit.selectIdentity(chip.index);
                win.focusStop(0);
              }
            }
          }
        }
      }

      // The password pill, in the lock screen's vocabulary: the account's picture and name, and
      // the dots under it. Authenticate is the button, so there is no submit disc.
      Rectangle {
        id: pill

        x: Theme.authInset
        y: win.pillTop
        width: Theme.authWidth - Theme.authInset * 2
        height: Theme.lockPillHeight
        radius: height / 2
        color: Theme.surfaceSubtle
        border.width: 1
        border.color: Polkit.errorText !== "" ? Theme.withAlpha(Theme.love, Theme.lockErrorOutline) : Theme.surfaceOutline

        Accessible.role: Accessible.EditableText
        Accessible.name: Polkit.prompt
        Accessible.passwordEdit: !Polkit.echo

        transform: Translate {
          id: shake
        }

        Behavior on border.color {
          ColorAnimation {
            duration: Theme.duration(Theme.lockStateFade)
          }
        }

        SequentialAnimation {
          id: shakeAnimation

          readonly property int step: Theme.lockShake / 6

          NumberAnimation {
            target: shake
            property: "x"
            to: -Theme.lockShakeTravel
            duration: shakeAnimation.step
            easing.type: Easing.OutQuad
          }
          NumberAnimation {
            target: shake
            property: "x"
            to: Theme.lockShakeTravel
            duration: shakeAnimation.step * 2
            easing.type: Easing.InOutQuad
          }
          NumberAnimation {
            target: shake
            property: "x"
            to: -Theme.lockShakeTravel
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

        // Invisible: the dots are fixed geometry beside it. Read-only while a try is out, so it
        // keeps the focus it will need again when PAM asks.
        TextInput {
          id: field

          anchors.fill: parent
          echoMode: TextInput.NoEcho
          color: "transparent"
          cursorVisible: false
          cursorDelegate: Item {}
          readOnly: Polkit.checking
          inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase

          onTextChanged: {
            if (text.length > 0)
              Polkit.clearError();
          }
          onAccepted: win.submit()

          Keys.onPressed: function (event) {
            win.handleKey(event);
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.IBeamCursor
          acceptedButtons: Qt.LeftButton
          onClicked: win.focusStop(0)
        }

        Rectangle {
          id: avatar

          readonly property bool isYou: win.identity !== null && win.identity.name === Account.userName
          readonly property string label: win.identity !== null && win.identity.displayName !== "" ? win.identity.displayName : Account.displayName

          x: Theme.lockPillInset
          anchors.verticalCenter: parent.verticalCenter
          width: Theme.lockAvatarSize
          height: width
          radius: width / 2
          color: Theme.overlay

          ClippingRectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            visible: avatar.isYou && face.status === Image.Ready

            Image {
              id: face

              anchors.fill: parent
              source: "file://" + Account.facePath + "?" + Account.faceRevision
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
            visible: !(avatar.isYou && face.status === Image.Ready)
            text: avatar.label.length > 0 ? avatar.label.charAt(0).toUpperCase() : "?"
            color: Theme.accent
            font.family: Theme.uiFont
            font.weight: Theme.weightSemi
            font.pixelSize: Theme.lockAvatarGlyphSize
            renderType: Text.QtRendering
          }
        }

        Text {
          id: nameLabel

          x: Theme.lockTextLeft
          y: Theme.lockNameTop
          width: pill.width - x - Theme.authSpinnerRight - Theme.lockSpinnerSize / 2 - Theme.lockPillInset
          elide: Text.ElideRight
          text: avatar.label
          color: Theme.lockTextPrimary
          font.family: Theme.uiFont
          font.weight: Theme.weightSemi
          font.pixelSize: Theme.lockNameSize
          renderType: Text.QtRendering
        }

        // Line two: the dots and caret while typing, otherwise what PAM is asking, or that it is
        // checking. A failed try leaves it ready: the field is never locked out.
        Item {
          id: lineTwo

          x: Theme.lockTextLeft
          y: Theme.lockLineTwoTop
          width: nameLabel.width
          height: Theme.lockLineTwoHeight

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Polkit.checking ? 0 : Theme.lockPlaceholderInset
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: !win.hasText

            text: Polkit.checking ? "Checking…" : Polkit.prompt
            color: Theme.inkSecondary
            elide: Text.ElideRight
            font.family: Theme.uiFont
            font.pixelSize: Theme.lockLineTwoSize
            renderType: Text.QtRendering
          }

          Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            visible: !Polkit.checking

            // A code that is meant to be read is shown as typed.
            Text {
              visible: Polkit.echo && win.hasText
              anchors.verticalCenter: parent.verticalCenter
              text: field.text
              width: Math.min(implicitWidth, lineTwo.width - Theme.lockCaretWidth - 4)
              elide: Text.ElideLeft
              color: Theme.lockTextPrimary
              font.family: Theme.uiFont
              font.pixelSize: Theme.lockLineTwoSize
              renderType: Text.QtRendering
            }

            Repeater {
              model: Polkit.echo ? 0 : 64

              Item {
                id: slot

                readonly property bool filled: index < field.text.length

                width: filled ? Theme.lockDotSize + Theme.lockDotGap : 0
                // Every child is the caret's height, so the positioner lines them up without anchors.
                height: Theme.lockCaretHeight

                Behavior on width {
                  NumberAnimation {
                    duration: Theme.duration(Theme.lockDotPop)
                    easing.type: Easing.OutQuad
                  }
                }

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: Theme.lockDotSize
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

              width: Math.max(1, Theme.lockCaretWidth)
              height: Theme.lockCaretHeight
              radius: width / 2
              color: Theme.lockCaretColor

              SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: !Theme.reduceMotion && win.open
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

        // Checking: a quarter arc turning over a faint track, at the pill's right end.
        Shape {
          id: spinner

          readonly property real stroke: 2
          readonly property real r: (width - stroke) / 2

          x: pill.width - Theme.authSpinnerRight - width / 2
          anchors.verticalCenter: parent.verticalCenter
          width: Theme.lockSpinnerSize
          height: width
          visible: Polkit.checking
          antialiasing: true
          preferredRendererType: Shape.CurveRenderer

          ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.withAlpha(Theme.inkTertiary, 0.35)
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
      }

      // Under the pill: why the last try failed, held until the next keystroke, or what PAM said.
      Text {
        id: captionText

        // Kept after it is withdrawn, so it can fade out with its words.
        property string held: ""

        x: Theme.authInset
        y: win.captionTop
        width: Theme.authWidth - Theme.authInset * 2
        height: Theme.authCaptionHeight
        horizontalAlignment: Text.AlignHCenter
        text: held
        color: win.captionIsError ? Theme.love : Theme.inkSecondary
        opacity: win.caption !== "" ? 1 : 0
        elide: Text.ElideRight
        font.family: Theme.uiFont
        font.pixelSize: Theme.authCaptionSize
        font.weight: Theme.weightMedium

        Behavior on opacity {
          NumberAnimation {
            duration: Theme.duration(Theme.lockStateFade)
          }
        }

        Connections {
          target: win

          function onCaptionChanged() {
            if (win.caption !== "")
              captionText.held = win.caption;
          }
        }
      }

      // Cancel and Authenticate, flush to the right edge.
      Row {
        x: Theme.authWidth - Theme.authInset - width
        y: win.actionsTop
        spacing: Theme.authActionGap

        ActionButton {
          width: Theme.authCancelWidth
          label: "Cancel"
          focused: win.stop === 3
          onPressed: win.cancel()
        }

        ActionButton {
          width: Theme.authAuthenticateWidth
          label: "Authenticate"
          primary: true
          live: win.canSubmit
          focused: win.stop === 4
          onPressed: win.submit()
        }
      }
    }
  }

  // Cancel is the notification's secondary pill; Authenticate is its accent one while there is
  // something to send, and a plate with a muted label until then.
  component ActionButton: Rectangle {
    id: button

    property string label: ""
    property bool primary: false
    property bool live: true
    property bool focused: false

    signal pressed

    height: Theme.authActionHeight
    radius: Theme.authActionRadius
    color: !primary ? Theme.withAlpha(Theme.highlightMed, Theme.notifActionSecondaryAlpha) : live ? Theme.accent : Theme.surfaceRaised
    border.width: focused ? 1.5 : 0
    border.color: Theme.focusRing
    opacity: area.containsMouse && live ? 0.85 : 1

    Accessible.role: Accessible.Button
    Accessible.name: label

    Behavior on color {
      ColorAnimation {
        duration: Theme.duration(Theme.lockStateFade)
      }
    }

    Text {
      anchors.centerIn: parent
      text: button.label
      color: !button.primary ? Theme.inkPrimary : button.live ? Theme.inkOnAccent : Theme.inkTertiary
      font.family: Theme.uiFont
      font.pixelSize: Theme.notifActionSize
      font.weight: button.primary ? Theme.weightSemi : Theme.weightMedium
    }

    MouseArea {
      id: area

      anchors.fill: parent
      hoverEnabled: true
      cursorShape: button.live ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: if (button.live)
        button.pressed()
    }
  }
}
