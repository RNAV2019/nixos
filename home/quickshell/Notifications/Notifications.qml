import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The toast. Board 10, and the island in another of its shapes.
//
// It used to be a card in the top right corner, which is the one place in this
// shell where a surface appeared that the island had nothing to do with. The
// board puts it where every other surface is: the pill grows in place into a
// 450 px card on the board's own 339 ms, holds while the notification is read,
// and melts back into the clock.
//
// One card, not a stack. The island can only be one shape, so this draws the
// newest notification and the rest wait behind it; each gets its own life when
// it reaches the front. The control centre's list is where the whole run of
// them lives, and nothing here has to outlive its card.
//
// Only the card takes input. The window covers the screen so the card can be
// centred in it, but its mask is the card alone, so a click anywhere else goes
// to whatever is underneath rather than being eaten by an overlay.
Variants {
  id: root

  model: Quickshell.screens

  PanelWindow {
    id: win

    required property var modelData

    readonly property bool focused: Monitors.isFocused(win.screen)

    // The one being shown. Newest first, which is the order the store keeps.
    readonly property var current: NotificationStore.popups.length > 0 ? NotificationStore.popups[0] : null

    // A toast is not asked for, so it waits rather than shoving a panel the
    // user opened off the screen, and it gives way to an OSD, which is the
    // direct result of a key that was just pressed.
    readonly property bool blocked: Bus.islandHeld || Bus.osdScreen !== ""

    readonly property bool open: current !== null && focused && !blocked

    readonly property int collapsedWidth: Theme.islandCollapsedWidth(Media.active, Recorder.recording)

    readonly property bool showing: open || surface.width > collapsedWidth + 0.5

    // Per the specification: 0 never expires, negative means the server's own
    // default, positive is a count of milliseconds.
    readonly property int timeout: {
      if (!current)
        return 0;
      if (current.expireTimeout === 0)
        return 0;
      return current.expireTimeout > 0 ? current.expireTimeout : NotificationStore.defaultTimeout;
    }

    readonly property bool urgent: current ? current.urgency === 2 : false

    readonly property string appName: current && current.appName ? String(current.appName) : "Notification"
    readonly property string summary: current && current.summary ? String(current.summary) : ""
    readonly property string bodyText: current && current.body ? String(current.body) : ""

    readonly property color tint: urgent ? Theme.love : NotificationStore.avatarColour(appName)

    readonly property string iconSource: current ? NotificationStore.iconFor(current.image, current.appIcon) : ""

    // The notification's own buttons. "default" is the whole-card click, by
    // convention, so it is never drawn as one; two is as many as the row has
    // room for beside the dismiss button.
    readonly property var buttons: {
      var out = [];
      if (!current)
        return out;
      var actions = current.actions;
      for (var i = 0; i < actions.length && out.length < 2; i++) {
        if (actions[i].identifier !== "default")
          out.push(actions[i]);
      }
      return out;
    }

    // What the notification is worth reading of. Board 10 draws two lines and
    // the card is sized to whatever there actually is.
    readonly property int bodyLines: bodyText === "" ? 0 : Math.min(Theme.notifBodyLines, bodyMetrics.lineCount)

    // The board has a source line under the title - a web address, in its own
    // example. Nothing on this bus carries one: an application sends a summary
    // and a body and nothing between them. So the body sits where the source
    // would have started, and the line is not drawn at all rather than drawn
    // empty.
    readonly property int bodyTop: Theme.notifBodyTopBare

    readonly property int bodyBottom: bodyLines > 0 ? bodyTop + bodyLines * Theme.notifBodyLeading - 3 : Theme.notifTitleTop + 18

    readonly property int actionsTop: bodyBottom + Theme.notifActionGapAbove

    readonly property int openHeight: Math.max(Theme.notifAvatarSize + Theme.notifInset * 2, actionsTop + Theme.notifActionHeight + Theme.notifPadBottom)

    // Time left before it goes, in milliseconds. Counted down rather than run
    // off one long Timer, because hovering has to hold it where it is: a Timer
    // that is stopped and started again begins its whole interval afresh, which
    // hands back time the notification had already spent and makes a card that
    // is passed over twice outlive one that is not.
    property int remaining: 0

    function reset() {
      remaining = timeout;
    }

    onTimeoutChanged: reset()

    // Taking the card away. The notification is dismissed on the bus, which is
    // what tells the application nobody is looking at it any more, and dropped
    // from the store, which is what shrinks this surface back to the pill.
    function close() {
      if (!current)
        return;
      var n = current;
      n.dismiss();
      NotificationStore.forgetPopup(n);
    }

    // The same, but as the timeout rather than as a decision: expire() is the
    // one the specification wants when nobody touched it.
    function expire() {
      if (!current)
        return;
      var n = current;
      n.expire();
      NotificationStore.forgetPopup(n);
    }

    function invoke(action) {
      action.invoke();
      close();
    }

    Timer {
      // Only while the card is up, only while it expires at all, and only while
      // the pointer is somewhere else.
      running: win.open && win.timeout > 0 && !cardHover.containsMouse
      interval: 100
      repeat: true
      onTriggered: {
        win.remaining -= interval;
        if (win.remaining <= 0)
          win.expire();
      }
    }

    // For the timestamp, which is the only thing on the card that changes while
    // it is being looked at.
    SystemClock {
      id: clock

      precision: SystemClock.Minutes
    }

    property date arrived: new Date()

    // One handler, because QML takes only one per signal: a new notification
    // arrives, so it is new, and its clock starts now.
    onCurrentChanged: {
      arrived = new Date();
      reset();
    }

    readonly property string timestamp: {
      clock.date;
      var mins = Math.floor((Date.now() - arrived.getTime()) / 60000);
      if (mins < 1)
        return "now";
      if (mins === 1)
        return "1 min ago";
      return mins + " min ago";
    }

    screen: modelData
    visible: showing
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    exclusionMode: ExclusionMode.Ignore

    // A toast must never take the keyboard. Whatever was being typed into goes
    // on being typed into.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Only the card is a target; the rest of the window is not there as far as
    // the pointer is concerned.
    mask: Region {
      item: surface
    }

    onShowingChanged: {
      if (showing)
        Bus.notifyScreen = win.screen ? win.screen.name : "";
      else if (win.screen && Bus.notifyScreen === win.screen.name)
        Bus.notifyScreen = "";
    }

    FrostedSurface {
      id: surface

      x: (win.width - width) / 2
      y: Theme.barMarginTop

      clipContent: true

      implicitWidth: win.open ? Theme.notifWidth : win.collapsedWidth
      implicitHeight: win.open ? win.openHeight : Theme.barHeight

      // Read off the height rather than travelling; see Bar/Island.qml.
      surfaceRadius: Math.min(height / 2, Theme.notifRadius)

      Behavior on implicitWidth {
        Morph {}
      }

      Behavior on implicitHeight {
        Morph {}
      }

      MouseArea {
        id: cardHover

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        // Clicking the card invokes the notification's default action, which is
        // what opens the application that sent it. Anything without one is just
        // dismissed.
        onClicked: {
          var actions = win.current ? win.current.actions : [];
          for (var i = 0; i < actions.length; i++) {
            if (actions[i].identifier === "default") {
              actions[i].invoke();
              break;
            }
          }
          win.close();
        }
      }

      // Reuse the island clock for the pill state rather than maintaining a
      // second copy with subtly different metrics.
      IslandClock {
        anchors.fill: parent
        shown: !win.open
      }

      Item {
        id: body

        anchors.fill: parent
        opacity: win.open ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          Morph {
            duration: Theme.morphContent
          }
        }

        // The sender's icon, or its initial on a wash of its own colour. The
        // colour is picked off the name, so the same application keeps the same
        // avatar between sessions.
        Rectangle {
          id: avatar

          x: Theme.notifInset
          y: Theme.notifInset
          width: Theme.notifAvatarSize
          height: width
          radius: width / 2
          color: Theme.withAlpha(win.tint, Theme.notifAvatarAlpha)

          Text {
            anchors.centerIn: parent
            text: NotificationStore.initial(win.appName)
            color: win.tint
            visible: !appIcon.visible
            font.family: Theme.uiFont
            font.pixelSize: Theme.notifAvatarLetterSize
            font.weight: Font.Bold
          }

          Image {
            id: appIcon

            anchors.centerIn: parent
            width: parent.width - 12
            height: width
            source: win.iconSource
            sourceSize.width: Theme.notifAvatarSize * 3
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            visible: source !== "" && status === Image.Ready
          }
        }

        Text {
          x: Theme.notifTextLeft
          y: Theme.notifAppTop
          width: Math.max(0, stamp.x - x - Theme.notifActionGap)
          text: win.appName
          color: win.tint
          elide: Text.ElideRight
          font.family: Theme.uiFont
          font.pixelSize: Theme.notifAppSize
          font.weight: Font.Medium
        }

        Text {
          id: stamp

          x: closeGlyph.x - width - Theme.notifActionGap
          y: Theme.notifAppTop
          text: win.timestamp
          color: Theme.muted
          font.family: Theme.uiFont
          font.pixelSize: Theme.notifAppSize
        }

        Text {
          id: closeGlyph

          x: Theme.notifWidth - Theme.notifInset - width
          y: Theme.notifAppTop - 1
          text: Icons.close
          color: closeArea.containsMouse ? Theme.text : Theme.muted
          scale: closeArea.pressed ? 0.95 : 1

          Behavior on color {
            Tint {}
          }

          Behavior on scale {
            Morph { duration: Theme.morphState }
          }
          font.family: Theme.iconFont
          font.pixelSize: Theme.notifCloseSize

          MouseArea {
            id: closeArea

            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: win.close()
          }
        }

        Text {
          x: Theme.notifTextLeft
          y: Theme.notifTitleTop
          width: Theme.notifWidth - x - Theme.notifInset
          text: win.summary
          color: win.urgent ? Theme.love : Theme.text
          elide: Text.ElideRight
          font.family: Theme.uiFont
          font.pixelSize: Theme.notifTitleSize
          font.weight: Font.DemiBold
        }

        Text {
          id: bodyMetrics

          x: Theme.notifTextLeft
          y: win.bodyTop
          width: Theme.notifWidth - x - Theme.notifInset
          text: win.bodyText
          visible: win.bodyText !== ""
          color: Theme.subtle
          textFormat: Text.StyledText
          wrapMode: Text.WordWrap
          maximumLineCount: Theme.notifBodyLines
          elide: Text.ElideRight
          // Fixed leading, so the card's height can be worked out from a line
          // count rather than measured after the fact.
          lineHeightMode: Text.FixedHeight
          lineHeight: Theme.notifBodyLeading
          font.family: Theme.uiFont
          font.pixelSize: Theme.notifBodySize
        }

        // The buttons, laid out right to left: the sender's own first, so the
        // rightmost is the thing the notification is for, and ours last.
        Row {
          id: actions

          layoutDirection: Qt.RightToLeft
          spacing: Theme.notifActionGap
          x: Theme.notifWidth - Theme.notifInset - width
          y: win.actionsTop

          component Pill: Rectangle {
            id: pill

            property string label: ""
            property bool primary: false

            signal pressed

            implicitWidth: pillText.implicitWidth + Theme.notifActionPad * 2
            implicitHeight: Theme.notifActionHeight
            radius: Theme.notifActionRadius
            color: primary ? Theme.accent : Theme.withAlpha(Theme.highlightMed, Theme.notifActionSecondaryAlpha)
            opacity: pillArea.containsMouse ? 0.85 : 1

            Text {
              id: pillText

              anchors.centerIn: parent
              text: pill.label
              color: pill.primary ? Theme.base : Theme.text
              font.family: Theme.uiFont
              font.pixelSize: Theme.notifActionSize
              font.weight: pill.primary ? Font.DemiBold : Font.Medium
            }

            MouseArea {
              id: pillArea

              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: pill.pressed()
            }
          }

          Repeater {
            model: win.buttons

            Pill {
              required property int index
              required property var modelData

              label: modelData.text
              primary: index === 0
              onPressed: win.invoke(modelData)
            }
          }

          // Always present, and always the leftmost. A critical notification
          // has not been dealt with by being sent away, so its word for this is
          // Ignore rather than Dismiss.
          Pill {
            label: win.urgent ? "Ignore" : "Dismiss"
            primary: win.buttons.length === 0
            onPressed: win.close()
          }
        }
      }
    }
  }
}
