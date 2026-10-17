import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui

// A floating image preview that trails the cursor while an image row in the Nearby
// "Received" list is hovered. It is meant to be a sibling of the panel card, not a child,
// so the card's clip never trims it; the caller maps the cursor into the panel coordinates.
// It never handles input, only draws.
Item {
  id: root

  // While true the card fades in and chases the anchor; false fades it out and holds.
  property bool active: false
  // A local absolute path or a file:// URL.
  property string source: ""
  // The cursor, already mapped into this item's parent coordinates by the caller.
  property real anchorX: 0
  property real anchorY: 0
  property real maxWidth: 320
  property real maxHeight: 320
  // The offset from the cursor, so the card sits down and to the right of it.
  property real marginX: 16
  property real marginY: 16

  // Above the panel card, which is a sibling.
  z: 1000

  // The image's own size decides the card, capped but never upscaled. Until it loads we still
  // show the rounded ground at a thumb's size, so a hover does not flash nothing.
  readonly property bool ready: preview.status === Image.Ready && source !== ""
  readonly property real naturalW: preview.implicitWidth
  readonly property real naturalH: preview.implicitHeight
  readonly property real fit: ready && naturalW > 0 && naturalH > 0 ? Math.min(1, maxWidth / naturalW, maxHeight / naturalH) : 1
  readonly property real cardW: ready ? naturalW * fit : Theme.nearbyThumbSize
  readonly property real cardH: ready ? naturalH * fit : Theme.nearbyThumbSize

  width: cardW
  height: cardH

  // A spring chase of the anchor rather than a direct bind: retargeting keeps velocity, so the
  // card trails the cursor and overshoots slightly. Clamp the target, never x itself, or the
  // Behavior would be fought every frame; the settled size is the clamp's own reference.
  readonly property real targetX: parent ? Math.max(0, Math.min(parent.width - cardW, anchorX + marginX)) : anchorX + marginX
  readonly property real targetY: parent ? Math.max(0, Math.min(parent.height - cardH, anchorY + marginY)) : anchorY + marginY

  x: targetX
  y: targetY

  // Frozen while fading out, so a left row stops being hunted; SurfaceSpring already snaps
  // rather than overshoots under Theme.reduceMotion.
  Behavior on x {
    enabled: root.active
    SurfaceSpring {}
  }

  Behavior on y {
    enabled: root.active
    SurfaceSpring {}
  }

  // An empty source is simply invisible; Morph's duration collapses under reduceMotion.
  visible: opacity > 0
  opacity: active && source !== "" ? 1 : 0

  Behavior on opacity {
    Morph {}
  }

  // Ground and image share one rounded mask rather than a clip, so the fill, the image and the
  // border all take the panel row's corner. MultiEffect is used the same way as Ui/AlbumArt.
  Item {
    id: content

    anchors.fill: parent
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: mask
    }

    Rectangle {
      anchors.fill: parent
      color: Theme.withAlpha(Theme.surfaceRaised, 0.98)
    }

    // Crop: the card is already sized to the source's aspect, so crop and fit agree, and crop
    // leaves no hairline of ground showing at an edge from rounding.
    Image {
      id: preview

      anchors.fill: parent
      source: root.source
      asynchronous: true
      cache: true
      fillMode: Image.PreserveAspectCrop
      visible: root.ready
    }
  }

  Item {
    id: mask

    anchors.fill: parent
    visible: false
    layer.enabled: true

    Rectangle {
      anchors.fill: parent
      radius: Theme.nearbyRowRadius
      color: "black"
    }
  }

  // The edge rides on top of the masked content, like FrostedSurface's outline, so the mask
  // never cuts it; a transparent fill keeps it from covering the image.
  Rectangle {
    anchors.fill: parent
    radius: Theme.nearbyRowRadius
    color: "transparent"
    border.width: 1
    border.color: Theme.withAlpha(Theme.separator, 0.6)
  }
}
