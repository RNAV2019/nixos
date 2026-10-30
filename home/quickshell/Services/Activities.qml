pragma Singleton

import QtQuick
import Quickshell
import qs.Commons

// Live activities: things that are going on and deserve a glance (a timer, a rebuild, a phone)
// without opening anything. The island shows each as a satellite, a small circle beside the
// shut pill, with a card that grows out of it on hover; and anything that happens at an instant
// (a timer done, a charger plugged in) is a moment, a transient surface that grows out of the
// pill itself. This singleton is the registry and the queue; the drawing is in Activities/.
//
// An activity (Services/Activity.qml) is a QtObject a service declares; it registers itself
// while `active` and is removed with its owner. Bind its look (`icon` or `text`, `ring`, the
// colours), `title` / `subtitle` / `value` for the overflow list and the generic card, and
// optionally a `card` Component for a hover card of its own (see Activities/TimerCard.qml):
//
//   Activity {
//     kind: "usb"
//     active: drive.mounted
//     icon: IconPaths.hardDrive
//     ring: drive.usedShare
//     title: drive.label
//     card: Component { UsbCard {} }
//   }
//
// Several at once come from an Instantiator whose delegate is an Activity (Activities/
// TimerSource.qml). A source lives in Activities/ and is listed once in ActivitySources.qml,
// which is what starts it with the shell. Without a file of its own an activity can be made
// and removed by hand:
//
//   Activities.register(activity)
//   Activities.remove(activity)
//   Activities.find(key)                 the registered activity with that key, or null
//
// Slots. At most two circles stand beside the pill. The phone (`pinned`) is always the first;
// an activity that needs the user (`attention`) takes the next visible one over a quieter one,
// and with three or more it takes the first, since "+N" would hide it; otherwise the oldest is
// nearest the pill. With three or more the second circle becomes "+N", whose card lists what the
// first does not show, oldest first. `slots` and `hidden` are what the satellites draw.
//
// Moments. `raiseMoment(spec)` queues one; they show one at a time on the island, an
// attention moment ahead of any informational one still waiting, and each waits its turn
// against the OSD, notifications and sharing by rank (Bus.transientWants: attention 1,
// informational 0, in order of arrival among equals). `spec` is a plain object:
//
//   kind        "timer-done"; names it for tests and for sounds to key on
//   key         optional; a second moment with the same key replaces the first
//   attention   true for one that wants the user (rank 1); false for information (rank 0)
//   icon, iconColor   a Lucide path and its role colour, drawn 20 px at the left
//   title, subtitle   the two lines; elide on the right inside the padding
//   buttons     [{ text, kind: "primary" | "secondary" | "ghost" | "danger", width?, keep?,
//               action? }], listed left to right so the last is at the right edge; acting
//               runs `action` and dismisses the moment unless `keep: true`
//   dwell       ms before it melts back by itself, held while the pointer is on it; 0 stays
//               until acted on (default Theme.momentDwell)
//   body        optional Component replacing the icon, lines and buttons (Activities/
//               PluggedBody.qml): an Item with `moment` (this spec) and, if it declares it,
//               `shown` (the island is showing it), laid out in `width` x `height`
//   data        anything the body wants; passed through untouched
//   width, height, radius   the shape; Theme.moment* (420 x 64, r 22) unless asked otherwise
//
//   var id = Activities.raiseMoment({ ... });
//   Activities.dismissMoment(id);
//
// `momentRaised(kind)` is emitted as each is raised, and `momentDismissed(kind)` as each goes:
// the place for a sound, which a later source connects to rather than this file knowing of it.
Singleton {
  id: root

  // ---- the registry ----

  property var items: []
  property int _serial: 0

  function register(activity) {
    if (items.indexOf(activity) !== -1)
      return;
    if (activity.key === "")
      activity.key = activity.kind + ":" + (++_serial);
    if (activity.since === 0)
      activity.since = Date.now() + _serial * 0.001;
    items = items.concat([activity]);
  }

  function remove(activity) {
    var at = items.indexOf(activity);
    if (at === -1)
      return;
    var next = items.slice();
    next.splice(at, 1);
    items = next;
  }

  function find(key) {
    for (var i = 0; i < items.length; i++) {
      if (items[i].key === key)
        return items[i];
    }
    return null;
  }

  // Nearest the pill first: the pinned one, then those that need the user, then oldest. With
  // three or more, an activity that needs the user goes before even the pinned one, or the "+N"
  // circle would hide it.
  readonly property var ordered: {
    var crowded = items.length > 2;
    var rankOf = function (a) {
      return a.attention && crowded ? 0 : a.pinned ? 1 : a.attention ? 2 : 3;
    };
    return items.slice().sort(function (a, b) {
      return rankOf(a) - rankOf(b) || a.since - b.since;
    });
  }

  // The circles drawn: up to two, or the first and "+N" past two.
  readonly property var slots: ordered.length > 2 ? [ordered[0]] : ordered

  // Behind the "+N" circle, oldest first; empty unless there are three or more.
  readonly property var hidden: {
    if (ordered.length <= 2)
      return [];
    return ordered.slice(1).sort(function (a, b) {
      return a.since - b.since;
    });
  }

  readonly property int circles: slots.length + (hidden.length > 0 ? 1 : 0)

  // ---- where they stand ----

  // The output the satellites sit beside: the focused one, else the first.
  readonly property string home: {
    var screens = Quickshell.screens;
    for (var i = 0; i < screens.length; i++) {
      if (Monitors.isFocused(screens[i]))
        return screens[i].name;
    }
    return screens.length > 0 ? screens[0].name : "";
  }

  // Written by the satellites on the home output, read by the pill's slide (Activities/PillSlide.qml):
  // how many circles stand beside the pill, counting one still leaving, and whether they are
  // folded away because the island is being used for something else.
  property int slideCount: 0
  property bool slideFolded: false

  // Whether the island on this output is taken by something else: any surface, transient or
  // card standing in for the pill or holding it. The satellites fold while this holds.
  function islandBusy(screenName) {
    return Bus.islandTaken(screenName) || Bus.islandCovered(screenName) || Bus.transientOnScreen(screenName) || Bus.islandHolders[screenName] !== undefined;
  }

  // ---- the hover card ----

  // The key of the activity whose card is up, "" for none. A card hangs under the satellite
  // that stands for it, or under "+N" when that activity is one it hides.
  property string cardKey: ""
  // Whether that card is the overflow list rather than an activity's own.
  property bool listOpen: false

  // Where the satellite that card hangs from stands, in screen coordinates; published by the
  // satellites on the home output.
  property real anchorX: 0
  property real anchorY: 0

  property string _overSatellite: ""
  property bool _overCard: false
  property string _pending: ""

  function hoverSatellite(key, on) {
    if (on) {
      _overSatellite = key;
      closeTimer.stop();
      if (cardKey !== key)
        _pending = key;
      if (cardKey !== key)
        openTimer.restart();
    } else {
      if (_overSatellite === key)
        _overSatellite = "";
      if (_pending === key)
        openTimer.stop();
      _settle();
    }
  }

  function hoverCard(on) {
    _overCard = on;
    if (on)
      closeTimer.stop();
    else
      _settle();
  }

  function _settle() {
    if (cardKey !== "" && _overSatellite === "" && !_overCard)
      closeTimer.restart();
  }

  function closeCard() {
    openTimer.stop();
    closeTimer.stop();
    _pending = "";
    _overCard = false;
    cardKey = "";
  }

  // The list's rows open their own activity's card in place of the list.
  function openCard(key) {
    cardKey = key;
  }

  Timer {
    id: openTimer

    interval: Theme.islandHoverOpenDelay
    onTriggered: {
      if (root._overSatellite === root._pending)
        root.cardKey = root._pending;
    }
  }

  Timer {
    id: closeTimer

    interval: Theme.islandHoverCloseDelay
    onTriggered: if (root._overSatellite === "" && !root._overCard)
      root.cardKey = ""
  }

  // Opening a card is seeing what was pulsing.
  onCardKeyChanged: {
    var seen = find(cardKey);
    if (seen)
      seen.acknowledged = true;
  }

  // A card for something that is gone closes.
  onItemsChanged: {
    if (cardKey !== "" && cardKey !== "+" && find(cardKey) === null)
      cardKey = "";
    if (cardKey === "+" && hidden.length === 0)
      cardKey = "";
  }

  // ---- moments ----

  // The queue; the head is the one on the island.
  property var moments: []
  readonly property var moment: moments.length > 0 ? moments[0] : null
  property int _momentSerial: 0

  signal momentRaised(string kind)
  signal momentDismissed(string kind)

  function raiseMoment(spec) {
    var m = {
      id: ++_momentSerial,
      kind: spec.kind || "",
      key: spec.key || "",
      attention: spec.attention === true,
      icon: spec.icon || "",
      iconColor: spec.iconColor !== undefined ? spec.iconColor : Theme.accent,
      title: spec.title || "",
      subtitle: spec.subtitle || "",
      buttons: spec.buttons || [],
      dwell: spec.dwell !== undefined ? spec.dwell : Theme.momentDwell,
      body: spec.body || null,
      data: spec.data || null,
      width: spec.width || Theme.momentWidth,
      height: spec.height || Theme.momentHeight,
      radius: spec.radius || Theme.momentRadius
    };
    var queue = moments.slice();
    if (m.key !== "") {
      for (var i = 0; i < queue.length; i++) {
        if (queue[i].key === m.key) {
          queue[i] = m;
          moments = queue;
          momentRaised(m.kind);
          return m.id;
        }
      }
    }
    // The one on the island is not displaced; an attention moment goes ahead of any quieter
    // one still waiting, behind the attention ones already queued.
    var at = queue.length;
    if (m.attention) {
      at = Math.min(1, queue.length);
      while (at < queue.length && queue[at].attention)
        at++;
    }
    queue.splice(at, 0, m);
    moments = queue;
    momentRaised(m.kind);
    return m.id;
  }

  function dismissMoment(id) {
    for (var i = 0; i < moments.length; i++) {
      if (moments[i].id !== id)
        continue;
      var gone = moments[i];
      var queue = moments.slice();
      queue.splice(i, 1);
      moments = queue;
      momentDismissed(gone.kind);
      return;
    }
  }

  function dismissAllMoments() {
    moments = [];
  }

  // ---- for tests ----

  // Stand-in activities for driving the satellites without their owners: `activities demo`.
  property var demos: []

  function addDemo(name) {
    demos = demos.concat([name]);
  }

  function clearDemos() {
    demos = [];
  }
}
