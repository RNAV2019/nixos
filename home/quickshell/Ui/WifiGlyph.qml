import QtQuick
import qs.Commons

// The Wi-Fi mark: Material's signal wedge, filled to the signal strength, in `litColor`; with no
// connection, the struck-through wedge in `dimColor`. Shared by the island's status gauge and
// the control centre's tile.
Item {
  id: root

  // Signal strength 0..1.
  property real strength: 0
  property bool connected: false
  property color litColor
  property color dimColor

  // The wedge's point, which callers place where the old mark's dot sat.
  readonly property real centreX: 12
  readonly property real centreY: 20

  implicitWidth: 24
  implicitHeight: 24

  Text {
    anchors.centerIn: parent
    text: root.connected ? Icons.step(Icons.wifi, root.strength * 100) : Icons.networkOff
    color: root.connected ? root.litColor : root.dimColor
    font.family: Theme.iconFont
    font.pixelSize: 24
  }
}
