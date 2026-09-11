pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Commons

// The notification server and the two lists it feeds. Toasts get the live Notification
// object in `popups`; the control centre gets a snapshot in `history`, so a row outlives
// the toast it came from.
Singleton {
  id: root

  readonly property int defaultTimeout: 5000
  readonly property int maxPopups: 3
  readonly property int maxHistory: 50

  // Peace mode. Toasts are suppressed, but notifications still land in the list.
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
      urgent: n.urgency === NotificationUrgency.Critical
    };
  }

  // Neither field can be trusted to load: an application may send a path, a data URI or
  // a bare theme name in either. A theme name handed to IconImage resolves against the
  // module directory and fails, so each candidate is resolved and the first hit wins.
  function _resolve(candidate) {
    if (!candidate)
      return "";
    var s = String(candidate);
    // Quickshell wraps an application icon as image://icon/<name>, and that provider
    // paints a placeholder rather than failing, so unwrap and ask the theme instead.
    if (s.indexOf("image://icon/") === 0)
      return Quickshell.iconPath(s.substring(13), true);
    if (s.indexOf("/") === 0 || s.indexOf("://") > 0 || s.indexOf("data:") === 0)
      return s;
    // "" when the theme has no such icon, which is the letter's cue.
    return Quickshell.iconPath(s, true);
  }

  function iconFor(image, appIcon) {
    return root._resolve(image) || root._resolve(appIcon);
  }

  // The letter avatar the card draws when an application ships no icon.
  function initial(name) {
    return name && name.length > 0 ? name.charAt(0).toUpperCase() : "?";
  }

  // A stable colour per application, independent of arrival order.
  function avatarColour(name) {
    var palette = [Theme.foam, Theme.iris, Theme.gold, Theme.rose, Theme.pine];
    var h = 0;
    for (var i = 0; i < name.length; i++)
      h = (h * 31 + name.charCodeAt(i)) % 997;
    return palette[h % palette.length];
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

      if (root.peace)
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
