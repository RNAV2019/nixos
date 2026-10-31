import QtQuick
import qs.Commons

// The Bluetooth mark on the Wi-Fi mark's 24 px box, so the two read as a pair: Material's rune,
// with its connected and disabled forms.
Item {
  id: root

  property color color
  property bool connected: false
  property bool off: false

  implicitWidth: 24
  implicitHeight: 24

  Text {
    anchors.centerIn: parent
    text: root.off ? Icons.bluetoothOff : root.connected ? Icons.bluetoothConnected : Icons.bluetoothOn
    color: root.color
    font.family: Theme.iconFont
    font.pixelSize: 24
  }
}
