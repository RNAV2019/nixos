import QtQuick
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// One thing that can be shared: a live capture of it in the carousel's tile, with a plate
// naming it. The capture is a still until the first frame lands, and is taken a few times a
// second rather than continuously, and only while the tile is in the card.
TileBase {
  id: root

  // A screen or a toplevel, null for a window with nothing to capture from.
  property var captureSource: null
  property string name: ""
  property string detail: ""
  // The dot before the name; transparent for none.
  property color dot: "transparent"
  // Whether the tile is inside the card and the card is up: the capture runs on this alone.
  property bool capturing: false
  // Shown when there is nothing to capture, so the tile still says what it is.
  property string fallbackGlyph: ""

  picture: Item {
    anchors.fill: parent
    clip: true

    // Cropped to fill, like every other picture in a tile: the capture is scaled up to
    // cover the box and centred.
    ScreencopyView {
      id: view

      readonly property real cover: sourceSize.width > 0 && sourceSize.height > 0 ? Math.max(parent.width / sourceSize.width, parent.height / sourceSize.height) : 1

      anchors.centerIn: parent
      width: sourceSize.width * cover
      height: sourceSize.height * cover
      captureSource: root.captureSource
      live: false
      visible: hasContent

      Timer {
        interval: Theme.shareCaptureInterval
        running: root.capturing && root.captureSource !== null
        repeat: true
        triggeredOnStart: true
        onTriggered: view.captureFrame()
      }
    }

    StrokeIcon {
      anchors.centerIn: parent
      visible: !view.hasContent && root.fallbackGlyph !== ""
      size: 28
      strokeWidth: 1.75
      path: root.fallbackGlyph
      color: Theme.inkTertiary
    }
  }

  // The plate: opaque, so a frame behind it never costs the name its contrast.
  Rectangle {
    id: plate

    readonly property real room: root.width - Theme.sharePlateInset * 2 - Theme.sharePlatePad * 2 - (root.dot.a > 0 ? Theme.sharePlateDot + Theme.sharePlateGap : 0)
    // The name keeps what the detail leaves, or the larger share of the room when it cannot
    // have both; the detail drops out before the name is cut below a word.
    readonly property real nameWidth: Math.min(nameText.implicitWidth, Math.max(room * 0.6, room - detailText.implicitWidth - Theme.sharePlateGap))
    readonly property real detailWidth: Math.min(detailText.implicitWidth, room - nameWidth - Theme.sharePlateGap)

    x: Theme.sharePlateInset
    y: root.height - Theme.sharePlateInset - height
    width: Theme.sharePlatePad * 2 + (root.dot.a > 0 ? Theme.sharePlateDot + Theme.sharePlateGap : 0) + nameWidth + (detailWidth > 24 ? Theme.sharePlateGap + detailWidth : 0)
    height: Theme.sharePlateHeight
    radius: height / 2
    color: Theme.surface

    Rectangle {
      x: Theme.sharePlatePad
      y: (parent.height - height) / 2
      width: Theme.sharePlateDot
      height: width
      radius: width / 2
      color: root.dot
      visible: root.dot.a > 0
    }

    Text {
      id: nameText

      x: Theme.sharePlatePad + (root.dot.a > 0 ? Theme.sharePlateDot + Theme.sharePlateGap : 0)
      y: (parent.height - height) / 2
      width: plate.nameWidth
      text: root.name
      elide: Text.ElideRight
      color: root.selected ? Theme.inkPrimary : Theme.inkSecondary
      font.family: Theme.uiFont
      font.pixelSize: Theme.sharePlateSize
      font.weight: Theme.weightSemi

      Behavior on color {
        Tint {}
      }
    }

    Text {
      id: detailText

      x: nameText.x + plate.nameWidth + Theme.sharePlateGap
      y: (parent.height - height) / 2
      width: plate.detailWidth
      visible: plate.detailWidth > 24
      text: root.detail
      elide: Text.ElideRight
      color: Theme.inkTertiary
      font.family: Theme.uiFont
      font.pixelSize: Theme.sharePlateSize
    }
  }
}
