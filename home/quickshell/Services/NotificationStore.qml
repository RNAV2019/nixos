pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Commons

// The notification server and the two lists it feeds: `popups` gets the live objects
// for toasts, `history` a snapshot so a control-centre row outlives its toast.
Singleton {
  id: root

  readonly property int defaultTimeout: 5000
  readonly property int maxPopups: 3
  readonly property int maxHistory: 50

  // Peace mode. Toasts other than critical ones are suppressed, but everything still lands in the list.
  property bool peace: false

  property var popups: []

  ListModel {
    id: historyModel
  }

  readonly property var history: historyModel

  property int _seq: 0

  function _snapshot(n) {
    return {
      key: ++root._seq,
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
    if (index >= 0 && index < historyModel.count)
      historyModel.remove(index);
  }

  function clear() {
    historyModel.clear();
  }

  NotificationServer {
    id: server

    keepOnReload: false
    actionsSupported: true
    imageSupported: true
    bodySupported: true
    bodyMarkupSupported: true

    onNotification: function (notification) {
      historyModel.insert(0, root._snapshot(notification));
      while (historyModel.count > root.maxHistory)
        historyModel.remove(historyModel.count - 1);

      // Critical ones, like the battery's last warning, still break through peace.
      if (root.peace && notification.urgency !== NotificationUrgency.Critical)
        return;

      notification.tracked = true;

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
