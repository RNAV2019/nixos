import QtQuick
import QtQuick.Shapes
import Quickshell.Services.UPower
import qs.Commons
import qs.Services

// Board 02's system gauge, beside the battery one: memory on the ring, CPU load in the chip
// at its centre, and the power draw in the gap, rising while charging and falling on battery.
Item {
  id: root

  readonly property var battery: UPower.displayDevice
  readonly property bool present: battery !== null && battery.isLaptopBattery && battery.isPresent
  readonly property bool charging: present && battery.state === UPowerDeviceState.Charging

  // UPower's energy rate is the battery's own flow: the whole system's draw while on
  // battery, what goes into the cell while charging.
  readonly property real watts: present ? Math.abs(battery.changeRate) : 0

  implicitWidth: 48
  implicitHeight: 52

  Shape {
    width: 48
    height: 48
    preferredRendererType: Shape.CurveRenderer

    GaugeArc {
      radius: 21
      strokeColor: Theme.highlightMed
    }

    GaugeArc {
      radius: 21
      value: SystemStats.memory
      strokeColor: Theme.rose
    }
  }

  // A CPU chip whose core fills from the bottom with load, as the Wi-Fi bars light with
  // signal on the battery gauge.
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
    visible: root.present
    text: (root.charging ? "↑ " : "↓ ") + root.watts.toFixed(1) + " W"
  }
}
