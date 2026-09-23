import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The toast: the island grows into a 450 px card, then melts back into the clock.
// One card, not a stack; only the card takes input (the window covers the screen).
Variants {
  id: root

  model: Quickshell.screens

  PanelWindow {
    id: win

    required property var modelData

    readonly property bool focused: Monitors.isFocused(win.screen)

    // The toast being shown; popups[0] is the newest.
    readonly property var current: NotificationStore.popups.length > 0 ? NotificationStore.popups[0] : null

    // Waits behind a user-opened panel, but yields to an OSD from a keypress.
    readonly property bool blocked: Bus.islandHeldFor(win.screen ? win.screen.name : "") || Bus.transientScreen("osd") !== ""
    readonly property bool wantsOpen: current !== null && focused && !blocked
    property bool open: false

    readonly property int collapsedWidth: Theme.islandCollapsedWidth(Media.active, Recorder.recording)

    readonly property bool showing: open || origin.held || surface.width > collapsedWidth + 0.5

    IslandOrigin {
      id: origin

      window: win
    }

    onWantsOpenChanged: {
      if (wantsOpen && !open) {
        origin.claim(Theme.notifWidth, win.openHeight, Theme.notifRadius, Theme.morphSurface);
        open = true;
      } else if (!wantsOpen && open) {
        open = false;
        origin.release();
      }
    }

    // Per the specification: 0 never expires, negative is the server default, positive is ms.
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

    // "default" is the whole-card click, so never drawn; two is the row's limit.
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

    readonly property int bodyLines: bodyText === "" ? 0 : Math.min(Theme.notifBodyLines, bodyMetrics.lineCount)

    // Nothing on this bus carries a source line, so the body starts where it would have.
    readonly property int bodyTop: Theme.notifBodyTopBare

    readonly property int bodyBottom: bodyLines > 0 ? bodyTop + bodyLines * Theme.notifBodyLeading - 3 : Theme.notifTitleTop + 18

    readonly property int actionsTop: bodyBottom + Theme.notifActionGapAbove

    readonly property int openHeight: Math.max(Theme.notifAvatarSize + Theme.notifInset * 2, actionsTop + Theme.notifActionHeight + Theme.notifPadBottom)

    // Counted down so hovering holds it; a restarted Timer would return spent time.
    property int remaining: 0

    function reset() {
      remaining = timeout;
    }

    onTimeoutChanged: reset()

    // Dismiss on the bus and drop from the store, shrinking the surface to the pill.
    function close() {
      if (!current)
        return;
      var n = current;
      n.dismiss();
      NotificationStore.forgetPopup(n);
    }

    // Same, via expire(), which is what the spec wants for a timeout.
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
      // Only while the card is up and expiring, and the pointer is elsewhere.
      running: win.open && win.timeout > 0 && !cardHover.containsMouse
      interval: 100
      repeat: true
      onTriggered: {
        win.remaining -= interval;
        if (win.remaining <= 0)
          win.expire();
      }
    }

    // Drives the timestamp, the only thing that changes while the card is up.
    SystemClock {
      id: clock

      precision: SystemClock.Minutes
    }

    property date arrived: new Date()

    // One handler, because QML takes only one per signal.
    onCurrentChanged: {
      arrived = new Date();
      reset();
    }

    Connections {
      target: win.current

      function onClosed() {
        if (win.current)
          NotificationStore.forgetPopup(win.current);
      }
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
    visible: !Bus.locking && showing
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

    // A toast must never take the keyboard.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Only the card is a target; the rest of the window is not there to the pointer.
    mask: Region {
      item: surface
    }

    onShowingChanged: {
      if (showing)
        Bus.setTransientScreen("notify", win.screen ? win.screen.name : "");
      else if (win.screen && Bus.transientScreen("notify") === win.screen.name)
        Bus.setTransientScreen("notify", "");
    }

    Connections {
      target: Bus

      function onSurfacesClosingForLock() {
        win.open = false;
        origin.release();
      }

      function onIslandClaimed(screen) {
        if (!win.open || !win.screen || screen !== win.screen.name)
          return;
        origin.publish(surface.width, surface.height, surface.surfaceRadius);
        origin.hold(surface.width, surface.height, surface.surfaceRadius);
        win.open = false;
      }
    }

    FrostedSurface {
      id: surface

      x: (win.width - width) / 2
      y: Theme.barMarginTop

      clipContent: true

      implicitWidth: win.open ? Theme.notifWidth : origin.held ? origin.heldWidth : origin.originWidth
      implicitHeight: win.open ? win.openHeight : origin.held ? origin.heldHeight : origin.originHeight

      // Read off the height rather than travelling; see Bar/Island.qml.
      surfaceRadius: Math.min(height / 2, Theme.notifRadius)

      Behavior on implicitWidth {
        enabled: !Theme.reduceMotion

        SurfaceSpring {}
      }

      Behavior on implicitHeight {
        enabled: !Theme.reduceMotion

        SurfaceSpring {}
      }

      MouseArea {
        id: cardHover

        anchors.fill: parent
        enabled: win.open
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        // Clicking invokes the default action (opens the sender); otherwise just dismiss.
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

      // Reuse the collapsed renderer so handoff preserves media and recording state.
      CollapsedPill {
        anchors.fill: parent
        origin: origin
        shown: !win.open && !origin.held
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

        // The sender's icon, or its initial on a colour picked off the name.
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
          // Fixed leading, so height follows from a line count, not a measurement.
          lineHeightMode: Text.FixedHeight
          lineHeight: Theme.notifBodyLeading
          font.family: Theme.uiFont
          font.pixelSize: Theme.notifBodySize
        }

        // Laid out right to left: the sender's own buttons first, ours last.
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
               color: pill.primary ? Theme.inkOnAccent : Theme.inkPrimary
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

          // Always present and leftmost. A critical notification says Ignore, not
          // Dismiss, because sending it away is not dealing with it.
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
