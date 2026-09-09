pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Commons

// The one notification server, and the two lists it feeds.
//
// Toasts and the control centre want different things from the same event. A
// toast is a live Notification object: it owns the actions the user can invoke
// and it has to be dismissed on the bus when the toast goes away. The control
// centre's list is a record of what arrived, and it has to outlive the objects,
// because a toast that times out is closed on the bus while the row in the
// control centre stays until the user clears it.
//
// So the server pushes to both: the object goes to `popups`, and a snapshot of
// the fields the card draws goes to `history`. Nothing in the control centre
// holds a Notification, which is what lets a row survive its toast.
Singleton {
  id: root

  readonly property int defaultTimeout: 5000
  readonly property int maxPopups: 3
  readonly property int maxHistory: 50

  // Peace mode - do not disturb. Toasts are suppressed while it is on, but the
  // notifications still arrive and still land in the list, so nothing is lost
  // by turning it on.
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

  // What the card actually hands an Image.
  //
  // Neither field can be trusted to be loadable. An application may send a
  // path, a data URI or a bare icon-theme name in either of them, and
  // notify-send puts the name it was given in both. A name handed straight to
  // IconImage is read as a relative URL and resolved against the Quickshell
  // module directory, which is where "Cannot open: qrc:/.../audio-headset"
  // comes from: the load fails and the card falls through to its letter even
  // though the theme has the icon. So each candidate is resolved, and the
  // first one that resolves to something is the icon.
  function _resolve(candidate) {
    if (!candidate)
      return "";
    var s = String(candidate);
    // Quickshell hands an application icon through as image://icon/<name>, and
    // that provider paints a broken-image placeholder for a name the theme does
    // not have rather than failing the load. The theme lookup is the one thing
    // that answers honestly, so a name that arrived wrapped is unwrapped and
    // asked again.
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

  // A stable colour per application, so the same sender keeps the same avatar
  // between sessions rather than depending on arrival order.
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

      // One toast per application: a second arrival replaces the first rather
      // than stacking two cards from the same sender.
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
