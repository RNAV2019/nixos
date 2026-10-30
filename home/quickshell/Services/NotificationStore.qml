pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.Commons

// The notification server and the two lists it feeds: `popups` gets the live objects
// for toasts, `history` a snapshot so a control-centre row outlives its toast.
Singleton {
  id: root

  readonly property int defaultTimeout: 5000
  // The toast in front and the ones queued behind it; each one past the front is a "+1".
  readonly property int maxPopups: 6
  readonly property int maxHistory: 50

  // Raised once for every notification that is announced, a toast on its way, never for one
  // Peace holds back to the list. `urgent` is a critical one. The hook for anything that should
  // sound when one arrives.
  signal notified(bool urgent)

  // Peace mode. Toasts other than critical ones are suppressed, but everything still lands in the list.
  property bool peace: false

  // Peace survives a reboot: every change to the flag is saved, and the saved one is
  // applied once the file is read at startup, unless a toggle has already landed.
  property bool _peaceTouched: false

  onPeaceChanged: {
    root._peaceTouched = true;
    peaceState.setText(root.peace ? "1" : "0");
  }

  FileView {
    id: peaceState

    path: Paths.stateDir + "/peace"
    printErrors: false

    onLoaded: {
      if (root._peaceTouched)
        return;
      if (peaceState.text().trim() === "1")
        root.peace = true;
    }
  }

  property var popups: []

  ListModel {
    id: historyModel
  }

  readonly property var history: historyModel

  // Counts every change to the list, so a view that groups it knows when to look again.
  property int revision: 0

  property int _seq: 0

  function _snapshot(n) {
    return {
      key: ++root._seq,
      arrived: Date.now(),
      appName: n.appName ? String(n.appName) : "Notification",
      summary: n.summary ? String(n.summary) : "",
      body: n.body ? String(n.body) : "",
      image: n.image ? String(n.image) : "",
      appIcon: n.appIcon ? String(n.appIcon) : "",
      desktopEntry: n.desktopEntry ? String(n.desktopEntry) : "",
      urgent: n.urgency === NotificationUrgency.Critical
    };
  }

  // Neither field can be trusted: either may hold a path, data URI or bare theme name.
  // A bare name handed to IconImage resolves against the module dir and fails, so try both.
  function _resolve(candidate) {
    if (!candidate)
      return "";
    var s = String(candidate);
    // Quickshell wraps an app icon as image://icon/<name>, and that provider paints a
    // placeholder rather than failing, so unwrap and ask the theme instead.
    if (s.indexOf("image://icon/") === 0)
      return Quickshell.iconPath(s.substring(13), true);
    if (s.indexOf("/") === 0 || s.indexOf("://") > 0 || s.indexOf("data:") === 0)
      return s;
    // "" when the theme has no such icon, which is the letter's cue.
    return Quickshell.iconPath(s, true);
  }

  // Per-app icon overrides, keyed by desktop entry or, failing that, app name. A value is
  // anything _resolve takes: a theme icon name, an absolute path, or a URL. An override beats
  // both fields the sender filled, so it also covers apps that ship raw image data. Overrides
  // are glyphs: only their alpha is kept, inked in the avatar's accent (see Ui/NotificationIcon).
  readonly property var appIcons: ({
      "Battery": Qt.resolvedUrl("../Assets/notification-icons/battery.svg"),
      "Screen Recorder": Qt.resolvedUrl("../Assets/notification-icons/recorder.svg"),
      // nm-applet notifies through GNotification: this desktop entry, and the app name it sets.
      "org.freedesktop.network-manager-applet": Qt.resolvedUrl("../Assets/notification-icons/wifi.svg"),
      "NetworkManager Applet": Qt.resolvedUrl("../Assets/notification-icons/wifi.svg")
    })

  function _override(key) {
    return key && Object.prototype.hasOwnProperty.call(root.appIcons, key) ? root.appIcons[key] : "";
  }

  function _custom(desktopEntry, appName) {
    return root._resolve(root._override(desktopEntry) || root._override(appName));
  }

  function iconFor(image, appIcon, desktopEntry, appName) {
    return root._custom(desktopEntry, appName) || root._resolve(image) || root._resolve(appIcon);
  }

  // True when iconFor's answer is an override, which is drawn in the theme's accent.
  function iconTinted(desktopEntry, appName) {
    return root._custom(desktopEntry, appName) !== "";
  }

  // The letter avatar the card draws when an application ships no icon.
  function initial(name) {
    return name && name.length > 0 ? name.charAt(0).toUpperCase() : "?";
  }

  // A custom icon is one of the shell's own marks, so it wears the theme's accent as the control
  // centre's tiles do. Other senders get a stable colour per application, independent of
  // arrival order, so their letter avatars stay apart.
  function avatarColour(name, tinted) {
    return tinted ? Theme.accent : Theme.stableAccent(name);
  }

  function forgetPopup(notification) {
    var next = [];
    for (var i = 0; i < popups.length; i++) {
      if (popups[i] !== notification)
        next.push(popups[i]);
    }
    popups = next;
  }

  function dismiss(index) {
    if (index >= 0 && index < historyModel.count) {
      historyModel.remove(index);
      root.revision++;
    }
  }

  // By the row's own key, which still names it after the list has shifted under a view.
  function dismissKey(key) {
    for (var i = 0; i < historyModel.count; i++) {
      if (String(historyModel.get(i).key) === String(key)) {
        root.dismiss(i);
        return;
      }
    }
  }

  // Every row from one application.
  function clearApp(appName) {
    var removed = false;
    for (var i = historyModel.count - 1; i >= 0; i--) {
      if (historyModel.get(i).appName === appName) {
        historyModel.remove(i);
        removed = true;
      }
    }
    if (removed)
      root.revision++;
  }

  function clear() {
    historyModel.clear();
    root.revision++;
  }

  // The list bucketed by application, as plain rows for a keyed list: the application whose
  // notification came last first, each with its count and its newest entry's text.
  function groupRows() {
    var order = [];
    var seen = {};
    for (var i = 0; i < historyModel.count; i++) {
      var n = historyModel.get(i);
      if (!Object.prototype.hasOwnProperty.call(seen, n.appName)) {
        seen[n.appName] = order.length;
        order.push({
          key: n.appName,
          appName: n.appName,
          count: 0,
          summary: n.summary,
          body: n.body,
          image: n.image,
          appIcon: n.appIcon,
          desktopEntry: n.desktopEntry,
          urgent: n.urgent,
          arrived: n.arrived
        });
      }
      order[seen[n.appName]].count++;
    }
    return order;
  }

  // One application's notifications, newest first, the same way.
  function entryRows(appName) {
    var rows = [];
    for (var i = 0; i < historyModel.count; i++) {
      var n = historyModel.get(i);
      if (n.appName === appName)
        rows.push({
          key: String(n.key),
          appName: n.appName,
          summary: n.summary,
          body: n.body,
          image: n.image,
          appIcon: n.appIcon,
          desktopEntry: n.desktopEntry,
          urgent: n.urgent,
          arrived: n.arrived
        });
    }
    return rows;
  }

  // "now", "5 min ago", "2 h ago" for a row's arrival; read `clock` to have it follow the minute.
  function ago(arrived, clock) {
    var mins = Math.floor((Date.now() - arrived) / 60000);
    if (mins < 1)
      return "now";
    if (mins < 60)
      return mins + " min ago";
    var hours = Math.floor(mins / 60);
    return hours < 24 ? hours + " h ago" : Math.floor(hours / 24) + " d ago";
  }

  NotificationServer {
    id: server

    keepOnReload: false
    actionsSupported: true
    imageSupported: true
    bodySupported: true
    bodyMarkupSupported: true
    // Advertised, so a chat app offers its reply box; the toast shows one for those that do.
    inlineReplySupported: true

    onNotification: function (notification) {
      historyModel.insert(0, root._snapshot(notification));
      while (historyModel.count > root.maxHistory)
        historyModel.remove(historyModel.count - 1);
      root.revision++;

      // Critical ones and the battery's own warnings (see Battery.qml) still break through peace.
      if (root.peace && notification.urgency !== NotificationUrgency.Critical && notification.appName !== "Battery")
        return;

      notification.tracked = true;
      root.notified(notification.urgency === NotificationUrgency.Critical);

      // One toast per application: a second arrival replaces the first.
      var next = root.popups.slice();
      for (var i = 0; i < next.length; i++) {
        if (next[i].appName === notification.appName) {
          next[i].dismiss();
          next.splice(i, 1);
          break;
        }
      }

      next.unshift(notification);
      while (next.length > root.maxPopups) {
        next[next.length - 1].dismiss();
        next.pop();
      }
      root.popups = next;
    }
  }
}
