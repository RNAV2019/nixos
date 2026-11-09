import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Ui
import "../Ui/Motion.js" as Motion

// The phone satellite (board "Phone satellite"): while KDE Connect has a phone, a disc buds out
// of the right end of whatever the island is wearing - the pill, the open card, or a transient
// pill such as the OSD - and rides that edge. It comes and goes like a drop of liquid on a neck
// (Motion.satelliteStep): going out it is held back by the neck, so it starts slowly, speeds up as
// the neck stretches and thins, and past Theme.phoneBridgeBreak the neck snaps, both ends recoil
// into rounded tips, and the disc settles into its dock with a little give. Coming in, a pull
// that grows as the gap closes draws it home; on contact the neck re-forms and the pill's end
// swells and relaxes. Shaders/satellite.frag draws it. A full panel taking the island draws it
// back in, at once (Theme.phonePull0Taken); clicking it does the same. The phone panel is asked for
// on the click, while the disc is still at rest, and held as the pill it grows out of until the
// disc touches the pill (Bus.holdPresent), so the panel grows out as the disc sinks in and the
// panel's first frame, the dear one, is not paid for in the middle of the disc's flight.
//
// This item holds the logic and the geometry. The geometry goes to Bus.satellite every frame it
// changes; the bar's SatelliteLayer draws it, and a transient surface's window draws it instead
// while the satellite rides that transient, so the bud lies over the transient's outline.
Item {
  id: root

  // The bar's island and output; the satellite rides the island unless a transient covers it.
  required property Item pill
  required property string screenName

  // Where the bar's window starts on screen, to place a transient's shape (drawn in a window
  // spanning the output from its top) in this one.
  property real windowTop: 0

  // ---- what it rides ----

  readonly property var transientShape: Bus.transientOnScreen(screenName) ? Bus.transientSurfaceFor(screenName) : null
  // A lock takes the transients' windows away, so while it is up the bar carries it, as it
  // carries the pill.
  readonly property var follow: transientShape && transientShape.visible && !Bus.locking ? transientShape : pill
  readonly property bool followingTransient: follow !== pill

  // What `f` is just now, in this window's coordinates. The pill's edge is the springs' own,
  // unsnapped, while it moves; at rest it is where the pill is actually drawn.
  function rawFor(f) {
    var t = f !== pill;
    return {
      follow: f,
      transient: t,
      edge: t || !f.morphRunning ? f.x + f.width : f.edgeX,
      top: t ? f.y - windowTop : f.y,
      height: f.height,
      width: f.width,
      // The stadium's own end circle, or for the open card its corner radius.
      capR: Math.max(1, Math.min(f.height / 2, f.surfaceRadius))
    };
  }

  readonly property var raw: rawFor(follow)

  // What is drawn: `raw`, plus whatever jump the last change of what it rides left, which a
  // spring carries to nothing. Written whenever either moves; see syncEff().
  property var eff: null
  property var lastFollow: null
  property var delta: ({
      edge: 0,
      top: 0,
      height: 0,
      width: 0,
      capR: 0
    })

  MorphSpring {
    id: blend

    label: "phone.blend"
    target: 0
    epsilon: 0.001
    onValueChanged: root.syncEff()
  }

  // The edge it rides has not moved for a moment.
  property real lastEdge: 0
  property real lastTop: 0
  readonly property bool edgeStill: !edgeQuiet.running

  Timer {
    id: edgeQuiet

    interval: 60
  }

  function syncEff() {
    var r = raw;
    if (!r || !r.follow)
      return;
    if (r.follow !== lastFollow) {
      var swap = lastFollow !== null && eff !== null && !Theme.reduceMotion;
      lastFollow = r.follow;
      if (swap) {
        delta = {
          edge: eff.edge - r.edge,
          top: eff.top - r.top,
          height: eff.height - r.height,
          width: eff.width - r.width,
          capR: eff.capR - r.capR
        };
        blend.value = 1;
        blend.kick(0);
      }
    }
    var b = blend.value;
    if (eff === null || Math.abs(r.edge - lastEdge) > 0.01 || Math.abs(r.top - lastTop) > 0.01)
      edgeQuiet.restart();
    lastEdge = r.edge;
    lastTop = r.top;
    eff = {
      transient: r.transient,
      edge: r.edge + delta.edge * b,
      top: r.top + delta.top * b,
      height: r.height + delta.height * b,
      width: r.width + delta.width * b,
      capR: Math.max(1, r.capR + delta.capR * b)
    };
  }

  onRawChanged: syncEff()

  // ---- out or in ----

  // A click draws it in first; see openPanel(). `landing` from the click until the disc touches
  // the pill, which is as long as the panel it asked for is held back.
  property bool retreating: false
  property bool landing: false

  readonly property bool panelUp: Bus.islandCovered(screenName) || Bus.islandOpenFor(screenName)
  // A lock does not draw it in: like the bar it stays, so the snapshot behind the lock screen
  // carries it where it sat.
  readonly property bool wantOut: Phone.connected && (Bus.sessionReady || Bus.locking) && !panelUp && !retreating

  readonly property real satRadius: Theme.phoneSatelliteSize / 2
  // The disc starts a little inside the edge and grows to full size over the first 70% of its
  // travel; docked it sits phoneSatelliteGap off the edge.
  readonly property real startInset: 6
  readonly property real travel: startInset + Theme.phoneSatelliteGap + satRadius

  // The simulation's tokens (Motion.satelliteStep lists what each is). Unlike the island's morphs
  // it gives a little at the dock; see Theme.phoneSpringDamping. Times are seconds there.
  readonly property var simParams: ({
      travel: travel,
      startInset: startInset,
      satR: satRadius,
      grow: 0.7,
      dock: travel,
      reach: Theme.phoneReach,
      omega: Theme.phoneSpringOmega,
      zeta: Theme.phoneSpringDamping,
      rampFrom: Theme.phoneRampFrom,
      rampTime: Theme.phoneRampTime / 1000,
      tension: Theme.phoneTension,
      tensionLead: Theme.phoneTensionLead,
      breakGap: Theme.phoneBridgeBreak,
      maxHold: Theme.phoneMaxHold / 1000,
      neckK: Theme.phoneNeckK,
      neckOn: Theme.phoneNeckOn / 1000,
      pull0: root.retreating || root.panelUp ? Theme.phonePull0Taken : Theme.phonePull0,
      pull1: Theme.phonePull1,
      pullDrag: Theme.phonePullDrag,
      mergeOmega: Theme.phoneMergeOmega,
      stubOmega: Theme.phoneStubOmega,
      stubZeta: Theme.phoneStubDamping,
      stubKick: Theme.phoneStubKick,
      // The pill's end swells as the disc comes home, and wobbles as it relaxes. Not when a panel is
      // taking the island: the pill is about to grow into the panel, and a swell and a wobble in
      // the frames before it does read as the pill being squashed.
      bulgeKick: root.retreating || root.panelUp ? 0 : Motion.satelliteKick(Theme.phoneBulge, Theme.phoneBulgeOmega, Theme.phoneBulgeDamping),
      bulgeOmega: Theme.phoneBulgeOmega,
      bulgeZeta: Theme.phoneBulgeDamping,
      bulgeVRef: Theme.phoneBulgeVRef,
      restEps: Theme.phoneRestEps
    })

  // The simulation's state (see Motion.satelliteRest), replaced every frame it runs. It starts
  // at rest where the target is, as a spring does.
  property var sim: Motion.satelliteRest(false, simParams)

  readonly property real p: sim.x / travel

  function snapSim() {
    driver.stop();
    sim = Motion.satelliteRest(wantOut, simParams);
  }

  onWantOutChanged: {
    if (Theme.reduceMotion)
      snapSim();
    else
      driver.start();
  }
  Component.onCompleted: {
    snapSim();
    syncEff();
  }

  // A stalled frame is solved for its whole length rather than slowed down; past 50 ms it is
  // clamped, as MorphSpring does.
  FrameAnimation {
    id: driver

    running: false
    onTriggered: {
      if (Theme.reduceMotion) {
        root.snapSim();
        return;
      }
      root.sim = Motion.satelliteStep(root.sim, root.simParams, root.wantOut, Math.min(0.05, Math.max(0, frameTime)));
      if (Theme.motionLog)
        root.logSim();
      if (root.sim.rest)
        stop();
    }
  }

  // One line per frame per label for tools/qs-verify/motion/check.mjs: p is progress 0..1 (and
  // may pass 1 where the neck stretches it), the others are px.
  function logSim() {
    var t = Date.now();
    var s = sim;
    var goal = wantOut ? 1 : 0;
    console.info("motion phone.p " + t + " " + p.toFixed(4) + " " + (s.v / travel).toFixed(4) + " " + goal.toFixed(4));
    console.info("motion phone.x " + t + " " + s.x.toFixed(4) + " " + s.v.toFixed(3) + " " + (wantOut ? travel : 0).toFixed(4));
    console.info("motion phone.neck " + t + " " + s.neck.toFixed(4) + " 0.000 0.0000");
    console.info("motion phone.bulge " + t + " " + s.bulge.toFixed(4) + " 0.000 0.0000");
  }

  // Locking from a panel (the session menu's Lock) closes the panel, and the disc comes back
  // out: the lock's snapshot waits until the simulation rests (the give, the stubs and the swell
  // included).
  readonly property bool settling: Bus.locking && (blend.running || driver.running)
  readonly property string holdKey: "phone-satellite:" + screenName

  onSettlingChanged: Bus.holdLock(holdKey, settling)
  Component.onDestruction: {
    if (landing)
      Bus.holdPresent("phone", false);
    Bus.holdLock(holdKey, false);
    Bus.setSatellite(screenName, null);
  }

  // Docked: out, settled near enough to take a click.
  readonly property bool docked: wantOut && p > 0.9

  // The disc touches the pill: the panel, up since the click, is let go.
  onPChanged: if (landing && p < Theme.phoneOpenAt)
    land()

  function land() {
    landing = false;
    landGiveUp.stop();
    Bus.holdPresent("phone", false);
  }

  // The disc is home well inside this; a hold must never outlive what it waits for.
  Timer {
    id: landGiveUp

    interval: 400
    onTriggered: root.land()
  }

  onPanelUpChanged: if (panelUp)
    retreating = false

  // The panel did not come (another output had focus, say): come back out.
  Timer {
    id: retreatGiveUp

    interval: 1500
    onTriggered: root.retreating = false
  }

  // The pointer on the docked disc is most often a click coming: the phone panel's window is made
  // ready (parked), so the click does not wait out a window being built after the disc is home.
  readonly property bool hovered: docked && layer.hovered
  onHoveredChanged: if (hovered)
    Bus.warmSurface("phone")

  function openPanel() {
    if (!docked)
      return;
    landing = true;
    landGiveUp.restart();
    Bus.holdPresent("phone", true);
    retreating = true;
    retreatGiveUp.restart();
    // A panel taking the island turns the disc back by itself (panelUp), reduced motion at once.
    Bus.toggleSurface("phone");
    if (landing && p < Theme.phoneOpenAt)
      land();
  }

  // ---- geometry ----

  readonly property real ratio: QsWindow.window && QsWindow.window.devicePixelRatio > 0 ? QsWindow.window.devicePixelRatio : 1

  // The disc's left or top on the device grid, except while it is travelling: it blends from the
  // free position to the snapped one over the last 0.3 px of motion, so settling neither
  // jumps nor leaves it between pixels. The give's turning points count as motion, not rest.
  function settled(v, remaining) {
    // Not while the edge it follows is moving or a hand-over is carried: it would step against
    // a smooth edge.
    if (blend.running || !edgeStill)
      return v;
    var s = Motion.snap(v - satRadius, ratio) + satRadius;
    if (!driver.running)
      return s;
    var t = Theme.clamp01(remaining / 0.3);
    return s + (v - s) * t;
  }

  function geometry() {
    var e = eff;
    if (!e)
      return null;
    var rowH = e.transient ? e.height : Math.min(e.height, Theme.barHeight);
    var mid = e.top + rowH / 2;
    var pc = Math.max(0, p);
    var s = sim;
    var r = Motion.satelliteRadius(s.x, simParams);
    var remaining = Math.abs(s.x - (wantOut ? travel : 0)) + Math.abs(s.v) / Theme.phoneSpringOmega;
    var cx = settled(e.edge - startInset + s.x, remaining);
    var cy = settled(mid, remaining);
    // The broken ends the snap leaves, reaching out of the pill and the disc and shrinking to
    // nothing as they recoil.
    var stub = Qt.point(s.stubs * Theme.phoneStubLength, Theme.phoneStubRadius * Theme.clamp01(s.stubs * 2));
    return {
      edgeX: e.edge,
      midY: mid,
      shapeY: e.top + e.height / 2,
      halfH: e.height / 2,
      shapeW: e.width,
      capR: e.capR,
      disc: Qt.vector3d(cx, cy, r),
      neck: s.neck,
      stub: stub,
      bulge: Math.max(0, s.bulge),
      follow: e.transient ? "transient" : "pill",
      windowTop: windowTop,
      p: pc,
      docked: docked,
      ring: ringShown,
      hover: layer.hovered
    };
  }

  readonly property var geo: geometry()

  // Nothing moves while the disc is away and not on its way: skip, so no window re-renders for
  // an island morph that does not concern the disc.
  property bool pushedAway: false
  onGeoChanged: {
    var away = sim.rest && !wantOut;
    if (away && pushedAway)
      return;
    pushedAway = away;
    Bus.setSatellite(screenName, geo);
  }

  // The battery ring sweeps in once the disc has landed, and is gone as soon as it leaves.
  property real ringShown: 0

  Binding {
    target: root
    property: "ringShown"
    value: root.docked && Phone.hasBattery ? 1 : 0
  }

  Behavior on ringShown {
    NumberAnimation {
      duration: root.ringShown > 0.5 ? Theme.morphContent : Theme.tintFade
      easing.type: Easing.OutCubic
    }
  }

  // ---- drawing ----

  // The bar draws it unless a transient covers the island, where the transient's window does,
  // over its outline. At each hand-over the one giving up keeps drawing until the taker has a
  // frame on screen (Ui/SatelliteLayer.qml), so there is never a frame with neither.
  SatelliteLayer {
    id: layer

    g: root.geo
    interactive: true
    screenName: root.screenName
    hostId: "bar"
    wanted: !root.followingTransient
    onClicked: root.openPanel()
  }

  // The bar's input mask takes this once the disc is nearly home (docked, p > 0.9, as before the
  // spring): one fixed rectangle at the rest position, not a region that follows the disc.
  readonly property bool hitActive: docked && geo !== null
  readonly property real hitX: eff ? (eff.edge - startInset + travel) - satRadius : 0
  readonly property real hitY: eff ? (eff.top + (eff.transient ? eff.height : Math.min(eff.height, Theme.barHeight)) / 2) - satRadius : 0
  readonly property real hitSize: Theme.phoneSatelliteSize
}
