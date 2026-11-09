import QtQuick
import QtQuick.Effects
import qs.Commons

// Content cropped to a rounded box: children land in a layer masked by a rounded rectangle, so
// a picture or a progress fill takes the corner instead of spilling square past it. The layer
// follows this item's geometry; under a fractional scale it is resampled unless it sits on the
// device-pixel grid, so place it as FrostedSurface places its own (see FrostedSurface.snap()).
Item {
  id: root

  property real radius: 0

  // Tells a content-morph scan (Ui/MorphScan.js) that what fills this takes its corners.
  readonly property bool morphRounds: true

  default property alias content: holder.data

  Item {
    id: holder

    anchors.fill: parent
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: mask
    }
  }

  Item {
    id: mask

    anchors.fill: parent
    visible: false
    layer.enabled: true

    Rectangle {
      anchors.fill: parent
      radius: root.radius
      color: "black"
    }
  }
}
