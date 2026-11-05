import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Ui
import "../Ui/Motion.js" as Motion

// The phone satellite (board "Phone satellite"): while KDE Connect has a phone, a disc buds out
// of the right end of whatever the island is wearing - the pill, the open card, or a transient
// pill such as the OSD - and rides that edge. It comes and goes like a drop of liquid: pill and
// disc are one smooth union (Shaders/satellite.frag) whose neck thins as the disc travels; past
// Theme.phoneBridgeBreak it breaks, and the small stubs it leaves are the union's own fillet,
// fading with the gap. A full panel taking the island draws it back in; clicking it does the
// same, and the phone panel is asked for once it is mostly in, so the panel reads as growing out
// of it.
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
      capR: Math.max(1, r.capR + delta.capR * b)
    };
  }

  onRawChanged: syncEff()
  Component.onCompleted: syncEff()

  // ---- out or in ----

  // A click draws it in first; see openPanel().
  property bool retreating: false
  property bool panelAsked: false

  readonly property bool panelUp: Bus.islandCovered(screenName) || Bus.islandOpenFor(screenName)
  // A lock does not draw it in: like the bar it stays, so the snapshot behind the lock screen
  // carries it where it sat.
  readonly property bool wantOut: Phone.connected && (Bus.sessionReady || Bus.locking) && !panelUp && !retreating

  // Unlike the island's morphs, this one overshoots a little; see Theme.phoneSpringDamping.
  MorphSpring {
    id: progress

    label: "phone.p"
    target: root.wantOut ? 1 : 0
    omega: Theme.phoneSpringOmega
    damping: Theme.phoneSpringDamping
    epsilon: 0.001
  }

  readonly property real p: progress.value

  // Locking from a panel (the session menu's Lock) closes the panel, and the disc comes back
  // out: the lock's snapshot waits until it has stopped (the overshoot included), not merely
  // until the spring's last thousandth.
  readonly property bool settling: Bus.locking && (blend.running || (progress.running && !(Math.abs(p - progress.target) < 0.005 && Math.abs(progress.velocity) < 0.05)))
  readonly property string holdKey: "phone-satellite:" + screenName

  onSettlingChanged: Bus.holdLock(holdKey, settling)
  Component.onDestruction: {
    Bus.holdLock(holdKey, false);
    Bus.setSatellite(screenName, null);
  }

  // Docked: out, settled near enough to take a click.
  readonly property bool docked: wantOut && p > 0.9

  // The spring's frame handler is no place to open a surface: that waits for the turn.
  onPChanged: {
    if (retreating && !panelAsked && p < Theme.phoneOpenAt) {
      panelAsked = true;
      Qt.callLater(Bus.toggleSurface, "phone");
    }
  }

  onPanelUpChanged: if (panelUp)
    retreating = false

  // The panel did not come (another output had focus, say): come back out.
  Timer {
    id: retreatGiveUp

    interval: 1500
    onTriggered: root.retreating = false
  }

  function openPanel() {
    if (!docked)
      return;
    panelAsked = false;
    retreating = true;
    retreatGiveUp.restart();
  }

  // ---- geometry ----

  readonly property real satRadius: Theme.phoneSatelliteSize / 2
  // The disc starts a little inside the edge and grows to full size over the first 70%; docked
  // it sits phoneSatelliteGap off the edge.
  readonly property real startInset: 6
  readonly property real travel: startInset + Theme.phoneSatelliteGap + satRadius

  readonly property real ratio: QsWindow.window && QsWindow.window.devicePixelRatio > 0 ? QsWindow.window.devicePixelRatio : 1

  // The disc's left or top on the device grid, except while it is travelling: it blends from the
  // free position to the snapped one over the last 0.3 px of motion, so settling neither
  // jumps nor leaves it between pixels. The overshoot's turning points count as motion, not rest.
  function settled(v, remaining) {
    // Not while the edge it follows is moving or a hand-over is carried: it would step against
    // a smooth edge.
    if (blend.running || !edgeStill)
      return v;
    var s = Motion.snap(v - satRadius, ratio) + satRadius;
    if (!progress.running)
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
    var r = satRadius * Theme.clamp01(pc / 0.7);
    var remaining = (Math.abs(p - progress.target) + Math.abs(progress.velocity) / progress.omega) * travel;
    var cx = settled(e.edge - startInset + travel * pc, remaining);
    var cy = settled(mid, remaining);
    // The neck's width falls with the gap between the edge and the disc, reaching twice the
    // gap (a neck of no thickness) at Theme.phoneBridgeBreak, and grows with the disc so a bud
    // too small to see does not bulge the pill.
    var gap = cx - r - e.edge;
    var b = Theme.phoneBridgeBreak;
    var k = Math.max(0, 2 * (2 * b - gap)) * Theme.clamp01(r / (satRadius * 0.5));
    return {
      edgeX: e.edge,
      midY: mid,
      shapeY: e.top + e.height / 2,
      halfH: e.height / 2,
      capR: e.capR,
      disc: Qt.vector3d(cx, cy, r),
      neck: k,
      follow: e.transient ? "transient" : "pill",
      windowTop: windowTop,
      p: pc,
      docked: docked,
      ring: ringShown,
      hover: layer.hovered
    };
  }

  readonly property var geo: geometry()

  onGeoChanged: Bus.setSatellite(screenName, geo)

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

  // The bar's input mask takes this while the disc is docked and still: one fixed rectangle,
  // not a region that follows the disc each frame.
  readonly property bool hitActive: docked && !progress.running && !blend.running && geo !== null
  readonly property real hitX: geo ? geo.disc.x - satRadius : 0
  readonly property real hitY: geo ? geo.disc.y - satRadius : 0
  readonly property real hitSize: Theme.phoneSatelliteSize
}
