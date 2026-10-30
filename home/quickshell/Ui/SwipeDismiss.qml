import QtQuick
import qs.Commons

// Swipe a card away, sideways, with a pointer, a finger or two fingers on a touchpad. Size it over
// the card and put it above everything else in it, so a drag that starts on a button still
// swipes; a press and a click pass straight through. It draws nothing: the card reads `offset`
// and `fade` and moves itself.
//
// Held, the card follows the drag one to one. Let go, and it is dismissed when it has gone far
// enough (a share of its `span`) or was flung fast enough toward the side it is on; otherwise
// it settles back. Both ride the island's critically damped spring, so nothing overshoots, and
// a fling carries its speed into the exit. Vertical drags are left alone.
Item {
  id: root

  // The card's width, which the distances are shares of.
  property real span: 0

  // Where the card sits and how much of it is left: one at rest, nothing once it is a share
  // of its width away.
  readonly property real offset: spring.value
  readonly property real fade: 1 - Math.min(1, Math.abs(root.offset) / Math.max(1, Theme.notifSwipeFade * root.span))

  // The pointer or the fingers are on it, so whatever expires it should wait.
  readonly property bool held: drag.active || wheeling
  // Let go past the threshold: on its way out.
  property bool leaving: false

  property bool wheeling: false

  // Raised at the moment of release that dismisses, and again once the card has faded out of
  // sight, so its owner can drop it with nothing left to see.
  signal committed
  signal gone

  // Raised once per dismissal, a turn after the fade that caused it: what `gone` does ends by
  // resetting the card, and doing that inside the change that prompted it left `offset` stale.
  property bool sent: false

  function settle() {
    if (root.leaving && !root.sent && root.fade <= 0.02) {
      root.sent = true;
      Qt.callLater(function () {
        root.gone();
      });
    }
  }

  onFadeChanged: root.settle()

  // Back to rest at once, for a card that has been dismissed and is reused for the next.
  function reset() {
    root.leaving = false;
    root.sent = false;
    root.wheeling = false;
    wheelIdle.stop();
    root.samples = [];
    spring.animate = false;
    spring.target = 0;
    spring.animate = true;
  }

  // Sends the card off to one side without a gesture, e.g. from a key.
  function dismiss(direction) {
    root.release(direction * root.span * Theme.notifSwipeThreshold, 0);
  }

  MorphSpring {
    id: spring
  }

  // ---- gesture ----

  property var samples: []

  function sample(x, now) {
    var kept = root.samples.filter(function (s) {
      return now - s.t <= 100;
    });
    kept.push({
      t: now,
      x: x
    });
    root.samples = kept;
  }

  // Px/ms over the last 100 ms up to `until`; a pause before the release counts as slowing down.
  function speed(until) {
    var kept = root.samples.filter(function (s) {
      return until - s.t <= 100;
    });
    if (kept.length < 2)
      return 0;
    var first = kept[0];
    var last = kept[kept.length - 1];
    return until > first.t ? (last.x - first.x) / (until - first.t) : 0;
  }

  function follow(x) {
    if (root.leaving)
      return;
    spring.animate = false;
    spring.target = x;
    root.sample(x, Date.now());
  }

  function release(x, v) {
    if (root.leaving)
      return;
    var w = Math.max(1, root.span);
    var far = Math.abs(x) >= Theme.notifSwipeThreshold * w;
    var flung = Math.abs(v) >= Theme.notifSwipeVelocity && (x === 0 || v * x > 0);
    spring.animate = true;
    if (far || flung) {
      var side = x !== 0 ? Math.sign(x) : Math.sign(v);
      root.leaving = true;
      // Before the spring moves: with motion reduced it lands at once, and `gone` must follow.
      root.committed();
      spring.velocity = v * side > 0 ? v * 1000 : 0;
      spring.target = side * (w + Theme.notifSwipeExit);
      // Dragged all the way out before letting go, the card is already out of sight.
      root.settle();
    } else {
      spring.velocity = 0;
      spring.target = 0;
    }
    root.samples = [];
  }

  DragHandler {
    id: drag

    target: null
    xAxis.enabled: true
    yAxis.enabled: false
    acceptedButtons: Qt.LeftButton
    enabled: root.enabled && !root.leaving

    onActiveTranslationChanged: if (active)
      root.follow(activeTranslation.x)

    onActiveChanged: {
      if (active)
        return;
      var x = spring.target;
      root.release(x, root.speed(Date.now()));
    }
  }

  // Two fingers on a touchpad arrive as horizontal wheel events, with no release of their own:
  // the swipe ends when they stop.
  WheelHandler {
    orientation: Qt.Horizontal
    acceptedDevices: PointerDevice.TouchPad
    enabled: root.enabled && !root.leaving

    onWheel: function (event) {
      var dx = event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x / 4;
      if (dx === 0)
        return;
      root.wheeling = true;
      root.follow(spring.target + dx);
      wheelIdle.restart();
    }
  }

  Timer {
    id: wheelIdle

    interval: 120
    onTriggered: {
      var last = root.samples.length > 0 ? root.samples[root.samples.length - 1].t : Date.now();
      root.wheeling = false;
      root.release(spring.target, root.speed(last));
    }
  }
}
