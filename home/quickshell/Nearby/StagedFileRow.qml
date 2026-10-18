import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Services
import qs.Ui

// One staged file (board 16e): a 28 px thumb - the picture itself for an image, a tinted glyph
// tile otherwise - the name, the size, and an × that takes it off the list.
Rectangle {
  id: root

  required property string path
  property real bytes: -1

  signal removeClicked

  implicitWidth: Theme.nearbyWidth - Theme.nearbyInset * 2
  implicitHeight: Theme.nearbyFileHeight
  radius: Theme.nearbyFileRadius
  color: Theme.withAlpha(Theme.surfaceSubtle, 0.85)
  border.width: 1
  border.color: Theme.withAlpha(Theme.separator, 0.55)

  readonly property string name: Nearby.baseName(path)
  readonly property string kind: Nearby.fileKind(name)
  readonly property bool picture: Nearby.isPreviewableImage(name)

  Item {
    id: thumb

    x: 8
    y: (root.height - height) / 2
    width: Theme.nearbyFileThumb
    height: Theme.nearbyFileThumb

    Rectangle {
      anchors.fill: parent
      visible: !root.picture || pic.status !== Image.Ready
      radius: Theme.nearbyFileThumbRadius
      color: Theme.surfaceRaised
    }

    StrokeIcon {
      anchors.centerIn: parent
      visible: !root.picture || pic.status !== Image.Ready
      size: Theme.nearbyFileThumbGlyph
      strokeWidth: 1.6
      path: Nearby.glyphFor(root.kind)
      color: Nearby.inkFor(root.kind)
    }

    Image {
      id: pic

      anchors.fill: parent
      visible: root.picture && status === Image.Ready
      source: root.picture ? "file://" + root.path : ""
      sourceSize.width: Theme.nearbyFileThumb * 2
      sourceSize.height: Theme.nearbyFileThumb * 2
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      layer.enabled: visible
      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: thumbMask
      }
    }

    Item {
      id: thumbMask

      anchors.fill: parent
      visible: false
      layer.enabled: true

      Rectangle {
        anchors.fill: parent
        radius: Theme.nearbyFileThumbRadius
        color: "black"
      }
    }
  }

  Text {
    x: Theme.nearbyFileTextLeft
    y: (root.height - height) / 2
    width: sizeText.x - x - 12
    elide: Text.ElideMiddle
    text: root.name
    color: Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: Theme.nearbyRowNameSize
    font.weight: Theme.weightRegular
  }

  Text {
    id: sizeText

    x: root.width - Theme.nearbyFileSizeRight - width
    y: (root.height - height) / 2
    text: root.bytes >= 0 ? Nearby.sizeLabel(root.bytes) : ""
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: Theme.nearbyRowMetaSize
    font.weight: Theme.weightMedium
  }

  StrokeIcon {
    x: root.width - Theme.nearbyFileRemoveRight - size
    y: (root.height - size) / 2
    size: Theme.nearbyFileRemove
    strokeWidth: 1.6
    path: IconPaths.x
    color: removeArea.containsMouse ? Theme.inkPrimary : Theme.inkTertiary

    Behavior on color {
      Tint {}
    }

    MouseArea {
      id: removeArea

      anchors.fill: parent
      anchors.margins: -8
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.removeClicked()
    }
  }

  Accessible.role: Accessible.ListItem
  Accessible.name: root.name
}
