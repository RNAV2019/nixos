pragma Singleton

import QtQuick
import Quickshell
import qs.Commons

// Moments: things that happen at an instant and deserve a glance (a charger plugged in, a
// network asking you to sign in), a transient surface that grows out of the island pill. This
// singleton is the queue; the drawing is Activities/Moments.qml and the sources that raise them
// are listed in Activities/ActivitySources.qml.
//
// `raiseMoment(spec)` queues one; they show one at a time, an attention moment ahead of any
// informational one still waiting, and each waits its turn against the OSD, notifications and
// sharing by rank (Bus.transientWants: attention 1, informational 0, in order of arrival among
// equals). `spec` is a plain object:
//
//   kind        "wifi-signin"; names it for tests
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
// `momentDismissed(kind)` is emitted as each goes, for a source to learn it was dismissed.
Singleton {
  id: root

  // The queue; the head is the one on the island.
  property var moments: []
  readonly property var moment: moments.length > 0 ? moments[0] : null
  property int _momentSerial: 0

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
}
