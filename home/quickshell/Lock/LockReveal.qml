import QtQuick
import qs.Commons
import qs.Ui

// The lock's one clock, held apart from the surfaces that read it, so every output plays the
// same frame of it.
//
// In: the ground (blur and scrim) comes up over Theme.lockIn; Theme.lockFlightDelay in, the
// flight starts: the clock leaves the pill for the middle of the screen on a spring that runs a
// little past and settles, the pill drops with it and narrows to its lock glyph. Out is the same
// played back: the clock flies home, the pill rises a little behind it and widens a beat later,
// and once the clock is in the pill the ground clears and revealOutFinished is raised.
Item {
  id: reveal

  // 0 with the desktop as it was, 1 with it blurred under the scrim.
  property real ground: 0
  // 0 with the clock in the pill, 1 with it at rest mid-screen; runs a little past 1 going in and
  // a little under 0 coming home.
  readonly property real flight: flightSpring.value
  // The clock's size on the same journey, on a looser spring of its own: it swells a little
  // past its resting size and settles back, as a bubble does when it is let go.
  readonly property real swell: swellSpring.value
  // A quicker, looser spring still, on the same journey. How far it leads or trails the flight
  // is the clock's wobble: stretched along its travel while it moves, squashed as it lands.
  readonly property real wobble: wobbleSpring.value - flightSpring.value
  // 0 with the pill where the island rests, 1 with it dropped to its locked place.
  readonly property real rise: riseSpring.value
  // Where the flight and the pill's width are headed. The width follows a beat behind on the
  // way home, so it has a flag of its own.
  property bool away: false
  property bool widthAway: false
  // Up from animateOut() until the next reset: nothing new is shown in a pill on its way home.
  property bool leaving: false
  // Up across a reset: every spring that reads this takes its target at once.
  property bool snapping: false
  // Up once the way out has begun clearing the ground: the flight is still settling then, and
  // must not start the clearing (and raise revealOutFinished) a second time.
  property bool clearing: false

  // Up from arm() until a surface has a frame on screen: the way in starts from the frame the
  // user sees, not from the moment the surface was asked for (a lock surface takes a while to
  // map, and the ground would be half up before anything showed).
  property bool armed: false

  readonly property bool flying: flightSpring.running
  readonly property bool animatingIn: armed || groundIn.running || flightDelay.running || (away && flying)

  // Raised once the clock is home and the ground has cleared; the opaque base holds until then.
  signal revealOutFinished

  function arm() {
    armed = true;
    armFallback.restart();
  }

  // A surface's first frame is on screen (Lock/LockView.qml), or none ever said so.
  function presented() {
    if (!armed)
      return;
    armed = false;
    armFallback.stop();
    animateIn();
  }

  function animateIn() {
    armed = false;
    armFallback.stop();
    groundOut.stop();
    clearing = false;
    leaving = false;
    groundIn.restart();
    flightDelay.restart();
  }

  function animateOut() {
    armed = false;
    armFallback.stop();
    groundIn.stop();
    flightDelay.stop();
    leaving = true;
    away = false;
    widthDelay.interval = Theme.duration(Theme.lockWidthOutDelay);
    widthDelay.restart();
    // Asked for before the flight ever left, or with motion off: there is nothing to wait for.
    landed();
  }

  function reset() {
    armed = false;
    armFallback.stop();
    groundIn.stop();
    groundOut.stop();
    flightDelay.stop();
    widthDelay.stop();
    snapping = true;
    away = false;
    widthAway = false;
    leaving = false;
    clearing = false;
    snapping = false;
    // Stay opaque while the lock is secured, so the compositor never shows a black frame.
    ground = 0;
  }

  // The clock is home once the big one has given way to the island's own.
  function landed() {
    if (!leaving || clearing || flight > Theme.lockClockSwapFrom)
      return;
    clearing = true;
    groundOut.restart();
  }

  onFlightChanged: landed()

  MorphSpring {
    id: flightSpring

    label: "lock.flight"
    target: reveal.away ? 1 : 0
    animate: !reveal.snapping
    omega: reveal.away ? Theme.lockFlightOmega : Theme.lockFlightOmegaOut
    damping: reveal.away ? Theme.lockFlightDamping : Theme.lockFlightDampingOut
    epsilon: 0.0005
  }

  MorphSpring {
    id: swellSpring

    label: "lock.swell"
    target: reveal.away ? 1 : 0
    animate: !reveal.snapping
    omega: reveal.away ? Theme.lockSwellOmega : Theme.lockFlightOmegaOut
    damping: reveal.away ? Theme.lockSwellDamping : Theme.lockFlightDampingOut
    epsilon: 0.0005
  }

  MorphSpring {
    id: wobbleSpring

    label: "lock.wobble"
    target: reveal.away ? 1 : 0
    animate: !reveal.snapping
    omega: reveal.away ? Theme.lockWobbleOmega : Theme.lockWobbleOmegaOut
    damping: reveal.away ? Theme.lockWobbleDamping : Theme.lockWobbleDampingOut
    epsilon: 0.0005
  }

  MorphSpring {
    id: riseSpring

    label: "lock.rise"
    target: reveal.away ? 1 : 0
    animate: !reveal.snapping
    omega: reveal.away ? Theme.lockFlightOmega : Theme.lockRiseOmegaOut
    damping: reveal.away ? Theme.lockFlightDamping : Theme.morphDamping
    epsilon: 0.0005
  }

  Timer {
    id: armFallback

    interval: Theme.lockPresentWait
    onTriggered: reveal.presented()
  }

  Timer {
    id: flightDelay

    interval: Theme.duration(Theme.lockFlightDelay)
    onTriggered: {
      reveal.away = true;
      widthDelay.interval = Theme.duration(Theme.lockWidthInDelay);
      widthDelay.restart();
    }
  }

  // The pill's width follows the flight a beat behind, both ways.
  Timer {
    id: widthDelay

    onTriggered: reveal.widthAway = reveal.away
  }

  NumberAnimation {
    id: groundIn

    target: reveal
    property: "ground"
    to: 1
    duration: Theme.duration(Theme.lockIn)
    easing.type: Easing.OutQuad
  }

  SequentialAnimation {
    id: groundOut

    NumberAnimation {
      target: reveal
      property: "ground"
      to: 0
      duration: Theme.duration(Theme.lockOut)
      easing.type: Easing.OutQuad
    }

    ScriptAction {
      script: reveal.revealOutFinished()
    }
  }
}
