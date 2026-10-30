import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The toast: the island grows into a 450 px card, then melts back into the clock.
// One card at a time; the ones waiting peek out under it and are counted on it. Only the
// card takes input, and the keyboard only when it carries a reply box.
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

    // A card being typed into stays in front: the notification it belongs to, for as long as
    // there is a draft, so a newer arrival queues behind it rather than taking the draft away.
    property var pinned: null

    // The toast being shown; popups[0] is the newest.
    readonly property var current: {
      var list = NotificationStore.popups;
      if (win.pinned && list.indexOf(win.pinned) >= 0)
        return win.pinned;
      return list.length > 0 ? list[0] : null;
    }

    // How many wait behind it.
    readonly property int queued: Math.max(0, NotificationStore.popups.length - 1)

    // Waits behind a user-opened panel.
    readonly property bool blocked: Bus.islandOpenFor(win.screenName)

    wanted: current !== null && win.focused && !win.blocked

    openWidth: Theme.notifWidth
    openHeight: win.frontSlot.cardHeight
    openRadius: Theme.notifRadius

    // Only a card with a reply box wants the keyboard, and then only on demand: the compositor
    // hands it over when the box is clicked, never when the toast appears.
    keyboardFocus: win.frontSlot.canReply ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    cardOffset: swipe.offset
    cardOpacity: swipe.fade * win.appear

    // ---- what the card shows ----
    //
    // The card draws a snapshot of the notification, never the live object: a dismissed one is
    // gone the moment it is dismissed, and the card still has its fade out to play. Two slots
    // take turns, so the toast after it crossfades in while the height springs between the two.

    property int front: 0

    readonly property var frontSlot: win.front === 0 ? slotA : slotB

    // The notification the card is drawing (a snapshot), which outlives the live one.
    readonly property var shown: win.frontSlot.n

    // There is a draft in the reply box.
    readonly property bool typing: win.frontSlot.typing

    onTypingChanged: win.pinned = win.typing ? win.current : null

    function snapshot(n) {
      var buttons = [];
      var actions = n.actions;
      // "default" is the whole-card click and "inline-reply" the reply box, so neither is drawn;
      // two is the row's limit.
      for (var i = 0; i < actions.length && buttons.length < 2; i++) {
        if (actions[i].identifier !== "default" && actions[i].identifier !== "inline-reply")
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
        hasReply: n.hasInlineReply,
        replyPlaceholder: n.inlineReplyPlaceholder ? String(n.inlineReplyPlaceholder) : "",
        arrived: new Date()
      };
    }

    // A fresh arrival on a card nobody can see lands at once; on a card on screen it crossfades.
    // After a swipe the card is replaced where it stands (`instant`) and the surface fades in.
    function present(n, instant) {
      // A card on its way out keeps the slot until it is gone; see swipe.onGone.
      if (win.leaving)
        return;
      var shown = win.shown;
      if (shown && shown.ref === n)
        return;
      var shot = win.snapshot(n);
      var crossfade = !instant && win.showing && !win.parked && shown !== null;
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

    // What the sender does with an action or a reply can close the notification on the spot,
    // which moves `current` on to the next toast: so it is the one acted on that is dismissed.
    function invoke(action) {
      var n = current;
      action.invoke();
      if (n) {
        n.dismiss();
        NotificationStore.forgetPopup(n);
      }
    }

    // The sender gets the text, and the toast is done with.
    function sendReply(text) {
      var n = current;
      if (!n)
        return;
      n.sendInlineReply(text);
      n.dismiss();
      NotificationStore.forgetPopup(n);
    }

    Timer {
      // Only while the card is up and expiring, and nobody is on it: not the pointer over it,
      // not a hand dragging it, not a draft in its reply box.
      running: win.open && win.timeout > 0 && !cardHover.containsMouse && !swipe.held && !win.typing && !win.leaving
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

    // ---- the queue ----
    //
    // The toasts behind the front one show as two back layers under it, drawn in the window
    // beneath the surface rather than inside it, so they stand against the desktop. Each is a
    // strip: only the part below the card's bottom edge is drawn.

    // A card leaving lifts the layers behind it, and one arriving sets the old front back
    // behind it: the layers start offset the other way and settle.
    property int lastQueued: 0

    readonly property real rise: riseSpring.value

    onQueuedChanged: {
      var gone = win.queued < win.lastQueued;
      win.lastQueued = win.queued;
      riseSpring.animate = false;
      riseSpring.target = gone ? Theme.notifQueuePeek : -Theme.notifQueuePeek;
      riseSpring.animate = true;
      riseSpring.target = 0;
    }

    MorphSpring {
      id: riseSpring
    }

    QueueLayer {
      host: win
      depth: 2
    }

    QueueLayer {
      host: win
      depth: 1
    }

    // ---- swipe ----

    // From the release that dismisses until the card is out of sight.
    property bool leaving: false

    // The surface coming back after a swipe, for the next card or the melt into the pill.
    property real appear: 1

    NumberAnimation {
      id: appearIn

      target: win
      property: "appear"
      from: 0
      to: 1
      duration: Theme.duration(Theme.morphEnter)
      easing.type: Easing.OutQuad
    }

    // First in the surface, under the toasts: set beside the surface it swallowed their clicks,
    // and over them it took the buttons' presses; here it only watches for a drag.
    SwipeDismiss {
      id: swipe

      anchors.fill: parent
      span: Theme.notifWidth
      // A drag inside the box would be a selection.
      enabled: win.open && !win.typing

      // The notification goes at once and the next waits its turn: it replaces this card where
      // it stands only once the swiped one is gone.
      onCommitted: {
        win.leaving = true;
        win.close();
      }

      onGone: {
        win.leaving = false;
        swipe.reset();
        win.appear = 0;
        appearIn.restart();
        if (win.current)
          win.present(win.current, true);
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

  // A toast waiting behind the card, showing only the curve of its bottom edge.
  component QueueLayer: Item {
    id: layer

    required property var host
    // 1 is the next toast, 2 the one after.
    required property int depth

    readonly property bool shown: layer.host.open && layer.host.origin.presented && layer.host.queued >= layer.depth

    parent: layer.host.contentItem
    z: -layer.depth
    // At rest under the card, whatever the card is being swiped to.
    x: layer.host.surface.x - layer.host.cardOffset
    y: layer.host.surface.snap(layer.host.surface.y + layer.host.surface.height)
    width: layer.host.surface.width
    height: Theme.notifQueuePeek * (Theme.notifQueueLayers + 1)
    clip: true
    opacity: layer.shown ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
      Morph {
        duration: Theme.morphState
      }
    }

    Rectangle {
      x: Theme.notifQueueInset * layer.depth
      y: Theme.notifQueuePeek * layer.depth + layer.host.rise - height
      width: layer.width - x * 2
      height: Theme.notifRadius * 2
      radius: Theme.notifRadius
      color: Theme.surface
      border.width: 1
      border.color: Theme.surfaceOutline
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

    // The sender takes replies, and Esc has not sent the box away for this card.
    readonly property bool canReply: toast.n ? toast.n.hasReply : false
    property bool replyOff: false
    readonly property bool replying: toast.canReply && !toast.replyOff
    readonly property bool typing: toast.replying && (replyInput.activeFocus || replyInput.text !== "")

    // Esc steps back: out of the box to the sender's buttons, then out of the toast.
    function leaveReply() {
      replyInput.text = "";
      toast.replyOff = true;
      toast.forceActiveFocus();
    }

    onNChanged: {
      replyOff = false;
      replyInput.text = "";
    }

    readonly property int bodyLines: !toast.n || toast.n.body === "" ? 0 : Math.min(Theme.notifBodyLines, bodyMetrics.lineCount)

    // Nothing on this bus carries a source line, so the body starts where it would have.
    readonly property int bodyTop: Theme.notifBodyTopBare
    readonly property int bodyBottom: bodyLines > 0 ? bodyTop + bodyLines * Theme.notifBodyLeading - 3 : Theme.notifTitleTop + 18
    readonly property int actionsTop: bodyBottom + Theme.notifActionGapAbove
    // The reply box is taller than the pills it stands in for.
    readonly property int rowHeight: toast.replying ? Theme.notifReplyHeight : Theme.notifActionHeight
    readonly property int cardHeight: Math.max(Theme.notifAvatarSize + Theme.notifInset * 2, actionsTop + toast.rowHeight + Theme.notifPadBottom)

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

    Keys.onEscapePressed: toast.host.close()

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
      enabled: !toast.replying
      opacity: toast.replying ? 0 : 1
      visible: opacity > 0

      Behavior on opacity {
        Morph {
          duration: Theme.duration(Theme.morphContent)
        }
      }

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

    // How many more are waiting, where the action row starts. Counting down cross-fades the
    // digits; with nothing waiting it goes.
    QueueChip {
      x: Theme.notifTextLeft
      y: toast.actionsTop + (Theme.notifActionHeight - height) / 2
      count: toast.host ? toast.host.queued : 0
      shown: toast.live && !toast.replying
    }

    // The sender's reply box in the action row's place.
    Item {
      id: replyRow

      y: toast.actionsTop
      width: Theme.notifWidth
      height: Theme.notifReplyHeight
      enabled: toast.replying
      opacity: toast.replying ? 1 : 0
      visible: opacity > 0

      Behavior on opacity {
        Morph {
          duration: Theme.duration(Theme.morphContent)
        }
      }

      Rectangle {
        id: field

        x: Theme.notifTextLeft
        width: sendDisc.x - Theme.notifReplyGap - x
        height: parent.height
        radius: Theme.notifReplyRadius
        color: Theme.surfaceSubtle
        border.width: replyInput.activeFocus ? Theme.notifReplyFocusRing : 1
        border.color: replyInput.activeFocus ? Theme.accent : Theme.surfaceOutline

        Behavior on border.color {
          Tint {}
        }

        Text {
          x: Theme.notifReplyTextInset + (replyInput.activeFocus ? 3 : 0)
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - Theme.notifReplyTextInset * 2
          visible: replyInput.text === ""
          text: toast.n && toast.n.replyPlaceholder !== "" ? toast.n.replyPlaceholder : "Reply to " + (toast.n ? toast.n.summary : "") + "…"
          color: Theme.inkTertiary
          elide: Text.ElideRight
          font.family: Theme.uiFont
          font.pixelSize: Theme.notifBodySize
        }

        TextInput {
          id: replyInput

          x: Theme.notifReplyTextInset
          width: parent.width - Theme.notifReplyTextInset * 2
          height: parent.height
          verticalAlignment: TextInput.AlignVCenter
          clip: true
          color: Theme.inkPrimary
          selectionColor: Theme.withAlpha(Theme.accent, Theme.fillSelected)
          selectByMouse: true
          font.family: Theme.uiFont
          font.pixelSize: Theme.notifBodySize

          Accessible.role: Accessible.EditableText
          Accessible.name: "Reply"

          cursorDelegate: Rectangle {
            width: 1.5
            height: 16
            color: Theme.accent
          }

          onAccepted: if (text !== "")
            toast.host.sendReply(text)

          Keys.onEscapePressed: toast.leaveReply()
        }
      }

      Rectangle {
        id: sendDisc

        readonly property bool ready: replyInput.text !== ""

        x: Theme.notifWidth - Theme.notifInset - width
        width: Theme.notifReplyHeight
        height: width
        radius: width / 2
        color: sendDisc.ready ? Theme.accent : Theme.surfaceRaised
        opacity: sendArea.containsMouse && sendDisc.ready ? 0.85 : 1

        Accessible.role: Accessible.Button
        Accessible.name: "Send reply"

        Behavior on color {
          Tint {}
        }

        StrokeIcon {
          anchors.centerIn: parent
          size: 18
          strokeWidth: 1.75
          path: IconPaths.send
          color: sendDisc.ready ? Theme.inkOnAccent : Theme.inkTertiary
        }

        MouseArea {
          id: sendArea

          anchors.fill: parent
          enabled: sendDisc.ready
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: toast.host.sendReply(replyInput.text)
        }
      }
    }
  }

  // "+2": the toasts waiting behind this one.
  component QueueChip: Rectangle {
    id: chip

    property int count: 0
    property bool shown: true

    // The last number worth drawing, so it can fade out with the chip rather than before it.
    property int last: 0
    // Which of the two digits is the front one: each count change swaps them over.
    property bool flip: false

    onCountChanged: {
      if (chip.count <= 0 || chip.count === chip.last)
        return;
      if (chip.last > 0)
        chip.flip = !chip.flip;
      (chip.flip ? digitB : digitA).text = "+" + chip.count;
      chip.last = chip.count;
    }

    width: Theme.notifChipWidth
    height: Theme.notifChipHeight
    radius: height / 2
    color: Theme.withAlpha(Theme.highlightMed, Theme.notifActionSecondaryAlpha)
    opacity: chip.shown && chip.count > 0 ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
      Morph {
        duration: Theme.duration(Theme.morphContent)
      }
    }

    Accessible.role: Accessible.StaticText
    Accessible.name: chip.count + " more notifications"

    ChipDigit {
      id: digitA

      front: !chip.flip
    }

    ChipDigit {
      id: digitB

      front: chip.flip
    }
  }

  // One of the chip's two digits; the count change cross-fades them.
  component ChipDigit: Text {
    required property bool front

    anchors.centerIn: parent
    color: Theme.inkPrimary
    opacity: front ? 1 : 0
    font.family: Theme.uiFont
    font.pixelSize: Theme.notifChipSize
    font.weight: Theme.weightSemi

    Behavior on opacity {
      Morph {
        duration: Theme.duration(Theme.morphContent)
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
