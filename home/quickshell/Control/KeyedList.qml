import QtQuick
import qs.Commons
import qs.Ui

// A column of rows that keeps its delegates across updates. sync() takes the list as it now
// stands - a plain object per row, a unique string `key` and the fields the delegate reads -
// and edits a keyed model in place: keys that are gone are removed, new ones inserted,
// reordered ones moved, and changed fields set on the entry that already exists. A scan result,
// a property change or PipeWire churn therefore never rebuilds a delegate, so its hover, a
// half-typed password and a slider mid-drag all survive. Rows fade in and rise, fade out and shrink, and
// make room for each other as the Launcher's do (Theme.listEnter and its neighbours); the height is the content's, so the panel's own spring is
// what makes the growing and shrinking read as one motion.
Item {
  id: root

  // Key -> the live object behind a row (a network, a device, a node), for what a row does
  // that its plain fields cannot: connecting, pairing, choosing a default.
  property var objects: ({})

  // The space between rows; the control centre's lists keep its row gap.
  property real gap: Theme.controlRowGap

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
    spacing: root.gap
    interactive: false
    // No current row: a view with one hands it the focus whenever the rows around it change,
    // which closed a password field that was being typed in.
    currentIndex: -1

    Timer {
      running: true
      interval: Theme.morphSurface
      onTriggered: root.primed = true
    }

    // A new row waits a beat while the rows below start apart, then fades in and rises the last
    // few px into the gap (Theme.listEnter, listRise).
    add: Transition {
      id: arrive

      enabled: root.animated && root.primed

      SequentialAnimation {
        PropertyAction {
          property: "opacity"
          value: 0
        }
        PauseAnimation {
          duration: Theme.morphContent
        }
        ParallelAnimation {
          NumberAnimation {
            property: "opacity"
            to: 1
            duration: Theme.listEnter
            easing.type: Easing.OutCubic
          }
          NumberAnimation {
            property: "y"
            from: arrive.ViewTransition.destination.y + Theme.listRise
            duration: Theme.listEnter
            easing.type: Easing.OutCubic
          }
        }
      }
    }

    // Quick, and a little smaller as it goes, so it is out of the way of the rows closing over it.
    remove: Transition {
      enabled: root.animated && root.primed

      NumberAnimation {
        property: "opacity"
        to: 0
        duration: Theme.listExit
        easing.type: Easing.OutCubic
      }
      NumberAnimation {
        property: "scale"
        to: Theme.listExitScale
        duration: Theme.listExit
        easing.type: Easing.OutCubic
      }
    }

    // The rows around a change make room on the spring's curve (Theme.listEase), and start with
    // the change, not after it: its soft start is what keeps them off a row that is still fading.
    // A row that moved itself rides the same curve.
    displaced: Transition {
      enabled: root.animated && root.primed

      NumberAnimation {
        properties: "y"
        duration: Theme.listSettle
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.listEase
      }

      // A row caught on its way in or out is brought back whole.
      NumberAnimation {
        property: "opacity"
        to: 1
        duration: Theme.listEnter
        easing.type: Easing.OutCubic
      }
      NumberAnimation {
        property: "scale"
        to: 1
        duration: Theme.listEnter
        easing.type: Easing.OutCubic
      }
    }

    move: Transition {
      enabled: root.animated && root.primed

      NumberAnimation {
        properties: "y"
        duration: Theme.listSettle
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.listEase
      }
    }
  }
}
