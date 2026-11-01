import QtQuick

// A layer an Arrival moves, without disturbing its children's own coordinates.
Item {
  id: layer

  property real shift: 0

  anchors.fill: parent
  transform: Translate {
    x: layer.shift
  }
}
