import QtQuick
import Quickshell
import qs.Commons
import qs.Services

// The phone satellite as it is drawn: the body (Ui/SatelliteShape.qml) and the disc's face (its
// hover wash, battery ring and glyph) from one geometry `g`, the entry Bar/PhoneSatellite.qml keeps
// in Bus.satellite. Two kinds of window host one each: the bar's, under the transients, and a
// transient surface's, over its outline. `yOffset` turns the bar window's y into the host window's.
// Only the bar's takes the pointer.
//
// Hand-over without a gap: a host that becomes `wanted` claims the satellite on its output
// (Bus.claimSatelliteHost) and reports when a frame showing it has been swapped in its window; the
// host it took over from keeps drawing until then, with Theme.morphPresentFallback as the upper
// bound, so there is never a frame with neither drawing it.
Item {
  id: root

  property var g: null
  property real yOffset: 0
  property bool interactive: false
  // Which output, and which host this is (unique per window).
  property string screenName: ""
  property string hostId: ""
  // This host is the one the satellite rides now.
  property bool wanted: true
  // Drawing: wanted, or handing over and the taker has no frame on screen yet. A host that is not
  // drawing keeps its pointer area, so a satellite riding a transient can still be clicked through
  // the bar.
  readonly property bool shown: wanted || (lingering && pending)

  readonly property bool pending: Bus.satelliteHandoverPending(screenName)
  property bool lingering: false
  property bool armed: false
  property bool synced: false
  // Swaps since then. The window renders on its own thread, so the first swap after the sync can
  // be the frame before it; the second is certainly one that carries the bud.
  property int swaps: 0

  // A frame of this host has shown the bud since it took it over.
  property bool hasFrame: false

  function take() {
    lingering = false;
    Bus.claimSatelliteHost(screenName, hostId);
    armed = true;
    synced = false;
    swaps = 0;
    fallback.restart();
    if (frameWindow)
      frameWindow.update();
  }

  function giveUp() {
    armed = false;
    fallback.stop();
    lingering = hasFrame;
    hasFrame = false;
    if (lingering)
      lingerEnd.restart();
  }

  onWantedChanged: wanted ? take() : giveUp()
  Component.onCompleted: if (wanted)
    take()
  Component.onDestruction: if (wanted)
    Bus.releaseSatelliteHost(screenName, hostId)

  onPendingChanged: if (!pending)
    lingering = false

  readonly property var frameWindow: root.Window ? root.Window.window : null

  Connections {
    target: root.frameWindow
    ignoreUnknownSignals: true

    // Before the frame's sync: the frame after this one carries the state that shows the bud.
    function onAfterAnimating() {
      if (root.armed && root.visible)
        root.synced = true;
    }

    function onFrameSwapped() {
      if (!root.armed || !root.synced)
        return;
      if (++root.swaps >= 2)
        root.reported();
      else if (root.frameWindow)
        root.frameWindow.update();
    }
  }

  function reported() {
    armed = false;
    synced = false;
    hasFrame = true;
    fallback.stop();
    Bus.reportSatelliteReady(screenName, hostId);
  }

  Timer {
    id: fallback

    interval: Theme.morphPresentFallback
    onTriggered: if (root.armed)
      root.reported()
  }

  // A hand-over that no taker ever claims must not leave this host drawing.
  Timer {
    id: lingerEnd

    interval: Theme.morphPresentFallback
    onTriggered: root.lingering = false
  }

  signal clicked

  readonly property real ratio: QsWindow.window && QsWindow.window.devicePixelRatio > 0 ? QsWindow.window.devicePixelRatio : 1
  readonly property real satRadius: Theme.phoneSatelliteSize / 2

  y: yOffset
  visible: g !== null && g.p > 0.002

  SatelliteShape {
    visible: root.visible && root.shown
    pillEdge: root.g ? Qt.point(root.g.edgeX, root.g.shapeY) : Qt.point(0, 0)
    pillHalfH: root.g ? root.g.halfH : 0
    capRadius: root.g ? root.g.capR : 0
    disc: root.g ? root.g.disc : Qt.vector3d(0, 0, 0)
    neck: root.g ? root.g.neck : 0
    aa: 1 / root.ratio
  }

  readonly property color ink: Phone.low ? Theme.love : Theme.text

  Item {
    id: face

    x: root.g ? root.g.disc.x - root.satRadius : 0
    y: root.g ? root.g.disc.y - root.satRadius : 0
    width: Theme.phoneSatelliteSize
    height: Theme.phoneSatelliteSize

    Item {
      anchors.fill: parent
      visible: root.shown

      Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.withAlpha(Theme.highlightMed, root.g && root.g.hover && root.g.docked ? 0.45 : 0)

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
        value: Math.max(0, Phone.charge) / 100 * (root.g ? root.g.ring : 0)
        opacity: root.g ? root.g.ring : 0
        visible: opacity > 0
      }

      // Fades in through the middle of the travel, growing with the disc.
      StrokeIcon {
        anchors.centerIn: parent
        path: Icons.phone
        size: Theme.phoneSatelliteGlyph
        color: root.ink
        opacity: root.g ? Theme.clamp01((root.g.p - 0.35) / 0.45) : 0
        scale: root.g ? Math.min(1, root.g.disc.z / root.satRadius) : 0

        Behavior on color {
          Tint {}
        }
      }
    }

    MouseArea {
      id: hit

      anchors.fill: parent
      enabled: root.interactive && root.g !== null && root.g.docked
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.clicked()
    }
  }

  readonly property bool hovered: hit.containsMouse
}
