import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import "Motion.js" as Motion

// What every island surface shares: the window, the shape, and the handover. How a surface
// comes to be open is the policy of the file that derives from this: Ui/IslandSurface.qml is
// opened by the user and takes the keyboard, Ui/TransientSurface.qml opens by itself and takes
// its turn. Must be the caller's Variants delegate.
PanelWindow {
  id: win

  required property var modelData

  // Identity on the bus, and the layer-shell namespace.
  property string key: ""
  property string layerNamespace: "quickshell-" + win.key

  // The shape this surface settles at. Any of the three may be a live binding.
  property real openWidth: 0
  property real openHeight: 0
  property real openRadius: Theme.controlRadius

  // Grows about the resting pill's midline up to the pill row's height rather than only down,
  // so a 42 px pill keeps the bar's margins above and below; a taller card carries on from there.
  property bool centred: false

  property bool open: false
  property alias origin: origin
  property alias surface: surface

  // The fixed box the contents are laid out in (see FrostedSurface.contentWidth).
  readonly property Item contentBox: surface.contentBox

  // Everything the surface draws, laid out at its final metrics from the first frame and
  // uncovered by the growing shape, which makes the open read as a reveal rather than a fade.
  default property alias content: bodyHolder.data

  // What a policy draws over the card and outside its clip, in the window's coordinates (the
  // phone satellite beside a transient).
  property alias overlayData: overlay.data

  // What a policy adds inside the card, beside the contents: items that draw nothing of their own.
  property alias surfaceData: surface.content

  // Where a key the contents leave unaccepted goes next. A policy that takes keys names its own
  // key item here, so the one it handles is the same whether a content item or it has focus.
  property list<Item> contentKeyTargets

  // Raised inside show(), before the island is claimed, so a caller can reset the state its
  // own open shape is computed from.
  signal opening

  // Raised when another surface took the island from this one.
  signal dismissed

  // The shape this surface grows out of, and the handover protocol it follows when another
  // surface takes the island.
  IslandOrigin {
    id: origin

    window: win
    frameItem: surface
    presentable: !Bus.locking && win.tall
  }

  // Raised while the island is being handed to another surface. The still held for it rides
  // the taker's own morph, and keeps the final cut to the pill instant.
  property bool handover: false

  // Raised for the length of a handover, and what the still's two fades are driven from.
  // Separate from `handover`, which also disables the shape Behaviors.
  property bool farewell: false

  // True while contents arrive out of another surface rather than the island. Panel to panel
  // there is no clip to reveal them, so they enter on their own delayed schedule.
  readonly property bool entering: win.open && origin.handedOver

  // The few pixels arriving contents settle through, signed by the height's direction so they
  // move with the box. Set once per open, since openHeight is usually a live binding.
  property real enterTravel: 0

  readonly property bool focused: Monitors.isFocused(win.screen)
  readonly property string screenName: win.screen ? win.screen.name : ""

  // True from the moment the shape starts growing until it is at rest on the pill, or until a
  // frozen still is taken down. At rest, not merely back: the spring dips under the pill and
  // returns, and the bar's own pill must not appear in the middle of that.
  readonly property bool morphRunning: widthSpring.running || heightSpring.running
  // Read off the spring, never the snapped size: snapping depends on the window it would flip.
  readonly property bool showing: open || origin.held || morphRunning || Math.abs(widthSpring.value - origin.collapsedWidth) > 0.5 || Math.abs(heightSpring.value - Theme.barHeight) > 0.5

  // The whole time the bar must keep its island hidden: from this surface's first frame on
  // screen, never before it, so the pill is never taken away with nothing drawn in its place.
  readonly property bool covering: showing && (origin.presented || !open)

  // Shared gate for the shape springs: no motion when asked, no travel when the surface was
  // snapped onto a shape, and no travelling while a still is being cut away from.
  // Parked, a change of pill (media starting, a recording) is taken at once: a parked surface
  // must not wake to travel between two pills nobody can see.
  readonly property bool geometryAnimEnabled: !Theme.reduceMotion && !origin.snapping && !win.parked && (!win.handover || origin.held)

  // Raised inside show() around the claim, so this surface's own claim is not taken for
  // another surface's.
  property bool claiming: false

  // Whether the still left by a dismiss carries the contents it was showing. A surface already
  // on its way down had faded them, and must not bring them back to fade them again.
  property bool stillCarriesBody: false

  // Whether another surface taking the island on a different output closes this one. A panel
  // is the only one open; a transient has its own turn on every output.
  property bool closesElsewhere: false

  function show() {
    widthSpring.settle();
    heightSpring.settle();
    win.opening();
    handover = false;
    farewell = false;
    stillCarriesBody = false;
    // Take the island. The ordering, the card and the handover mailbox live in
    // Ui/IslandOrigin.qml; the arguments are the morph the holder rides with this surface.
    claiming = true;
    origin.claim(win.openWidth, win.openHeight, win.openRadius, Theme.morphSurface);
    claiming = false;
    // Read after the claim, which is what fills in the shape this surface grows out of.
    enterTravel = origin.handedOver ? (win.openHeight >= origin.fromHeight ? -Theme.morphEnterTravel : Theme.morphEnterTravel) : 0;
    open = true;
    // Carry on the motion of the surface that let go (zero out of the pill): per axis, towards
    // the open shape only, and no faster than a spring that does not overshoot could be. Armed
    // until this surface's first frame is up, when the target moves and the spring runs; dropped
    // if it is closed or dismissed before then.
    if (origin.handedOver) {
      widthSpring.kick(Motion.seedVelocity(widthSpring.value, win.openWidth, origin.fromVW, Theme.morphOmega));
      heightSpring.kick(Motion.seedVelocity(heightSpring.value, win.openHeight, origin.fromVH, Theme.morphOmega));
    }
  }

  function hide() {
    widthSpring.settle();
    heightSpring.settle();
    origin.release();
    // The travel belongs to the arrival: a close is a close whichever shape it grew out of.
    enterTravel = 0;
    open = false;
  }

  // Giving the island up to the surface that claimed it, open or still on its way down. The
  // still is what the eye sees until the taker's first frame lands. Still wanted, this one
  // comes back once the island is free again; see evaluate().
  function dismiss() {
    var w = surface.implicitWidth;
    var h = surface.implicitHeight;
    var vw = widthSpring.running ? widthSpring.velocity : 0;
    var vh = heightSpring.running ? heightSpring.velocity : 0;
    widthSpring.settle();
    heightSpring.settle();
    origin.publish(surface.width, surface.height, surface.surfaceRadius, vw, vh);
    stillCarriesBody = win.open;
    handover = true;
    farewell = true;
    origin.hold(w, h, surface.surfaceRadius, vw, vh);
    open = false;
    win.dismissed();
    // Whoever claimed registers itself in the same turn; if nothing did, the island is free.
    evaluateSoon();
  }

  // ---- turns ----
  //
  // A surface its owner asks for, rather than the user toggling: the owner binds `wanted`, and
  // the window grows out of the island, hands it over and comes back by itself.

  // Bound by the owner: this surface wants the island on this output.
  property bool wanted: false

  // Wanted, but another surface has the turn here. It waits rather than being knocked out.
  property bool waiting: false

  readonly property bool wantsOpen: win.wanted && !win.waiting

  // Decided a turn later, never inside the change that prompted it: a want often moves in the
  // middle of another surface's claim (a panel cutting the OSD short frees the island for a
  // toast before that panel has registered as its owner), and a claim made from in there would
  // race the claim it is nested in.
  onWantsOpenChanged: evaluateSoon()

  // Closed by anything but the owner letting go, a wanted surface is up again once the island
  // is free; closed for the want ending, there is nothing to decide.
  onOpenChanged: {
    if (!open && wanted)
      evaluateSoon();
  }

  function evaluateSoon() {
    evaluateLater.restart();
  }

  Timer {
    id: evaluateLater

    interval: 0
    onTriggered: win.evaluate()
  }

  function evaluate() {
    if (Bus.locking)
      return;
    if (win.wantsOpen && !win.open) {
      win.show();
    } else if (!win.wantsOpen && win.open) {
      // Outranked, the surface that outranks this one claims the island in its own turn, and
      // the claim hands over from here. Shrinking first would put the pill between the two.
      if (win.wanted && win.waiting)
        yieldLater.restart();
      else
        win.hide();
    }
  }

  Timer {
    id: yieldLater

    interval: 0
    onTriggered: if (win.open && !win.wantsOpen)
      win.hide()
  }

  // The shape. The still first: hold() seats it on the shape it was wearing before the surface
  // lets go of its open one, which is what starts it from rest; see Ui/IslandOrigin.qml. An
  // open waits for its first frame on screen, so that frame is the shape it grows out of, and
  // the still riding along starts on the same frame, waiting on the same report.
  MorphSpring {
    id: widthSpring

    label: "surface." + win.key + ".w"
    animate: win.geometryAnimEnabled
    target: origin.held ? origin.heldWidth : win.open && origin.presented ? win.openWidth : origin.originWidth
  }

  MorphSpring {
    id: heightSpring

    label: "surface." + win.key + ".h"
    animate: win.geometryAnimEnabled
    target: origin.held ? origin.heldHeight : win.open && origin.presented ? win.openHeight : origin.originHeight
  }

  // The taker is on screen and the still starts for it: from the shape it waited on, at the speed it
  // was seated with, towards the taker's shape, which is where the taker's own spring is going
  // from the same shape at the same speed.
  Connections {
    target: origin

    function onTakerPresentedChanged() {
      if (!origin.held || !origin.takerPresented)
        return;
      widthSpring.kick(Motion.seedVelocity(widthSpring.value, origin.heldTargetWidth, origin.heldVW, Theme.morphOmega));
      heightSpring.kick(Motion.seedVelocity(heightSpring.value, origin.heldTargetHeight, origin.heldVH, Theme.morphOmega));
    }
  }

  MorphSpring {
    id: radiusSpring

    label: "surface." + win.key + ".r"
    // Not gated by the snapping that seats a still: it is the radius that must travel then.
    animate: !Theme.reduceMotion && !win.parked
    target: origin.held ? origin.heldRadius : win.openRadius
  }

  // With QS_MOTION_LOG=1: where the contents sit on screen while the shape moves, which
  // tools/qs-verify/motion/check.mjs --expect-static wants to find unchanging.
  FrameAnimation {
    running: Theme.motionLog && win.morphRunning && win.tall
    onTriggered: console.info("motion surface." + win.key + ".contentX " + Date.now() + " " + win.contentBox.mapToItem(null, 0, 0).x.toFixed(4) + " 0.0000 " + win.contentBox.mapToItem(null, 0, 0).x.toFixed(4))
  }

  // ---- one clock for shape and contents ----
  //
  // The contents' opacity and the collapsed pill's are functions of how far the shape has
  // travelled, not of timers of their own, so a retarget cannot pull them apart from the shape.

  // Where the shape travels from, re-based to the current shape on every retarget.
  property real fromW: 0
  property real fromH: 0

  // Along the axis that travels further; NaN while neither does.
  readonly property real shapeProgress: Motion.progress(win.fromW, win.fromH, widthSpring.target, heightSpring.target, widthSpring.value, heightSpring.value)

  // A shape that does not travel (the same size, other contents) has a short spring of its own,
  // restarted on every change of intent.
  ProgressSpring {
    id: progressFallback

    label: "surface." + win.key + ".p"
    target: 1
    animate: !win.parked
  }

  // The close also runs on a timed clock of its own, started on the flip and as long as the
  // content cross-fades: a card closed while it is still opening coasts outward first (its
  // progress stays 0 for that while), and a fast shape would otherwise cut the contents in a frame.
  property real closeT: 1

  onCloseTChanged: if (!bodyPending && !bodyWanted)
    updateBody()

  NumberAnimation {
    id: closeClock

    target: win
    property: "closeT"
    from: 0
    to: 1
    duration: Theme.duration(Theme.morphContent)
    easing.type: Easing.OutCubic
  }

  readonly property real morphProgress: isNaN(win.shapeProgress) ? (Theme.reduceMotion ? 1 : progressFallback.value) : win.shapeProgress

  // What the contents are on their way to: up, or gone.
  readonly property bool bodyWanted: (win.open && origin.presented) || (origin.held && win.stillCarriesBody)

  // Carried across retargets: moves only toward the end its intent points at.
  property real bodyOpacity: 0

  // The collapsed pill's share while the surface closes (CollapsedPill.amount).
  property real pillAmount: 1

  // A change of intent or of target arrives in several property writes that settle within one
  // turn; it is read once they have (a read in between sees the old shape against the new intent).
  property bool bodyPending: false

  function updateBody() {
    if (origin.held || Theme.reduceMotion || win.parked) {
      bodyOpacity = win.bodyWanted ? 1 : 0;
      pillAmount = win.open ? 0 : 1;
      return;
    }
    var p = win.morphProgress;
    if (win.bodyWanted) {
      var r = win.entering ? Theme.fadeEnterIn : Theme.fadeOpenIn;
      bodyOpacity = Math.max(bodyOpacity, Motion.ramp(p, r[0], r[1]));
      pillAmount = 0;
    } else {
      bodyOpacity = Math.min(bodyOpacity, 1 - Math.max(Motion.ramp(p, Theme.fadeCloseOut[0], Theme.fadeCloseOut[1]), win.closeT));
      if (!win.open)
        pillAmount = Math.max(pillAmount, Motion.ramp(p, Theme.fadePillIn[0], Theme.fadePillIn[1]));
    }
  }

  function settleBody() {
    // A held still is cut, not faded: its two fades are the surface's own.
    if (origin.held || Theme.reduceMotion) {
      bodyPending = false;
      updateBody();
      return;
    }
    bodyPending = true;
    bodyTurn.restart();
  }

  Timer {
    id: bodyTurn

    interval: 0
    onTriggered: {
      win.bodyPending = false;
      if (!win.bodyWanted) {
        closeClock.restart();
      }
      // Only a shape that stays put needs it; one that travels is read off its own size.
      if (isNaN(win.shapeProgress)) {
        progressFallback.value = 0;
        progressFallback.kick(0);
      }
      win.updateBody();
    }
  }

  onBodyWantedChanged: settleBody()
  onMorphProgressChanged: if (!bodyPending)
    updateBody()

  Connections {
    target: origin

    function onHeldChanged() {
      win.settleBody();
    }
  }

  Connections {
    target: widthSpring

    function onTargetChanged() {
      win.fromW = widthSpring.value;
      win.fromH = heightSpring.value;
      win.settleBody();
    }
  }

  Connections {
    target: heightSpring

    function onTargetChanged() {
      win.fromW = widthSpring.value;
      win.fromH = heightSpring.value;
      win.settleBody();
    }
  }

  // With QS_MOTION_LOG=1: the contents' opacity against the intent (1 open, 0 closed), which
  // check.mjs --expect-monotonic wants to see never turn back inside one intent.
  FrameAnimation {
    running: Theme.motionLog && win.tall && (win.morphRunning || (bodyHolder.opacity > 0 && bodyHolder.opacity < 1))
    onTriggered: console.info("motion surface." + win.key + ".body " + Date.now() + " " + bodyHolder.opacity.toFixed(4) + " 0.0000 " + ((win.open && origin.presented) || (origin.held && win.stillCarriesBody) ? "1.0000" : "0.0000"))
  }

  // ---- the window ----
  //
  // Quickshell destroys a layer surface's window when it is hidden and builds a new one on
  // show, and that new window's first frame was 35-216 ms late, which every open paid. So the
  // window outlives the close: parked, a 1 px sliver drawing nothing and taking no input, it
  // costs a strip of buffer, and the next open is a resize, a frame or two.

  readonly property real fullHeight: win.screen ? win.screen.height : 0

  // Down from the moment the surface starts showing; raised a beat after it stops, once the
  // bar's pill has had a frame to land under it.
  property bool parked: true

  // Unparked and the compositor has made the window full height. Nothing is drawn before:
  // a frame committed at the sliver while the resize is pending gets no frame callback from
  // Hyprland, and Qt then holds the first full-size frame for its 100 ms callback timeout.
  readonly property bool tall: !parked && fullHeight > 0 && win.height >= fullHeight - 1

  Timer {
    id: parkDelay

    interval: Theme.surfacePark
    onTriggered: {
      if (win.showing)
        return;
      win.parked = true;
      // The close is off screen; the shape Behaviors are live again for the next open. A held
      // still parks with handover still raised, which keeps its cut to the pill instant.
      win.handover = false;
      win.farewell = false;
      win.stillCarriesBody = false;
      retainTimer.restart();
    }
  }

  // A parked window still holds a render context (~8 MiB of GPU memory each, nine surfaces
  // an output), so one left unused for a while is let go. The next open makes a new window and
  // waits out its first frame with the pill still up, which is slower but never bare.
  property bool retained: false

  Timer {
    id: retainTimer

    interval: Theme.surfaceRetain
    onTriggered: if (win.parked)
      win.retained = false
  }

  screen: modelData
  // Mapped while in use and for a while after, parked; unmapped for the lock, so its snapshot
  // never holds shell UI.
  visible: !Bus.locking && (win.showing || win.retained)
  color: "transparent"

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: win.layerNamespace

  anchors {
    top: true
    left: true
    right: true
  }

  implicitHeight: win.parked ? 1 : win.fullHeight

  exclusionMode: ExclusionMode.Ignore

  // The input region while open, which the policy picks: the whole window, the card, or
  // nothing. Not open (closing, a still, parked), nothing: the shape on its way out must not
  // swallow the clicks of whoever is below.
  property Region openMask: null

  property alias emptyMask: emptyMask
  property alias cardMask: cardMask

  mask: win.open ? win.openMask : emptyMask

  Region {
    id: emptyMask
  }

  // The open card's final shape, centred and snapped as the surface will sit at rest, from the
  // first frame of an open: a click off a card still opening dismisses it, and the region does
  // not change every tick of the morph.
  Region {
    id: cardMask

    readonly property real w: surface.snap(win.openWidth)
    readonly property real h: surface.snap(win.openHeight)

    x: surface.snap((win.width - w) / 2 + origin.offsetX)
    y: surface.snap(Theme.barMarginTop + origin.offsetY - (win.centred ? Math.max(0, Math.min(h, Theme.islandPillHeight) - Theme.barHeight) / 2 : 0))
    width: w
    height: h
  }

  onShowingChanged: {
    if (Theme.motionLog)
      console.info("motion surface." + win.key + ".showing " + Date.now() + " " + (showing ? "1.0000" : "0.0000") + " 0.0000 " + (showing ? "1.0000" : "0.0000"));
    if (showing) {
      parkDelay.stop();
      retainTimer.stop();
      retained = true;
      parked = false;
    } else {
      parkDelay.restart();
    }
  }

  Connections {
    target: Bus

    // Another surface taking the island takes it from here. On this output it is growing in
    // this surface's place, so this one cuts, even on its way down: left to finish its close,
    // it would shrink beside the taker growing out of the pill. On any other output an open
    // one takes its own close and one already closing carries on.
    function onIslandClaimed(screen) {
      if (win.claiming || origin.held)
        return;
      var here = win.screenName !== "" && screen === win.screenName;
      if (here && win.showing && !win.parked)
        win.dismiss();
      else if (win.closesElsewhere && win.open)
        win.hide();
    }
  }

  FrostedSurface {
    id: surface

    // Parked, nothing is drawn, including on the frames before the window is down to its
    // sliver; a still that has finished is already transparent, a close is on the bar's pill.
    visible: win.tall

    // The still fades in two parts: its contents at once, its ground only once the taker has
    // a frame on screen to show through it, so the island's spot is never left bare.
    contentOpacity: win.farewell ? 0 : 1
    backdropOpacity: win.farewell && origin.takerPresented ? 0 : 1

    // Only the fade out is animated; the reset lands off screen in one frame. Guarded on
    // `handover`, not `farewell`: a Behavior's enabled binding is evaluated before farewell changes.
    Behavior on contentOpacity {
      enabled: win.handover

      Morph {
        duration: Theme.morphFarewell
      }
    }

    Behavior on backdropOpacity {
      enabled: win.handover

      Morph {
        duration: Theme.duration(Theme.morphGroundFade)
      }
    }

    x: snap((win.width - width) / 2 + origin.offsetX)
    y: snap(Theme.barMarginTop + origin.offsetY - (win.centred ? Math.max(0, Math.min(height, Theme.islandPillHeight) - Theme.barHeight) / 2 : 0))

    clipContent: true

    // Contents are laid out at the open size, in a box that stays where the open card will sit,
    // so the growing card uncovers them. The open card's top, as the y below works it out.
    contentWidth: win.openWidth
    contentHeight: win.openHeight
    contentLeft: (win.width - snap(contentWidth)) / 2 + origin.offsetX
    contentTop: Theme.barMarginTop + origin.offsetY - (win.centred ? Math.max(0, Math.min(snap(contentHeight), Theme.islandPillHeight) - Theme.barHeight) / 2 : 0)

    implicitWidth: widthSpring.value
    implicitHeight: heightSpring.value

    // Read off the height rather than travelling; see Bar/Island.qml. A still riding a taker's
    // morph asks for the taker's radius, as it does for target shape and duration, on a spring so
    // it does not jump when it is seated.
    surfaceRadius: Math.min(height / 2, radiusSpring.value)

    // The complete collapsed pill carried over from the shape this surface grew out of. Up on
    // the first frame of an open out of the island, so that frame matches the pill it covers;
    // a shape from another surface or the drop well had no clock, so none is brought.
    fillData: CollapsedPill {
      anchors.fill: parent
      origin: origin
      shown: !origin.held && !(win.open && (origin.presented || origin.handedOver || !origin.fromClock))
      // Closing, the clock and marks arrive with the shape rather than on a timer of their own.
      progressDriven: !win.open && !origin.held
      amount: win.pillAmount
    }

    // Everything the surface draws, cross-faded against that clock; nothing inside fades on
    // its own. Its opacity is read off the shape's progress (updateBody), so out of another panel,
    // where there is no clip, contents arrive late in the travel and settle a few px.
    // Both wait for the first frame, so a slow one cannot eat the choreography.
    Item {
      id: bodyHolder

      anchors.fill: parent
      opacity: win.bodyOpacity
      visible: opacity > 0
      Keys.forwardTo: win.contentKeyTargets

      // Taken off the fade rather than run beside it, so the two cannot fall out of step and
      // the reveal out of the pill, where the travel is zero, is left untouched.
      transform: Translate {
        y: (1 - bodyHolder.opacity) * win.enterTravel
      }
    }
  }

  Item {
    id: overlay

    anchors.fill: parent
  }
}
