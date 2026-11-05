import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Services
import qs.Ui

// The phone satellite (board "Phone satellite"): while KDE Connect has a phone, a disc buds out
// of the right end of whatever the island is wearing - the pill, the open card, or a transient
// pill such as the OSD - and rides that edge. It comes and goes like a drop of liquid: one
// outline holds pill, bridge and disc while they touch, the bridge thins as the disc travels,
// and past Theme.phoneBridgeBreak it snaps, leaving a stub on each side that pulls back in.
// A full panel taking the island draws it back in; clicking it does the same, and the phone
// panel is asked for once it is mostly in, so the panel reads as growing out of it.
//
// Lives in the bar's window, full size, so the shapes are drawn in that window's coordinates.
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
  readonly property var follow: transientShape && transientShape.visible ? transientShape : pill
  readonly property bool followingTransient: follow !== pill

  readonly property real edge: follow ? follow.x + follow.width : 0
  readonly property real followTop: follow ? (followingTransient ? follow.y - windowTop : follow.y) : 0
  readonly property real followHeight: follow ? follow.height : Theme.barHeight
  // The disc sits on the row of the pill: a transient is that one row, and the open card's top
  // row is as tall as the resting pill, so the disc stays where it was budding from instead of
  // sliding down to the card's middle.
  readonly property real rowHeight: followingTransient ? followHeight : Math.min(followHeight, Theme.barHeight)
  readonly property real midline: followTop + rowHeight / 2
  // The end cap the bridge leaves from: the stadium's own circle, or for the open card a
  // circle of its corner radius, which is near enough for a bridge that only shows in motion.
  readonly property real capRadius: follow ? Math.max(1, Math.min(rowHeight / 2, follow.surfaceRadius)) : Theme.barHeight / 2

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
  readonly property bool settling: Bus.locking && progress.running && !(Math.abs(p - progress.target) < 0.005 && Math.abs(progress.velocity) < 0.05)
  readonly property string holdKey: "phone-satellite:" + screenName

  onSettlingChanged: Bus.holdLock(holdKey, settling)
  Component.onDestruction: Bus.holdLock(holdKey, false)

  // Docked: out, settled near enough to take a click.
  readonly property bool docked: wantOut && p > 0.9

  onPChanged: {
    if (retreating && !panelAsked && p < Theme.phoneOpenAt) {
      panelAsked = true;
      Bus.toggleSurface("phone");
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
  // Centre distance from the cap's centre: docked, the disc sits phoneSatelliteGap off the
  // edge; it starts a little inside the cap, and grows to full size over the first 70%.
  readonly property real dockDistance: capRadius + Theme.phoneSatelliteGap + satRadius
  readonly property real startDistance: capRadius - 6
  readonly property real distance: startDistance + (dockDistance - startDistance) * p
  readonly property real radius: satRadius * Theme.clamp01(p / 0.7)

  readonly property point capCentre: Qt.point(edge - capRadius, midline)
  readonly property point centre: Qt.point(capCentre.x + distance, midline)

  readonly property bool inside: radius < 0.5 || distance + radius <= capRadius + 0.5
  readonly property bool attached: !inside && distance - capRadius - radius < Theme.phoneBridgeBreak

  // The stubs the bridge leaves when it breaks on the way out, 1 just broken to 0 gone.
  property real nub: 0

  NumberAnimation {
    id: nubFade

    target: root
    property: "nub"
    from: 1
    to: 0
    duration: Theme.phoneNubFade
  }

  onAttachedChanged: {
    if (!attached && !inside && progress.velocity > 0)
      nubFade.restart();
    else if (attached) {
      nubFade.stop();
      nub = 0;
    }
  }

  // The metaball bridge from circle (c1, r1) to circle (c2, r2), after Varun Vachhar's
  // "Metaballs": tangent points spread by v along each rim, joined by two cubics whose handles
  // shorten as the circles close. `fill` closes on a chord through circle 1, so drawn over it
  // the fill also hides circle 1's outline where the bridge leaves; `stroke` is the outer
  // contour alone, bridge and far rim of circle 2.
  function bridge(c1, r1, c2, r2) {
    var v = 0.5, handle = 2.4;
    var d = Math.hypot(c2.x - c1.x, c2.y - c1.y);
    if (d <= Math.abs(r1 - r2) || r2 <= 0)
      return null;
    var u1 = 0, u2 = 0;
    if (d < r1 + r2) {
      u1 = Math.acos((r1 * r1 + d * d - r2 * r2) / (2 * r1 * d));
      u2 = Math.acos((r2 * r2 + d * d - r1 * r1) / (2 * r2 * d));
    }
    var along = Math.atan2(c2.y - c1.y, c2.x - c1.x);
    var spread = Math.acos((r1 - r2) / d);
    var a1 = along + u1 + (spread - u1) * v;
    var a2 = along - u1 - (spread - u1) * v;
    var a3 = along + Math.PI - u2 - (Math.PI - u2 - spread) * v;
    var a4 = along - Math.PI + u2 + (Math.PI - u2 - spread) * v;
    function at(c, a, r) {
      return {
        x: c.x + r * Math.cos(a),
        y: c.y + r * Math.sin(a)
      };
    }
    var p1 = at(c1, a1, r1), p2 = at(c1, a2, r1), p3 = at(c2, a3, r2), p4 = at(c2, a4, r2);
    var reach = Math.min(v * handle, Math.hypot(p1.x - p3.x, p1.y - p3.y) / (r1 + r2)) * Math.min(1, d * 2 / (r1 + r2));
    var h1 = at(p1, a1 - Math.PI / 2, r1 * reach), h2 = at(p2, a2 + Math.PI / 2, r1 * reach);
    var h3 = at(p3, a3 + Math.PI / 2, r2 * reach), h4 = at(p4, a4 - Math.PI / 2, r2 * reach);
    var sweep = a3 - a4;
    while (sweep <= 0)
      sweep += 2 * Math.PI;
    function pt(q) {
      return q.x.toFixed(2) + " " + q.y.toFixed(2);
    }
    var r = r2.toFixed(2);
    var open = "M " + pt(p2) + " C " + pt(h2) + " " + pt(h4) + " " + pt(p4) + " A " + r + " " + r + " 0 " + (sweep > Math.PI ? 1 : 0) + " 1 " + pt(p3) + " C " + pt(h3) + " " + pt(h1) + " " + pt(p1);
    return {
      fill: open + " Z",
      stroke: open
    };
  }

  function circle(c, r) {
    var s = r.toFixed(2);
    return "M " + (c.x - r).toFixed(2) + " " + c.y.toFixed(2) + " A " + s + " " + s + " 0 1 1 " + (c.x + r).toFixed(2) + " " + c.y.toFixed(2) + " A " + s + " " + s + " 0 1 1 " + (c.x - r).toFixed(2) + " " + c.y.toFixed(2) + " Z";
  }

  // While attached, one bridge from the cap to the disc carries the disc's outline too.
  readonly property var joined: attached ? bridge(capCentre, capRadius, centre, radius) : null

  // After the break, a stub on the pill reaching right and one on the disc reaching left.
  readonly property real nubRadius: 1.3 * nub
  readonly property var pillNub: nub > 0 && !attached && !inside ? bridge(capCentre, capRadius, Qt.point(edge + 2 * nub, midline), nubRadius) : null
  readonly property var satNub: nub > 0 && !attached && !inside ? bridge(centre, radius, Qt.point(centre.x - radius - 2 * nub, midline), nubRadius) : null

  visible: Phone.connected || p > 0.001

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    // The disc on its own.
    ShapePath {
      fillColor: Theme.surface
      strokeColor: Theme.surfaceOutline
      strokeWidth: 1

      PathSvg {
        path: !root.inside && !root.attached ? root.circle(root.centre, root.radius - 0.5) : ""
      }
    }

    ShapePath {
      fillColor: Theme.surface
      strokeColor: "transparent"

      PathSvg {
        path: root.joined ? root.joined.fill : root.pillNub ? root.pillNub.fill : ""
      }
    }

    ShapePath {
      fillColor: "transparent"
      strokeColor: Theme.surfaceOutline
      strokeWidth: 1

      PathSvg {
        path: root.joined ? root.joined.stroke : root.pillNub ? root.pillNub.stroke : ""
      }
    }

    ShapePath {
      fillColor: Theme.surface
      strokeColor: "transparent"

      PathSvg {
        path: root.satNub ? root.satNub.fill : ""
      }
    }

    ShapePath {
      fillColor: "transparent"
      strokeColor: Theme.surfaceOutline
      strokeWidth: 1

      PathSvg {
        path: root.satNub ? root.satNub.stroke : ""
      }
    }
  }

  // ---- the disc's face ----

  readonly property color ink: Phone.low ? Theme.love : Theme.text

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

  Item {
    id: face

    x: root.centre.x - root.satRadius
    y: root.midline - root.satRadius
    width: Theme.phoneSatelliteSize
    height: Theme.phoneSatelliteSize
    visible: !root.inside

    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: Theme.withAlpha(Theme.highlightMed, hit.containsMouse && root.docked ? 0.45 : 0)

      Behavior on color {
        Tint {}
      }
    }

    Ring {
      anchors.fill: parent
      stroke: Theme.phoneRingWidth
      ringRadius: Theme.phoneRingRadius
      trackColor: Theme.withAlpha("white", 0.08)
      fillColor: Phone.low ? Theme.love : Theme.accent
      value: Math.max(0, Phone.charge) / 100 * root.ringShown
      opacity: root.ringShown
      visible: opacity > 0
    }

    // Fades in through the middle of the travel, growing with the disc.
    StrokeIcon {
      anchors.centerIn: parent
      path: Icons.phone
      size: Theme.phoneSatelliteGlyph
      color: root.ink
      opacity: Theme.clamp01((root.p - 0.35) / 0.45)
      scale: Math.min(1, root.radius / root.satRadius)

      Behavior on color {
        Tint {}
      }
    }

    MouseArea {
      id: hit

      anchors.fill: parent
      enabled: root.docked
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.openPanel()
    }
  }

  // The bar's input mask takes this while the disc is out.
  readonly property Item hitItem: docked ? face : null
}
