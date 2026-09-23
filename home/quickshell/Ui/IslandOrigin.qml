import QtQuick
import Quickshell
import qs.Commons
import qs.Services

// The shape an island surface grows out of, and the handover protocol when another surface
// takes the island. Keyed on the owning window's output so monitors never cross.
QtObject {
  id: origin

  // The owning PanelWindow. The handover and the card are both matched against its screen.
  property var window

  // The shape the surface grows out of when not the pill (zero is the pill). The card is the
  // same 520 px column and radius, so it is a change of height only; corner is read off height.
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

  // The still a dismissing surface leaves on screen. The taker's first frame lands 150-216 ms
  // after the open though the window maps in five, so cutting at the claim would bare the pill.
  property bool held: false
  property real heldWidth: 0
  property real heldHeight: 0
  property real heldRadius: 0
  property int heldDuration: 0

  // The claim this surface's still was armed for. A still is owed to one taker; a second
  // claim makes it stale, and stale stills stack up beside the surface actually growing.
  property int heldSerial: 0

  function hold(width, height, radius) {
    var claim = Bus.claimFor(screenName);
    heldWidth = claim ? claim.width : width;
    heldHeight = claim ? claim.height : height;
    heldRadius = claim ? claim.radius : radius;
    heldDuration = claim ? claim.duration : Theme.morphHold;
    held = true;
    heldSerial = claim ? claim.serial : Bus.claimSerial;
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

  // Take the shape of the card open on this output. Measurements are read into locals first,
  // because claiming the island shuts the card; matched on the card's `screenName`, not a `win`.
  function adopt() {
    var card = Bus.islandCardFor(origin.screenName);
    if (!card || card.screenName === "" || card.screenName !== origin.screenName)
      return;

    var w = card.width;
    var h = card.height;

    snapping = true;
    fromWidth = w;
    fromHeight = h;
    snapping = false;
  }

  // Take the shape the other surface was wearing when it let go in this same handover and
  // output. Outranks the pill. Consumed on read, so it cannot leak into a later open.
  function adoptHandoff() {
    var handoff = Bus.consumeHandoff(origin.screenName);
    if (!handoff)
      return;

    snapping = true;
    fromWidth = handoff.width;
    fromHeight = handoff.height;
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

  // Take the island. adopt() before the claim (claiming shuts the card), adoptHandoff() after
  // (the letting-go surface publishes inside the claim), so the handover reads as one morph.
  function claim(width, height, radius, duration) {
    handedOver = false;
    held = false;
    adopt();
    Bus.claimIsland(screenName, width, height, radius, duration);
    var serial = Bus.claimSerial;
    adoptHandoff();
    // The holder consumed the transaction synchronously; drop it so a later open cannot reuse it.
    Bus.clearClaim(screenName, serial);
  }

  // Give the island up to the surface that claimed it. There is no shrink back to the pill:
  // what this one owes the taker is the shape it was wearing, published before it lets go.
  function publish(width, height, radius) {
    Bus.publishHandoff(screenName, width, height, radius);
    release();
  }
}
