import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Ui

// The control centre's notifications, grouped by application: the application that notified last
// first, each group newest first. The store's list stays flat; this buckets it into rows for a
// keyed list, so a notification arriving or leaving edits the groups in place instead of
// rebuilding them. Opening and closing groups is kept per application until the panel closes.
Item {
  id: root

  // Rows are only animated while the panel is up.
  property bool active: true

  readonly property alias contentHeight: list.height
  height: list.height
  readonly property int groups: list.count

  // The groups the reader has opened or closed themselves, by application; everything else
  // follows the default, which opens the application that notified last.
  property var chosen: ({})
  property string newest: ""

  function isOpen(appName) {
    return Object.prototype.hasOwnProperty.call(root.chosen, appName) ? root.chosen[appName] : appName === root.newest;
  }

  function toggle(appName) {
    var next = Object.assign({}, root.chosen);
    next[appName] = !root.isOpen(appName);
    root.chosen = next;
  }

  // Back to the default, for a panel that has just opened.
  function reset() {
    root.chosen = ({});
  }

  function refresh() {
    var rows = NotificationStore.groupRows();
    root.newest = rows.length > 0 ? rows[0].key : "";
    list.sync(rows);
  }

  Component.onCompleted: root.refresh()

  Connections {
    target: NotificationStore

    function onRevisionChanged() {
      root.refresh();
    }
  }

  // The age on every row moves on the minute.
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

  KeyedList {
    id: list

    width: parent.width
    spacing: Theme.controlNotifGap
    animated: root.active

    delegate: NotificationGroup {
      id: group

      width: list.width
      expanded: root.isOpen(group.appName)
      clockDate: clock.date
      onToggled: root.toggle(group.appName)
    }
  }
}
