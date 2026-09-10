import QtQuick
import Quickshell
import qs.Commons
import qs.Services

// The shape an island surface grows out of, and the handover protocol it
// follows when another surface takes the island from it.
//
// A surface here is not a panel. It takes the island's own place, starting at
// whatever the island is wearing when it is asked for - the pill, the island's
// open card, or the live shape of another island surface letting go - and
// growing from that into its own open geometry. Growing out of the pill alone
// would first show the card collapsing, or the previous surface vanishing,
// while this surface rose out of what it left, which is two shapes moving
// where the shell has one. Reading the measurements at the instant of the
// claim and starting there turns the two into one morph.
//
// One of these is attached to every island surface: the launcher, the control
// centre, the calendar, the wallpaper picker, the recorder picker and the
// power menu. The handover is keyed on the owning window's output, so a
// surface opening on one monitor never picks up a shape published on another.
QtObject {
  id: origin

  // The owning PanelWindow. The handover and the card are both matched
  // against this window's screen.
  property var window

  // The shape the surface grows out of, when that is not the pill. Zero is
  // the pill.
  //
  // The island's status chip is one reason this exists. The chip lives on the
  // card, so it can only be pressed with the card already open, and a panel
  // that started from the pill would have the card drop shut and the panel
  // grow out of what was left - the one shape in the shell going backwards
  // before it goes forwards. The card is the same 520 px column at the same
  // radius the panels settle at, so growing out of it is a change of height
  // and nothing else.
  property real fromWidth: 0
  property real fromHeight: 0
  property real fromRadius: 0

  readonly property bool fromCard: fromHeight > 0

  // Raised for the one assignment that puts the surface on the card's shape,
  // so it arrives there rather than travelling there.
  property bool snapping: false

  // The pill the surface has to start from and return to, which is wider
  // while something is playing.
  readonly property real collapsedWidth: Theme.islandCollapsedWidth(Media.active, Recorder.recording)

  readonly property real originWidth: fromCard ? fromWidth : collapsedWidth
  readonly property real originHeight: fromCard ? fromHeight : Theme.barHeight
  readonly property real originRadius: fromCard ? fromRadius : Theme.islandRadius

  // How far open the card was when it handed over, on the island's own scale
  // where 0 is the pill and 1 the card. The clock the surface carries over is
  // drawn where the island had it at exactly that point, so the two are the
  // same clock across the hand-over even when the chip is pressed with the
  // card still growing.
  readonly property real fromOpenness: {
    var span = Theme.islandExpandedHeight - Theme.barHeight;
    if (!origin.fromCard || span <= 0)
      return 0;
    return Math.max(0, Math.min(1, (origin.fromHeight - Theme.barHeight) / span));
  }

  // True when the shape came from another surface rather than from the
  // island. A surface taking over from another must not fade a clock in over
  // the top of it - the surface it replaced had none showing - so whatever
  // rides on this cuts instead of crossfading.
  property bool handedOver: false

  // The still a dismissing surface leaves on screen. The surface taking over
  // is a separate layer surface, and its first rendered frame lands 150-216 ms
  // after the open even though the window maps in five - measured for the
  // pill-blink fix. Cutting away at the instant of the claim would show the
  // bare pill for that whole gap: a panel turning into a pill and back.
  //
  // So the holder does not cut. It rides the taker's own morph: same start
  // shape, same open target, same duration, same curve, begun on the same
  // frame the taker's own shape Behaviour begins - the claim and the open are
  // one call stack. The two surfaces run in lockstep, so from the taker's
  // first presented frame its box covers the still exactly, and the still's
  // own takedown cannot be seen. What the eye sees is one shape travelling on
  // the taker's curve; the holder is simply the part of the motion that
  // arrived before the taker's window did.
  property bool held: false
  property real heldWidth: 0
  property real heldHeight: 0
  property real heldRadius: 0
  property int heldDuration: 0

  function hold(width, height, radius) {
    heldWidth = Bus.takeWidth > 0 ? Bus.takeWidth : width;
    heldHeight = Bus.takeHeight > 0 ? Bus.takeHeight : height;
    heldRadius = Bus.takeRadius > 0 ? Bus.takeRadius : radius;
    heldDuration = Bus.takeDuration > 0 ? Bus.takeDuration : Theme.morphHold;
    held = true;
    holdTimer.interval = heldDuration + 260;
    holdTimer.restart();
  }

  property Timer holdTimer: Timer {
    onTriggered: origin.held = false
  }

  readonly property string screenName: origin.window && origin.window.screen ? origin.window.screen.name : ""

  // Take the shape of the card already standing open on this output, if
  // there is one. Its measurements are read first and read into locals,
  // because claiming the island is what shuts the card.
  function adopt() {
    var card = Bus.islandCard;
    if (!card || !card.win || !card.win.screen || !origin.window || !origin.window.screen)
      return;
    if (card.win.screen.name !== origin.window.screen.name)
      return;

    var w = card.width;
    var h = card.height;
    var r = card.surfaceRadius;

    snapping = true;
    fromWidth = w;
    fromHeight = h;
    fromRadius = r;
    snapping = false;
  }

  // Take the shape the other island surface was wearing when it let go, if
  // it let go in this same handover and on this output. It outranks the
  // pill, which is what this surface would otherwise grow out of while the
  // other's full panel is vanishing in the same frame. Consumed on read,
  // and dropped unused, so it can never be mistaken for the shape of some
  // later open.
  function adoptHandoff() {
    var pendingScreen = Bus.handoffScreen;
    Bus.handoffScreen = "";
    var pendingWidth = Bus.handoffWidth;
    Bus.handoffWidth = 0;
    var pendingHeight = Bus.handoffHeight;
    Bus.handoffHeight = 0;
    var pendingRadius = Bus.handoffRadius;
    Bus.handoffRadius = 0;

    if (pendingScreen === "" || !origin.window || !origin.window.screen || pendingScreen !== origin.window.screen.name)
      return;

    snapping = true;
    fromWidth = pendingWidth;
    fromHeight = pendingHeight;
    fromRadius = pendingRadius;
    snapping = false;
    handedOver = true;
  }

  // Back to growing out of the pill, which is what the island is again by
  // the time this surface has finished closing over it. Also drops the
  // frozen still: a surface asked to close while it is holding one for a
  // taker that never arrived owes nobody that wait any more.
  function release() {
    held = false;
    fromWidth = 0;
    fromHeight = 0;
    fromRadius = 0;
  }

  // Take the island. This is the ordering every surface uses, in one place:
  // adopt() must run before the claim, because claiming the island is what
  // shuts the card; adoptHandoff() must run after, because the surface
  // letting go publishes its shape inside the claim. Claiming it is what
  // makes the holder let go, and it lets go into this surface's own morph -
  // the holder's still rides the shape, duration and curve this surface is
  // about to travel, so the handover reads as one morph rather than a panel
  // vanishing while this one grows out of the pill.
  function claim(width, height, radius, duration) {
    handedOver = false;
    held = false;
    adopt();
    Bus.takeWidth = width;
    Bus.takeHeight = height;
    Bus.takeRadius = radius;
    Bus.takeDuration = duration;
    Bus.islandClaimed(screenName);
    adoptHandoff();
    // The holder consumed these inside the claim; drop them so they can
    // never be mistaken for the shape of some later open.
    Bus.takeWidth = 0;
    Bus.takeHeight = 0;
    Bus.takeRadius = 0;
    Bus.takeDuration = 0;
  }

  // Give the island up to the surface that claimed it. There is no shrink
  // back to the pill: the surface taking over is already growing in this
  // one's place. What this one owes it is the shape it was wearing,
  // published before this surface lets go of it, so the switch lands as one
  // morph instead of a cut to the pill.
  function publish(width, height, radius) {
    Bus.handoffScreen = screenName;
    Bus.handoffWidth = width;
    Bus.handoffHeight = height;
    Bus.handoffRadius = radius;
    release();
  }
}
