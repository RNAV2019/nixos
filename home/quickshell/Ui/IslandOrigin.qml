import QtQuick
import Quickshell
import qs.Commons
import qs.Services

// The shape an island surface grows out of, and the handover protocol it follows when
// another surface takes the island from it.
//
// A surface here is not a panel. It takes the island's own place, starting at whatever the
// island is wearing when it is asked for - the pill, the island's open card, or the live
// shape of another island surface letting go - and growing from that into its own geometry.
// Reading the measurements at the instant of the claim is what turns two shapes into one morph.
//
// One of these is attached to every island surface. The handover is keyed on the owning
// window's output, so a surface opening on one monitor never picks up a shape from another.
QtObject {
  id: origin

  // The owning PanelWindow. The handover and the card are both matched against its screen.
  property var window

  // The shape the surface grows out of, when that is not the pill. Zero is the pill. The
  // card is the same 520 px column at the same radius the panels settle at, so growing out
  // of it is a change of height and nothing else. Only a width and a height: no surface
  // animates its corner, which is read off its own live height; see Bar/Island.qml.
  property real fromWidth: 0
  property real fromHeight: 0

  readonly property bool fromCard: fromHeight > 0

  // Raised for the one assignment that puts the surface on the card's shape, so it arrives
  // there rather than travelling there.
  property bool snapping: false

  // The pill the surface starts from and returns to, which is wider while something plays.
  readonly property real collapsedWidth: Theme.islandCollapsedWidth(Media.active, Recorder.recording)

  readonly property real originWidth: fromCard ? fromWidth : collapsedWidth
  readonly property real originHeight: fromCard ? fromHeight : Theme.barHeight

  // How far open the card was when it handed over, 0 the pill and 1 the card. The clock
  // the surface carries over is drawn where the island had it at exactly that point.
  readonly property real fromOpenness: {
    var span = Theme.islandExpandedHeight - Theme.barHeight;
    if (!origin.fromCard || span <= 0)
      return 0;
    return Math.max(0, Math.min(1, (origin.fromHeight - Theme.barHeight) / span));
  }

  // True when the shape came from another surface rather than from the island. The surface
  // it replaced had no clock showing, so whatever rides on this cuts instead of crossfading.
  property bool handedOver: false

  // The still a dismissing surface leaves on screen. The taker is a separate layer surface,
  // and its first rendered frame lands 150-216 ms after the open even though the window maps
  // in five, so cutting away at the claim would show the bare pill for that whole gap.
  //
  // So the holder rides the taker's own morph: same start shape, target, duration and curve,
  // begun on the same frame, since the claim and the open are one call stack. From the
  // taker's first presented frame its box covers the still exactly.
  property bool held: false
  property real heldWidth: 0
  property real heldHeight: 0
  property real heldRadius: 0
  property int heldDuration: 0

  // The claim this surface's still was armed for. A still is owed to exactly one taker; a
  // second claim makes it stale, and stales left up through a run of fast switches stack up
  // beside the surface that is actually growing.
  property int heldSerial: 0

  function hold(width, height, radius) {
    heldWidth = Bus.takeWidth > 0 ? Bus.takeWidth : width;
    heldHeight = Bus.takeHeight > 0 ? Bus.takeHeight : height;
    heldRadius = Bus.takeRadius > 0 ? Bus.takeRadius : radius;
    heldDuration = Bus.takeDuration > 0 ? Bus.takeDuration : Theme.morphHold;
    held = true;
    heldSerial = Bus.claimSerial;
    holdTimer.interval = heldDuration + 260;
    holdTimer.restart();
  }

  property Timer holdTimer: Timer {
    onTriggered: origin.held = false
  }

  // Drop a still that a later claim has made stale. Keyed on the serial rather than on
  // which handler runs first, so it holds whichever order the two arrive in.
  property Connections claims: Connections {
    target: Bus

    function onIslandClaimed(screen) {
      if (origin.held && origin.heldSerial !== Bus.claimSerial && screen === origin.screenName)
        origin.release();
    }

    // And drop one whose taker has gone. release() raises this, so the drop raises it again,
    // but only ever one deep: the second pass finds held already down.
    function onIslandDropped(screen) {
      if (origin.held && screen === origin.screenName)
        origin.release();
    }
  }

  readonly property string screenName: origin.window && origin.window.screen ? origin.window.screen.name : ""

  // Take the shape of the card already standing open on this output. Its measurements are
  // read into locals first, because claiming the island is what shuts the card. Matched on
  // the card's `screenName`: the card is a FrostedSurface, not a window, so reaching through
  // it for a `win` found undefined and every panel grew out of the pill instead.
  function adopt() {
    var card = Bus.islandCard;
    if (!card || card.screenName === "" || card.screenName !== origin.screenName)
      return;

    var w = card.width;
    var h = card.height;

    snapping = true;
    fromWidth = w;
    fromHeight = h;
    snapping = false;
  }

  // Take the shape the other island surface was wearing when it let go, if it let go in this
  // same handover and on this output. It outranks the pill. Consumed on read, and dropped
  // unused, so it can never be mistaken for the shape of some later open.
  function adoptHandoff() {
    var pendingScreen = Bus.handoffScreen;
    Bus.handoffScreen = "";
    var pendingWidth = Bus.handoffWidth;
    Bus.handoffWidth = 0;
    var pendingHeight = Bus.handoffHeight;
    Bus.handoffHeight = 0;

    if (pendingScreen === "" || !origin.window || !origin.window.screen || pendingScreen !== origin.window.screen.name)
      return;

    snapping = true;
    fromWidth = pendingWidth;
    fromHeight = pendingHeight;
    snapping = false;
    handedOver = true;
  }

  // Back to growing out of the pill. Also drops the frozen still: a surface asked to close
  // while holding one for a taker that never arrived owes nobody that wait any more.
  function release() {
    held = false;
    fromWidth = 0;
    fromHeight = 0;
    Bus.islandDropped(screenName);
  }

  // Take the island. adopt() must run before the claim, because claiming the island is what
  // shuts the card; adoptHandoff() must run after, because the surface letting go publishes
  // its shape inside the claim. The holder's still then rides the shape, duration and curve
  // this surface is about to travel, so the handover reads as one morph.
  function claim(width, height, radius, duration) {
    handedOver = false;
    held = false;
    adopt();
    Bus.claimSerial++;
    Bus.takeWidth = width;
    Bus.takeHeight = height;
    Bus.takeRadius = radius;
    Bus.takeDuration = duration;
    Bus.islandClaimed(screenName);
    adoptHandoff();
    // The holder consumed these inside the claim; drop them so a later open cannot.
    Bus.takeWidth = 0;
    Bus.takeHeight = 0;
    Bus.takeRadius = 0;
    Bus.takeDuration = 0;
  }

  // Give the island up to the surface that claimed it. There is no shrink back to the pill:
  // what this one owes the taker is the shape it was wearing, published before it lets go.
  function publish(width, height) {
    Bus.handoffScreen = screenName;
    Bus.handoffWidth = width;
    Bus.handoffHeight = height;
    release();
  }
}
