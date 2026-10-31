import QtQuick
import qs.Commons

// One row of tiles asking which of these, then doing it once the card has gone: the power menu
// and the power profiles card. A tile that `confirms` arms on the first press and commits on
// the second; the rest commit at once. Committing closes the card and waits out the pill's
// settle-back before `committed` fires, so the eye never sees the card linger over a done
// change.
Panel {
  id: root

  // Entries of { glyph, label, confirms }.
  property var model: []
  property int inset: Theme.powerInset

  // The tile filled while nothing is armed, if any: the profile in use.
  property int marked: -1
  // Nothing answering greys the tiles out and makes a press do nothing.
  property bool available: true
  // Where the keyboard starts when the card opens.
  property int initialIndex: 0

  // Which tile the keyboard is on, and which is armed, or -1.
  property int current: 0
  property int armed: -1

  // Which tile's action is queued behind the settle-back, or -1. One slot, so a second commit
  // cannot queue a second shutdown.
  property int pending: -1

  readonly property int contentWidth: tiles.contentWidth

  // The tile whose action fires once the card is gone.
  signal committed(int index)

  function move(delta) {
    // Moving disarms, so an armed tile is never left waiting for a later Return.
    root.armed = -1;
    root.current = (root.current + delta + tiles.count) % tiles.count;
  }

  function activate(i) {
    root.current = i;
    if (!root.available)
      return;

    if (root.model[i].confirms && root.armed !== i) {
      root.armed = i;
      return;
    }

    // A commit for a tile already queued is a no-op, not a second one.
    if (root.pending === i)
      return;
    root.pending = i;

    root.surface.hide();
    settle.restart();
  }

  // The card is back, so the user is choosing again.
  function cancel() {
    root.pending = -1;
    settle.stop();
  }

  Connections {
    target: root.surface

    function onOpening() {
      root.current = root.initialIndex;
      root.armed = -1;
      root.cancel();
    }
  }

  Connections {
    target: Bus

    // Another surface taking the island means the user moved on; nothing fires under it.
    function onIslandClaimed(screen) {
      if (root.pending >= 0 && root.surface.screen && screen === root.surface.screen.name)
        root.cancel();
    }
  }

  Timer {
    id: settle

    interval: Theme.actionSettleDelay
    onTriggered: {
      var i = root.pending;
      root.pending = -1;
      root.committed(i);
    }
  }

  // Escape stands an armed tile down; with none armed it falls through and closes.
  backKeys: root.armed >= 0
  takesMove: true
  takesTab: true
  takesActivate: true

  onBacked: root.armed = -1
  onMoved: function (dx, dy) {
    root.move(dx + dy);
  }
  onStepped: function (delta) {
    root.move(delta);
  }
  onActivated: root.activate(root.current)

  // With nothing answering, the tiles grey out. Nested, so the grey-out fades under the one
  // content fade the surface owns.
  Item {
    anchors.fill: parent
    opacity: root.available ? 1 : 0.5

    Behavior on opacity {
      Morph {
        duration: Theme.morphState
      }
    }

    ChoiceTiles {
      id: tiles

      inset: root.inset
      model: root.model
      currentIndex: root.current
      activeIndex: root.armed >= 0 ? root.armed : root.marked
      activeColor: Theme.love
      activeLabel: root.armed >= 0 ? "Confirm" : ""
      activeIsCommitting: root.armed >= 0
      onEntered: function (index) {
        if (root.armed < 0)
          root.current = index;
      }
      onActivated: function (index) {
        root.activate(index);
      }
    }
  }
}
