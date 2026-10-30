import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services
import "../Commons/Meeting.js" as Meeting

// The next timed calendar event as an activity: a satellite from a quarter of an hour ahead that
// counts the minutes down in gold, turns into a gold disc with a pulsing halo when the event
// begins, and goes a few minutes later. At ten minutes ahead it also raises a reminder moment,
// once per event: the ones raised are kept in a state file, so a shell reload or restart inside
// the window does not ring again. All-day events never show.
//
// `Calendar.upcoming` is its data (Services/Calendar.qml); `fake` stands in for it in tests.
Scope {
  id: root

  // For tests: events in Calendar's shape, in place of the real feed.
  property var fake: null

  readonly property var events: root.fake !== null ? root.fake : Calendar.upcoming

  property real now: Date.now()

  // Event ids the user is done with (joined), until the shell restarts.
  property var done: ({})
  // Event ids already reminded of, id -> start time in ms; persisted.
  property var reminded: ({})

  function idOf(e) {
    return e.calendar + "|" + e.title + "|" + e.start.getTime();
  }

  // The earliest timed event inside its window: from `eventLeadMinutes` ahead until
  // `eventLingerMinutes` after its start, and not dismissed.
  readonly property var current: {
    var lead = Theme.eventLeadMinutes * 60000;
    var linger = Theme.eventLingerMinutes * 60000;
    var list = root.events;
    for (var i = 0; i < list.length; i++) {
      var e = list[i];
      if (e.allDay)
        continue;
      var left = e.start.getTime() - root.now;
      if (left > lead)
        break;
      if (left < -linger || root.done[root.idOf(e)] === true)
        continue;
      return e;
    }
    return null;
  }

  // The last one it had, for a satellite and a card that fade out showing what they showed.
  property var seen: null
  onCurrentChanged: if (current !== null)
    seen = current

  function minutesTo(e) {
    return e ? Math.max(0, Math.ceil((e.start.getTime() - root.now) / 60000)) : 0;
  }

  function started(e) {
    return e !== null && e.start.getTime() <= root.now;
  }

  function range(e) {
    return e ? Qt.formatTime(e.start, "HH:mm") + " – " + Qt.formatTime(e.end, "HH:mm") : "";
  }

  // { service, url } or null.
  function linkOf(e) {
    return e ? Meeting.find(e.url, e.location, e.description) : null;
  }

  // ---- what the buttons do ----

  function join(e) {
    var link = root.linkOf(e);
    if (link === null)
      return;
    opener.exec(["xdg-open", link.url]);
    var next = Object.assign({}, root.done);
    next[root.idOf(e)] = true;
    root.done = next;
  }

  function openCalendar(e) {
    Activities.closeCard();
    if (e)
      Calendar.selectDay(e.start);
    Bus.toggleSurface("calendar");
  }

  Command {
    id: opener

    label: "Join meeting"
  }

  Timer {
    interval: 1000
    running: root.events.length > 0
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.now = Date.now();
      root.remind();
    }
  }

  // ---- the satellite ----

  Activity {
    id: act

    readonly property var e: root.seen
    readonly property bool starting: root.started(root.current)

    kind: "event"
    key: "event"
    active: root.current !== null
    attention: starting
    since: e ? e.start.getTime() - Theme.eventLeadMinutes * 60000 : 0

    text: starting ? "" : String(root.minutesTo(root.current))
    textColor: Theme.gold
    textSize: 14
    caption: starting ? "" : "min"
    icon: IconPaths.calendarClock
    iconColor: starting ? Theme.inkOnAccent : Theme.inkPrimary
    ground: starting ? Theme.gold : Theme.surface
    haloColor: Theme.gold

    chipColor: Theme.gold
    title: e ? e.title : ""
    subtitle: root.range(e)
    value: starting ? "now" : root.minutesTo(root.current) + "m"

    card: Component {
      EventCard {
        source: root
      }
    }
  }

  // ---- the reminder ----

  property int momentId: 0

  // At ten minutes ahead, once per event; and the reminder goes when its event begins.
  function remind() {
    var list = root.events;
    var ahead = Theme.eventRemindMinutes * 60000;
    for (var i = 0; i < list.length; i++) {
      var e = list[i];
      var left = e.start.getTime() - root.now;
      if (e.allDay || left <= 0 || left > ahead)
        continue;
      var id = root.idOf(e);
      if (root.reminded[id] !== undefined)
        continue;
      var next = Object.assign({}, root.reminded);
      next[id] = e.start.getTime();
      root.reminded = next;
      root.save();
      root.raise(e);
    }
    if (root.momentId !== 0 && !root.reminding()) {
      Activities.dismissMoment(root.momentId);
      root.momentId = 0;
    }
  }

  // Whether the event the reminder is about is still ahead.
  property real remindedStart: 0
  function reminding() {
    return root.remindedStart > root.now;
  }

  function raise(e) {
    var link = root.linkOf(e);
    var mins = root.minutesTo(e);
    var buttons = [];
    if (link !== null)
      buttons.push({
        text: "Join",
        kind: "primary",
        width: 64,
        action: function () {
          root.join(e);
        }
      });
    root.remindedStart = e.start.getTime();
    root.momentId = Activities.raiseMoment({
      kind: "event-reminder",
      key: "event-reminder",
      attention: true,
      icon: IconPaths.calendarClock,
      iconColor: Theme.gold,
      title: e.title,
      subtitle: "in " + mins + " min" + (e.location !== "" ? " · " + e.location : ""),
      dwell: 0,
      buttons: buttons
    });
  }

  // ---- surviving a reload ----

  function save() {
    // A day is long enough to know an event has passed.
    var keep = {};
    var cutoff = Date.now() - 86400000;
    for (var id in root.reminded) {
      if (root.reminded[id] > cutoff)
        keep[id] = root.reminded[id];
    }
    root.reminded = keep;
    store.setText(JSON.stringify(keep));
  }

  FileView {
    id: store

    path: Paths.stateDir + "/event-reminders.json"
    // Read at once, so the first tick cannot remind of what a previous run already did.
    blockLoading: true
    printErrors: false

    onLoaded: {
      var saved = {};
      try {
        saved = JSON.parse(store.text()) || {};
      } catch (err) {
        saved = {};
      }
      root.reminded = Object.assign(saved, root.reminded);
    }
  }
}
