import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Ui

// The toast: the island grows into a 450 px card, then melts back into the clock.
// One card, not a stack; only the card takes input.
Variants {
  id: root

  model: Quickshell.screens

  // Ranked under the OSD and a Quick Share request, which it waits behind and comes back after,
  // and over the sharing pill's progress and confirmations, which wait behind it.
  TransientSurface {
    id: win

    key: "notify"
    layerNamespace: "quickshell-notifications"
    rank: 1

    // The toast being shown; popups[0] is the newest.
    readonly property var current: NotificationStore.popups.length > 0 ? NotificationStore.popups[0] : null

    // Waits behind a user-opened panel.
    readonly property bool blocked: Bus.islandOpenFor(win.screenName)

    wanted: current !== null && win.focused && !win.blocked

    openWidth: Theme.notifWidth
    openHeight: win.front === 0 ? slotA.cardHeight : slotB.cardHeight
    openRadius: Theme.notifRadius

    // ---- what the card shows ----
    //
    // The card draws a snapshot of the notification, never the live object: a dismissed one is
    // gone the moment it is dismissed, and the card still has its fade out to play. Two slots
    // take turns, so the toast after it crossfades in while the height springs between the two.

    property int front: 0

    // The notification the card is drawing (a snapshot), which outlives the live one.
    readonly property var shown: win.front === 0 ? slotA.n : slotB.n

    function snapshot(n) {
      var buttons = [];
      var actions = n.actions;
      // "default" is the whole-card click, so never drawn; two is the row's limit.
      for (var i = 0; i < actions.length && buttons.length < 2; i++) {
        if (actions[i].identifier !== "default")
          buttons.push({
            text: String(actions[i].text),
            action: actions[i]
          });
      }
      var appName = n.appName ? String(n.appName) : "Notification";
      var tinted = NotificationStore.iconTinted(n.desktopEntry, n.appName);
      return {
        ref: n,
        appName: appName,
        summary: n.summary ? String(n.summary) : "",
        body: n.body ? String(n.body) : "",
        urgent: n.urgency === 2,
        iconSource: NotificationStore.iconFor(n.image, n.appIcon, n.desktopEntry, n.appName),
        iconTinted: tinted,
        buttons: buttons,
        arrived: new Date()
      };
    }

    // A fresh arrival on a card nobody can see lands at once; on a card on screen it crossfades.
    function present(n) {
      var shown = win.shown;
      if (shown && shown.ref === n)
        return;
      var shot = win.snapshot(n);
      var crossfade = win.showing && !win.parked && shown !== null;
      if (!crossfade) {
        if (win.front === 0)
          slotA.n = shot;
        else
          slotB.n = shot;
        return;
      }
      if (win.front === 0)
        slotB.n = shot;
      else
        slotA.n = shot;
      win.front = 1 - win.front;
    }

    // Per the specification: 0 never expires, negative is the server default, positive is ms.
    readonly property int timeout: {
      if (!current)
        return 0;
      if (current.expireTimeout === 0)
        return 0;
      return current.expireTimeout > 0 ? current.expireTimeout : NotificationStore.defaultTimeout;
    }

    // Counted down so hovering holds it; a restarted Timer would return spent time.
    property int remaining: 0

    function reset() {
      remaining = timeout;
    }

    onTimeoutChanged: reset()

    // The claim carries the open shape, so the card must be drawing this toast before it.
    onOpening: {
      if (current)
        win.present(current);
    }

    // One handler, because QML takes only one per signal.
    onCurrentChanged: {
      reset();
      if (current)
        win.present(current);
    }

    // Dismiss on the bus and drop from the store; the card keeps its snapshot to fade out with.
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

    Connections {
      target: Bus

      function onClockRefreshed() {
        clock.enabled = false;
        clock.enabled = true;
      }
    }

    Connections {
      target: win.current

      function onClosed() {
        if (win.current)
          NotificationStore.forgetPopup(win.current);
      }
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

    Toast {
      id: slotA

      host: win
      clockDate: clock.date
      live: win.front === 0
    }

    Toast {
      id: slotB

      host: win
      clockDate: clock.date
      live: win.front === 1
    }
  }

  // One notification's card contents, at the board's positions.
  component Toast: Item {
    id: toast

    // The window, and the minute clock: an inline component cannot see the file's ids.
    property var host: null
    property date clockDate: new Date()
    // The snapshot drawn (see snapshot()), or null before the first one.
    property var n: null
    // The slot the card is showing. Only it takes input.
    property bool live: false

    readonly property bool urgent: toast.n ? toast.n.urgent : false
    readonly property string appName: toast.n ? toast.n.appName : ""
    readonly property bool iconTinted: toast.n ? toast.n.iconTinted : false
    readonly property color tint: toast.urgent ? Theme.love : NotificationStore.avatarColour(toast.appName, toast.iconTinted)
    readonly property var buttons: toast.n ? toast.n.buttons : []

    readonly property int bodyLines: !toast.n || toast.n.body === "" ? 0 : Math.min(Theme.notifBodyLines, bodyMetrics.lineCount)

    // Nothing on this bus carries a source line, so the body starts where it would have.
    readonly property int bodyTop: Theme.notifBodyTopBare
    readonly property int bodyBottom: bodyLines > 0 ? bodyTop + bodyLines * Theme.notifBodyLeading - 3 : Theme.notifTitleTop + 18
    readonly property int actionsTop: bodyBottom + Theme.notifActionGapAbove
    readonly property int cardHeight: Math.max(Theme.notifAvatarSize + Theme.notifInset * 2, actionsTop + Theme.notifActionHeight + Theme.notifPadBottom)

    readonly property string timestamp: {
      toast.clockDate;
      if (!toast.n)
        return "";
      var mins = Math.floor((Date.now() - toast.n.arrived.getTime()) / 60000);
      if (mins < 1)
        return "now";
      if (mins === 1)
        return "1 min ago";
      return mins + " min ago";
    }

    anchors.fill: parent
    enabled: toast.live
    opacity: toast.live ? 1 : 0
    visible: opacity > 0 && toast.n !== null

    Behavior on opacity {
      Morph {
        duration: Theme.duration(Theme.morphEnter)
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
      color: Theme.withAlpha(toast.tint, Theme.notifAvatarAlpha)

      Text {
        anchors.centerIn: parent
        text: NotificationStore.initial(toast.appName)
        color: toast.tint
        visible: !appIcon.shown
        font.family: Theme.uiFont
        font.pixelSize: Theme.notifAvatarLetterSize
        font.weight: Theme.weightBold
      }

      NotificationIcon {
        id: appIcon

        anchors.centerIn: parent
        width: parent.width - 12
        height: width
        source: toast.n ? toast.n.iconSource : ""
        tinted: toast.iconTinted
        tint: toast.tint
      }
    }

    Text {
      x: Theme.notifTextLeft
      y: Theme.notifAppTop
      width: Math.max(0, stamp.x - x - Theme.notifActionGap)
      text: toast.appName
      color: toast.tint
      elide: Text.ElideRight
      font.family: Theme.uiFont
      font.pixelSize: Theme.notifAppSize
      font.weight: Theme.weightMedium
    }

    Text {
      id: stamp

      x: closeGlyph.x - width - Theme.notifActionGap
      y: Theme.notifAppTop
      text: toast.timestamp
      color: Theme.muted
      font.family: Theme.uiFont
      font.pixelSize: Theme.notifAppSize
    }

    IconButton {
      id: closeGlyph

      x: Theme.notifWidth - Theme.notifInset - width
      y: Theme.notifAppTop - 1
      text: Icons.close
      font.family: Theme.iconFont
      font.pixelSize: Theme.notifCloseSize
      baseColor: Theme.muted
      hoverColor: Theme.text
      hitSlop: 6
      accessibleName: "Dismiss notification"

      onClicked: toast.host.close()
    }

    Text {
      x: Theme.notifTextLeft
      y: Theme.notifTitleTop
      width: Theme.notifWidth - x - Theme.notifInset
      text: toast.n ? toast.n.summary : ""
      color: toast.urgent ? Theme.love : Theme.text
      elide: Text.ElideRight
      font.family: Theme.uiFont
      font.pixelSize: Theme.notifTitleSize
      font.weight: Theme.weightSemi
    }

    Text {
      id: bodyMetrics

      x: Theme.notifTextLeft
      y: toast.bodyTop
      width: Theme.notifWidth - x - Theme.notifInset
      text: toast.n ? toast.n.body : ""
      visible: text !== ""
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
      y: toast.actionsTop

      Repeater {
        model: toast.buttons

        ActionPill {
          required property int index
          required property var modelData

          label: modelData.text
          primary: index === 0
          onPressed: toast.host.invoke(modelData.action)
        }
      }

      // Always present and leftmost. A critical notification says Ignore, not
      // Dismiss, because sending it away is not dealing with it.
      ActionPill {
        label: toast.urgent ? "Ignore" : "Dismiss"
        primary: toast.buttons.length === 0
        onPressed: toast.host.close()
      }
    }
  }

  component ActionPill: Rectangle {
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
}
