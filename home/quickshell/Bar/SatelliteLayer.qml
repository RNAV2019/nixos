import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Ui

// The phone satellite as it is drawn: the body (Bar/SatelliteShape.qml) and the disc's face (its
// hover wash, battery ring and glyph) from one geometry `g`, the entry Bar/PhoneSatellite.qml keeps
// in Bus.satellite. Two windows host one each, never at once for more than a few frames: the bar's,
// under the transients, and a transient surface's, over its outline. `yOffset` turns the bar
// window's y into the host window's. Only the bar's takes the pointer.
Item {
  id: root

  property var g: null
  property real yOffset: 0
  property bool interactive: false
  // Whether this host draws it just now. A host that is not drawing keeps its pointer area, so a
  // satellite riding a transient can still be clicked through the bar.
  property bool shown: true

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
