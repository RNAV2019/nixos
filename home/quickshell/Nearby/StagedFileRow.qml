import QtQuick
import qs.Commons
import qs.Services
import qs.Ui

// One staged file (board 16e): a 28 px thumb - the picture itself for an image, a tinted glyph
// tile otherwise - the name, the size, and an × that takes it off the list.
ListRow {
  id: root

  required property string path
  property real bytes: -1

  signal removeClicked

  readonly property string name: Nearby.baseName(path)
  readonly property string fileKind: Nearby.fileKind(name)
  readonly property bool picture: Nearby.isPreviewableImage(name)

  kind: ListRow.Hairline
  interactive: false
  accessibleRole: Accessible.ListItem
  implicitWidth: Theme.nearbyWidth - Theme.nearbyInset * 2
  implicitHeight: Theme.nearbyFileHeight
  label: name
  elide: Text.ElideMiddle
  textLeft: Theme.nearbyFileTextLeft
  value: root.bytes >= 0 ? Nearby.sizeLabel(root.bytes) : ""
  valueColor: Theme.inkSecondary
  valueSize: Theme.nearbyRowMetaSize
  valueGap: 12
  trailInset: Theme.nearbyFileRemoveRight

  trailing: Button {
    kind: Button.Icon
    iconSize: Theme.nearbyFileRemove
    iconStroke: 1.6
    icon: IconPaths.x
    baseColor: Theme.inkTertiary
    hoverColor: Theme.inkPrimary
    accessibleName: "Remove " + root.name

    onClicked: root.removeClicked()
  }

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
      path: Nearby.glyphFor(root.fileKind)
      color: Nearby.inkFor(root.fileKind)
    }

    RoundedClip {
      anchors.fill: parent
      visible: root.picture && pic.status === Image.Ready
      radius: Theme.nearbyFileThumbRadius

      Image {
        id: pic

        anchors.fill: parent
        source: root.picture ? "file://" + root.path : ""
        sourceSize.width: Theme.nearbyFileThumb * 2
        sourceSize.height: Theme.nearbyFileThumb * 2
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
      }
    }
  }
}
