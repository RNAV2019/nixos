import QtQuick
import qs.Commons
import qs.Services

// Board 02's system gauge, beside the battery one: memory on the ring, CPU load in the chip
// at its centre, power draw in the gap, rising while charging and falling on battery.
Gauge {
  id: root

  value: SystemStats.memory
  strokeColor: Theme.rose

  // A CPU chip whose core fills from the bottom with load, like the Wi-Fi bars light with signal.
  Item {
    id: chip

    x: 24 - width / 2
    y: 26 - height / 2
    width: 20
    height: 20

    Repeater {
      model: 12

      Rectangle {
        required property int index

        readonly property int side: Math.floor(index / 3)
        readonly property real along: 6.5 + (index % 3) * 3.5

        x: side === 0 ? along - 0.8 : side === 1 ? 17 : side === 2 ? along - 0.8 : 0
        y: side === 0 ? 0 : side === 1 ? along - 0.8 : side === 2 ? 17 : along - 0.8
        width: side % 2 === 0 ? 1.6 : 3
        height: side % 2 === 0 ? 3 : 1.6
        radius: 0.8
        color: Theme.text
      }
    }

    Rectangle {
      x: 3
      y: 3
      width: 14
      height: 14
      radius: 3
      color: "transparent"
      border.width: 1.8
      border.color: Theme.text
    }

    // The core: dim when idle, lit from the bottom as load rises.
    Rectangle {
      id: core

      x: 6.5
      y: 6.5
      width: 7
      height: 7
      radius: 1.5
      color: Theme.highlightHigh
      clip: true

      Rectangle {
        width: parent.width
        height: parent.height * SystemStats.cpu
        y: parent.height - height
        color: Theme.text

        Behavior on height {
          NumberAnimation {
            duration: Theme.duration(Theme.morphState)
            easing.type: Easing.OutCubic
          }
        }
      }
    }
  }

  GaugeLabel {
    anchors.horizontalCenter: parent.horizontalCenter
    y: Theme.islandGaugeLabelY
    visible: Battery.present
    text: (Battery.charging ? "↑ " : "↓ ") + Battery.watts.toFixed(1) + " W"
  }
}
