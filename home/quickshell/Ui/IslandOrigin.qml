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

  // Whether the shape grown out of had its clock up. The drop well hides the island's clock,
  // so a surface growing out of it must not bring one back for its first frames.
  property bool fromClock: true

  // Raised for the one assignment that puts the surface on the card's shape, so it arrives
  // there rather than travelling there.
  property bool snapping: false

  // The pill the surface starts from and returns to, which is wider while something plays.
  readonly property real collapsedWidth: Theme.islandCollapsedWidth(Media.active, Recorder.recording, Privacy.camera, Privacy.microphone)

  // Where the pill rests; the surface is placed by this so it starts from and returns to it.
  readonly property real offsetX: Bus.pillOffsetX
  readonly property real offsetY: Bus.pillOffsetY

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
  // Belongs to one open: a close goes back to the pill whatever the open grew out of.
  property bool handedOver: false

  // ---- presentation ----
  //
  // Nothing that hides what was on screen before may run on an assumed latency: the island
  // stays up, and a still keeps its ground, until the taker's own frame is on screen. A frame
  // is counted once the window has animated after becoming presentable, then swapped.

  // An item inside the owning window. Its window's frames are what `presented` waits on; a
  // surface that sets none is never reported, and whoever waits on it falls back to a timer.
  property Item frameItem: null

  // Set by the owner: the window is mapped at a size that shows the surface. Down while a
  // parked window is still the sliver it idles at.
  property bool presentable: false

  // A frame showing this surface has reached the screen since it last became presentable.
  property bool presented: false

  // The serial of the claim this surface last made, reported with its first frame so a
  // still knows the frame is from its own taker.
  property int ownSerial: 0

  readonly property var frameWindow: origin.frameItem && origin.frameItem.Window ? origin.frameItem.Window.window : null

  property bool presentArmed: false
  property bool presentSynced: false

  onPresentableChanged: {
    if (presentable)
      origin.armPresent();
    else {
      presentArmed = false;
      presentSynced = false;
      presentFallback.stop();
      presented = false;
    }
  }

  function armPresent() {
    if (presented || !frameItem)
      return;
    presentArmed = true;
    presentSynced = false;
    presentFallback.restart();
    // Nothing guarantees the window has anything new to draw; ask for a frame regardless.
    if (frameWindow)
      frameWindow.update();
  }

  function markPresented() {
    presentArmed = false;
    presentSynced = false;
    presentFallback.stop();
    if (presented)
      return;
    presented = true;
    Bus.reportPresented(screenName, ownSerial);
  }

  property Connections frames: Connections {
    target: origin.frameWindow
    ignoreUnknownSignals: true

    // Emitted on the GUI thread before the frame's sync, so this frame carries the state
    // that made the surface presentable; the swap after it is the first one that does.
    function onAfterAnimating() {
      if (origin.presentArmed)
        origin.presentSynced = true;
    }

    function onFrameSwapped() {
      if (origin.presentArmed && origin.presentSynced)
        origin.markPresented();
    }
  }

  // A compositor that never answers must not keep the island hidden behind nothing.
  property Timer presentFallback: Timer {
    interval: Theme.morphPresentFallback
    onTriggered: if (origin.presentArmed)
      origin.markPresented()
  }

  // ---- the still ----

  // The still a dismissing surface leaves on screen. It stands in for the island until the
  // taker reports its first frame, then lingers while its ground fades over it.
  property bool held: false
  property real heldWidth: 0
  property real heldHeight: 0
  property real heldRadius: 0
  property int heldDuration: 0

  // The claim this surface's still was armed for. A still is owed to one taker; a second
  // claim makes it stale, and stale stills stack up beside the surface actually growing.
  property int heldSerial: 0

  // The taker this still waits on has put a frame on screen (or the wait ran out). The
  // still's ground fades from here.
  property bool takerPresented: false

  // The taker's shape, which the still rides to once the taker is on screen.
  property real heldTargetWidth: 0
  property real heldTargetHeight: 0

  // Seats the still at rest on the shape it was wearing, where it waits for the taker's first
  // frame and then rides the taker's own spring to the taker's shape. The taker waits on that
  // same frame and grows out of that same shape, so the two run one curve from one start; a
  // surface caught mid-morph would otherwise carry its old velocity and part from the taker.
  // Owners bind held ahead of open, so the seat lands while open is still up.
  function hold(width, height, radius) {
    var claim = Bus.claimFor(screenName);
    snapping = true;
    heldWidth = width;
    heldHeight = height;
    heldRadius = claim ? claim.radius : radius;
    held = true;
    snapping = false;
    heldTargetWidth = claim ? claim.width : width;
    heldTargetHeight = claim ? claim.height : height;
    // The claim carries the taker's own morph duration; with no taker the still is a
    // deliberate beat, so it stays short under reduce motion like the morphs do.
    heldDuration = claim ? claim.duration : Theme.duration(Theme.morphHold);
    heldSerial = claim ? claim.serial : Bus.claimSerial;
    takerPresented = false;
    if (claim) {
      // Waits for the taker's frame; the fallback covers a taker that reports none.
      takerWait.interval = Theme.morphPresentFallback;
      takerWait.restart();
      holdTimer.interval = Theme.morphPresentFallback + heldDuration + Theme.morphHoldBuffer;
    } else {
      takerPresented = true;
      holdTimer.interval = heldDuration;
    }
    holdTimer.restart();
  }

  function takerArrived() {
    if (!held || takerPresented)
      return;
    takerWait.stop();
    heldWidth = heldTargetWidth;
    heldHeight = heldTargetHeight;
    takerPresented = true;
    holdTimer.interval = Theme.duration(Theme.morphHoldLinger);
    holdTimer.restart();
  }

  property Timer takerWait: Timer {
    onTriggered: origin.takerArrived()
  }

  // The hard stop on a still; once the taker is up, re-armed to the short linger.
  property Timer holdTimer: Timer {
    onTriggered: {
      origin.takerWait.stop();
      origin.held = false;
    }
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

    function onIslandPresented(screen, serial) {
      if (origin.held && screen === origin.screenName && serial === origin.heldSerial)
        origin.takerArrived();
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
    fromClock = card.clockShown !== false;
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
    takerWait.stop();
    holdTimer.stop();
    handedOver = false;
    fromWidth = 0;
    fromHeight = 0;
    fromClock = true;
    Bus.clearIslandHolder(screenName, origin);
    Bus.islandDropped(screenName);
  }

  // Take the island. adopt() before the claim (claiming shuts the card), adoptHandoff() after
  // (the letting-go surface publishes inside the claim), so the handover reads as one morph.
  function claim(width, height, radius, duration) {
    handedOver = false;
    held = false;
    fromClock = true;
    adopt();
    Bus.claimIsland(screenName, width, height, radius, duration);
    // After the claim, in which whoever held the island let it go.
    Bus.setIslandHolder(screenName, origin);
    var serial = Bus.claimSerial;
    ownSerial = serial;
    adoptHandoff();
    // The holder consumed the transaction synchronously; drop it so a later open cannot reuse it.
    Bus.clearClaim(screenName, serial);
    // Already on screen (claimed again mid-close): this frame is as good as the next.
    if (presented)
      Bus.reportPresented(screenName, serial);
    else if (presentable)
      armPresent();
  }

  // Give the island up to the surface that claimed it. There is no shrink back to the pill:
  // what this one owes the taker is the shape it was wearing, published before it lets go.
  function publish(width, height, radius) {
    Bus.publishHandoff(screenName, width, height, radius);
    release();
  }
}
