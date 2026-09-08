import QtQuick
import Quickshell.Widgets
import qs.Commons

// One result. The row draws its icon and its two lines of text; the selected
// background and the accent marker belong to the list's highlight, which
// slides between rows rather than being redrawn on each one.
Item {
  id: root

  property string name: ""
  property string description: ""
  property string iconSource: ""
  property bool hovered: false

  signal activated

  // A row with nothing to say under the name centres it instead of leaving a
  // gap where the description would have been.
  readonly property bool twoLine: description.length > 0

  // Entries without a themed icon fall back to a tinted initial. The hue is
  // picked off the name so a given app keeps the same colour between runs.
  readonly property var tintPalette: [Theme.foam, Theme.gold, Theme.iris, Theme.pine, Theme.rose, Theme.love, Theme.subtle]

  readonly property color tint: {
    var h = 0;
    for (var i = 0; i < name.length; i++)
      h = (h * 31 + name.charCodeAt(i)) % 9973;
    return tintPalette[h % tintPalette.length];
  }

  Rectangle {
    anchors.fill: parent
    radius: Theme.launcherRowRadius
    color: root.hovered ? Theme.withAlpha(Theme.text, Theme.fillHover) : "transparent"

    Behavior on color {
      ColorAnimation {
        duration: Theme.animFast
      }
    }
  }

  Rectangle {
    id: tile

    x: Theme.launcherIconLeft - Theme.launcherInset
    y: (parent.height - height) / 2
    width: Theme.launcherIconSize
    height: width
    radius: Theme.launcherIconRadius
    color: Theme.withAlpha(root.tint, 0.22)
    visible: !icon.visible

    Text {
      anchors.centerIn: parent
      text: root.name.length > 0 ? root.name.charAt(0).toUpperCase() : "?"
      color: root.tint
      font.family: Theme.uiFont
      font.pixelSize: Theme.fontSizeLarge
      font.weight: Font.Bold
    }
  }

  IconImage {
    id: icon

    x: tile.x
    y: tile.y
    width: tile.width
    height: tile.height
    source: root.iconSource
    // An icon name the theme cannot resolve must not leave a hole where the
    // tinted initial would have been.
    visible: source !== "" && backer.status !== Image.Error && backer.status !== Image.Null
  }

  Text {
    id: title

    x: Theme.launcherTextLeft - Theme.launcherInset
    y: root.twoLine ? 5 : (parent.height - height) / 2
    width: parent.width - x - Theme.launcherInset
    text: root.name
    color: Theme.text
    elide: Text.ElideRight
    font.family: Theme.uiFont
    font.pixelSize: Theme.launcherNameSize
    font.weight: Theme.weightSemi
  }

  Text {
    x: title.x
    y: 24
    width: title.width
    text: root.description
    color: Theme.muted
    elide: Text.ElideRight
    visible: root.twoLine
    font.family: Theme.uiFont
    font.pixelSize: Theme.launcherDescSize
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: root.hovered = true
    onExited: root.hovered = false
    onClicked: root.activated()
  }
}
