import QtQuick
import QtQuick.Shapes

// The Bluetooth rune on the Wi-Fi mark's 24 px grid and stroke, so the two read as a pair.
// Connected adds a dot either side; off strikes the rune through.
Item {
  id: root

  property color color
  property bool connected: false
  property bool off: false

  implicitWidth: 24
  implicitHeight: 24

  // A Shape sizes itself to its paths, which leave out the dots; the Item above owns the box.
  Shape {
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeColor: root.color
      strokeWidth: 2.4
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      fillColor: "transparent"
      startX: 7
      startY: 7

      PathLine { x: 17; y: 17 }
      PathLine { x: 12; y: 22 }
      PathLine { x: 12; y: 2 }
      PathLine { x: 17; y: 7 }
      PathLine { x: 7; y: 17 }
    }

    ShapePath {
      strokeColor: root.off ? root.color : "transparent"
      strokeWidth: 2.4
      capStyle: ShapePath.RoundCap
      fillColor: "transparent"
      startX: 3.5
      startY: 3.5

      PathLine { x: 20.5; y: 20.5 }
    }
  }

  Repeater {
    model: root.connected && !root.off ? [3, 21] : []

    Rectangle {
      required property real modelData

      x: modelData - 1.8
      y: 12 - 1.8
      width: 3.6
      height: 3.6
      radius: 1.8
      color: root.color
    }
  }
}
