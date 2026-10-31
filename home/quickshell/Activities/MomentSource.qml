import QtQuick
import qs.Services

// What every source of moments shares: it raises one kind of moment, remembers which it has
// on the queue, can take it back, and hears when the user dismisses it. A source that has a
// test stand-in names it `fake`, for the shell's `activities` IPC to set.
QtObject {
  id: root

  // Names the moment for tests and for `momentDismissed`, and is its key, so raising it again
  // while the first still waits replaces that one.
  property string kind: ""

  // The moment this source has queued, 0 for none.
  property int momentId: 0

  // Emitted when the user dismisses the moment, by acting on it or swiping it away; not when
  // the source withdraws it.
  signal dismissed

  property bool _withdrawing: false

  // Queues the moment `spec` describes (see Services/Activities.qml).
  function show(spec) {
    momentId = Activities.raiseMoment(Object.assign({
      kind: kind,
      key: kind
    }, spec));
  }

  // Whether the moment this raised is still queued (a test hook can clear them all).
  function queued() {
    for (var i = 0; i < Activities.moments.length; i++) {
      if (Activities.moments[i].id === momentId)
        return true;
    }
    return false;
  }

  function withdraw() {
    if (momentId === 0)
      return;
    _withdrawing = true;
    Activities.dismissMoment(momentId);
    _withdrawing = false;
    momentId = 0;
  }

  property Connections _queue: Connections {
    target: Activities

    function onMomentDismissed(gone) {
      if (gone !== root.kind || root._withdrawing)
        return;
      root.momentId = 0;
      root.dismissed();
    }
  }
}
