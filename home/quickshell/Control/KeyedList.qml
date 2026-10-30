import QtQuick
import qs.Commons
import qs.Ui

// A column of rows that keeps its delegates across updates. sync() takes the list as it now
// stands - a plain object per row, a unique string `key` and the fields the delegate reads -
// and edits a keyed model in place: keys that are gone are removed, new ones inserted,
// reordered ones moved, and changed fields set on the entry that already exists. A scan result,
// a property change or PipeWire churn therefore never rebuilds a delegate, so its hover, a
// half-typed password and a slider mid-drag all survive. Rows fade in, fade out and glide when
// displaced as the Launcher's do; the height is the content's, so the panel's own spring is
// what makes the growing and shrinking read as one motion.
Item {
  id: root

  // Key -> the live object behind a row (a network, a device, a node), for what a row does
  // that its plain fields cannot: connecting, pairing, choosing a default.
  property var objects: ({})

  // False while the view is off screen: rows then change without moving, as they always did.
  property bool animated: true

  // The first fill lands as the view is built, so it is placed rather than faded in.
  property bool primed: false

  readonly property ListModel store: ListModel {}

  function objectFor(key) {
    return objects[key] || null;
  }

  function sync(rows, backing) {
    objects = backing || ({});
    var entries = [];
    var keys = [];
    for (var n = 0; n < rows.length; n++) {
      if (keys.indexOf(rows[n].key) === -1) {
        keys.push(rows[n].key);
        entries.push(rows[n]);
      }
    }
    for (var i = store.count - 1; i >= 0; i--) {
      if (keys.indexOf(store.get(i).key) === -1)
        store.remove(i);
    }
    for (var j = 0; j < entries.length; j++) {
      var at = -1;
      for (var k = j; k < store.count; k++) {
        if (store.get(k).key === keys[j]) {
          at = k;
          break;
        }
      }
      if (at === -1) {
        store.insert(j, entries[j]);
        continue;
      }
      if (at !== j)
        store.move(at, j, 1);
      var row = store.get(j);
      for (var field in entries[j]) {
        if (row[field] !== entries[j][field])
          store.setProperty(j, field, entries[j][field]);
      }
    }
  }

  property alias delegate: view.delegate
  readonly property alias count: view.count

  height: view.contentHeight

  // The view keeps one height, far past any list here, and this item reports the content's.
  // A view whose own height follows its content is resized in the middle of the change, which
  // cut a removed row off at once instead of letting it fade.
  ListView {
    id: view

    width: root.width
    height: 4096
    model: root.store
    spacing: Theme.controlRowGap
    interactive: false
    // No current row: a view with one hands it the focus whenever the rows around it change,
    // which closed a password field that was being typed in.
    currentIndex: -1

    Timer {
      running: true
      interval: Theme.morphSurface
      onTriggered: root.primed = true
    }

    // A new row waits a beat while the rows below glide apart, then fades into the gap.
    add: Transition {
      enabled: root.animated && root.primed

      SequentialAnimation {
        PropertyAction {
          property: "opacity"
          value: 0
        }
        PauseAnimation {
          duration: Theme.morphContent
        }
        NumberAnimation {
          property: "opacity"
          to: 1
          duration: Theme.morphState
        }
      }
    }

    remove: Transition {
      enabled: root.animated && root.primed

      NumberAnimation {
        property: "opacity"
        to: 0
        duration: Theme.morphState
      }
    }

    // Survivors travel on an OutCubic ease for the surface duration, so two can be seen
    // crossing, not shoving. A row that moved itself rides the same ease.
    displaced: Transition {
      enabled: root.animated && root.primed

      Morph {
        properties: "y"
        duration: Theme.duration(Theme.morphSurface)
      }

      NumberAnimation {
        property: "opacity"
        to: 1
        duration: Theme.morphState
      }
    }

    // The rows under a removal hold for the first of its fade, so they do not slide over a
    // row that is still mostly there.
    removeDisplaced: Transition {
      enabled: root.animated && root.primed

      SequentialAnimation {
        PauseAnimation {
          duration: Theme.morphContent
        }

        ParallelAnimation {
          Morph {
            properties: "y"
            duration: Theme.duration(Theme.morphSurface)
          }

          NumberAnimation {
            property: "opacity"
            to: 1
            duration: Theme.morphState
          }
        }
      }
    }

    move: Transition {
      enabled: root.animated && root.primed

      Morph {
        properties: "y"
        duration: Theme.duration(Theme.morphSurface)
      }
    }
  }
}
