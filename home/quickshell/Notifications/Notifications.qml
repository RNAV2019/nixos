import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Ui

// The toast: the island grows into a 450 px card, then melts back into the clock.
// One card at a time; the ones waiting peek out under it and are counted on it. Only the card
// takes input.
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

    // How many wait behind it.
    readonly property int queued: Math.max(0, NotificationStore.popups.length - 1)

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
}
