import QtQuick
import qs.Commons
import "Motion.js" as Motion

// A card that is thrown away sideways. Put one inside the card (it fills it and draws nothing),
// move the card by `offset` and dim it by `fade`: a press dragged sideways carries the card with
// the pointer one to one, and so do two fingers across a touchpad. Let go past
// Theme.swipeDismissAt of the card's width, or fast enough to coast there, and the card carries on
// out the way it was thrown at the speed it had, then `dismissed` fires once it has faded; short
// of that it comes back to rest on a spring that starts at the hand's speed.
//
// The first Theme.swipeSlop px of a press move nothing, so a click is still a click, and a button
// under the pointer keeps its press until the drag has really begun (then it loses it).
//
// It sits behind the card's own children, and that matters: a drag handler takes every press it
// sees, so anything clickable under it would never be pressed, while what lies over it is pressed
// first and only loses the press to a real drag. Where the card is clicked through to an area
// beneath it (a toast), name that area as `grip` and the drag is read there instead.
//
// It never comes back by itself after `dismissed`: the owner takes the card away, or calls
// reset() when the card is to show something else.
Item {
  id: swipe

  // The width the card is thrown across.
  property real extent: width
  // Names its spring in the motion log (`swipe.<name>`); empty keeps it out.
  property string name: ""
  // Two fingers across a touchpad throw it too. A list that scrolls keeps its vertical scroll:
  // only a gesture that sets out sideways is taken.
  property bool wheel: true
  // The item presses are read on; see above.
  property Item grip: swipe
  // Down for a card that is not the one on show: a grip can be shared.
  property bool armed: true

  // Where the card is drawn, in px from rest, and how much of it shows there.
  readonly property real offset: spring.value
  readonly property real fade: swipe.extent > 0 ? 1 - Motion.ramp(Math.abs(swipe.offset) / swipe.extent, 0, Theme.swipeFadeEnd) : 1
  // A hand has it.
  property bool held: false
  // Let go far or fast enough: it is on its way out, or gone.
  property bool thrown: false
  // In the hand or still travelling: what waits on the card (a toast's countdown) holds.
  readonly property bool busy: swipe.held || spring.running

  // The card has left; take it away.
  signal dismissed

  anchors.fill: parent
  // Behind the card's children; see above.
  z: -1

  // Where the card was when the hand took it (it can be caught on its way back), the hand's
  // travel that the slop swallowed, and the hand's recent speed.
  property real base: 0
  property real skip: 0
  property bool skipped: false
  property bool told: false
  readonly property var speed: Motion.tracker()

  // Back at rest at once, for a card about to show something else.
  function reset() {
    idle.stop();
    scroll.reach = 0;
    scroll.across = 0;
    scroll.taken = false;
    swipe.held = false;
    swipe.thrown = false;
    swipe.told = false;
    swipe.seat(0);
  }

  // Puts the spring on a value, at rest.
  function seat(v) {
    spring.animate = false;
    spring.target = v;
    spring.value = v;
    spring.velocity = 0;
    spring.animate = true;
  }

  function begin() {
    swipe.base = spring.value;
    swipe.skipped = false;
    swipe.skip = 0;
    swipe.speed.reset();
    swipe.held = true;
    // Down for as long as it is held, so every move lands at once.
    spring.animate = false;
    spring.target = swipe.base;
  }

  // The hand is `travel` px from where it pressed.
  function follow(travel) {
    if (!swipe.held)
      return;
    if (!swipe.skipped) {
      // The handler reports the whole travel since the press, slop included: without this the
      // card would jump that far as it starts.
      swipe.skip = Math.max(-Theme.swipeSlop, Math.min(Theme.swipeSlop, travel));
      swipe.skipped = true;
    }
    spring.target = swipe.base + travel - swipe.skip;
    swipe.speed.push(Date.now(), spring.target);
  }

  // The hand lets go; `still` when the gesture was taken from it rather than released.
  function release(still) {
    if (!swipe.held)
      return;
    swipe.held = false;
    var at = spring.value;
    var v = still ? 0 : swipe.speed.velocity(Date.now());
    var way = still ? 0 : Motion.thrown(at, v, Theme.swipeThrowRate, Theme.swipeDismissAt * swipe.extent);
    spring.animate = true;
    if (way !== 0) {
      swipe.thrown = true;
      // Held on a still spring until the target moves, on the next line.
      spring.kick(v);
      spring.target = way * swipe.extent;
    } else {
      // A speed heading out is kept whole (it runs out and turns round, never past rest); one
      // heading home is held to what lands without crossing.
      spring.kick(v * at > 0 ? v : Motion.seedVelocity(at, 0, v, spring.omega));
      spring.target = 0;
    }
    // Nowhere to go (let go at rest), or motion is off: no kick may wait for a later move.
    spring.settle();
    swipe.arrived();
  }

  // Tells the owner once, when the thrown card has faded out or stopped.
  function arrived() {
    if (!swipe.thrown || swipe.told)
      return;
    if (spring.running && Math.abs(spring.value) < Theme.swipeFadeEnd * swipe.extent)
      return;
    swipe.told = true;
    later.start();
  }

  // The next turn of the event loop: the owner may take the card, and this spring with it, away,
  // which must not happen inside the spring's own step.
  Timer {
    id: later

    interval: 0
    onTriggered: swipe.dismissed()
  }

  MorphSpring {
    id: spring

    // Critically damped: a card that comes back stops at rest, it does not pass it.
    damping: 1
    label: swipe.name !== "" ? "swipe." + swipe.name : ""
    onValueChanged: swipe.arrived()
    onRunningChanged: swipe.arrived()
  }

  DragHandler {
    id: drag

    parent: swipe.grip
    target: null
    enabled: swipe.armed && !swipe.thrown
    yAxis.enabled: false
    dragThreshold: Theme.swipeSlop
    acceptedButtons: Qt.LeftButton

    onActiveChanged: {
      if (active)
        swipe.begin();
      else
        swipe.release(false);
    }
    onActiveTranslationChanged: {
      if (active)
        swipe.follow(activeTranslation.x);
    }
    onCanceled: swipe.release(true)
  }

  // Two fingers on a touchpad. Only fingers report a phase, and only they are followed: a wheel
  // tilted sideways is a click, not a hand.
  WheelHandler {
    id: scroll

    // The fingers' travel in this gesture, along and across, and whether it has been taken as a
    // swipe (true) or left to whatever scrolls (false, until the fingers have been still).
    property real reach: 0
    property real across: 0
    property bool taken: false

    enabled: swipe.wheel && swipe.armed && !swipe.thrown && !drag.active
    orientation: Qt.Horizontal
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    // Until it is taken the event goes on to the list underneath, which may be scrolling.
    blocking: scroll.taken

    onWheel: function (event) {
      if (event.phase === Qt.NoScrollPhase)
        return;
      scroll.reach += event.pixelDelta.x;
      scroll.across += event.pixelDelta.y;
      if (!scroll.taken && !swipe.held) {
        // Sideways from the start, by a clear margin, or it is a scroll with a wobble in it.
        if (Math.abs(scroll.reach) > Theme.swipeSlop && Math.abs(scroll.reach) > 2 * Math.abs(scroll.across)) {
          scroll.taken = true;
          swipe.begin();
        }
      }
      if (scroll.taken)
        swipe.follow(scroll.reach);
      // The fingers lifting ends it at once; where that is not reported, the idle timer does.
      if (event.phase === Qt.ScrollEnd)
        idle.triggered();
      else
        idle.restart();
    }
  }

  Timer {
    id: idle

    interval: Theme.scrollIdle
    onTriggered: {
      idle.stop();
      var was = scroll.taken;
      scroll.reach = 0;
      scroll.across = 0;
      scroll.taken = false;
      if (was)
        swipe.release(false);
    }
  }
}
