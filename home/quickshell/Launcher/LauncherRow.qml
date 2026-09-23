import QtQuick
import qs.Commons

Item {
  id: root

  property string name: ""
  property string description: ""
  property string iconSource: ""

  signal activated

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: root.name
  Accessible.description: root.description
  Accessible.focusable: true
  Accessible.focused: root.activeFocus
  Accessible.onPressAction: root.activated()

  readonly property bool twoLine: description.length > 0

  // No themed icon: fall back to an initial, tinted off the name so it stays stable.
  readonly property var tintPalette: [Theme.foam, Theme.gold, Theme.iris, Theme.pine, Theme.rose, Theme.love, Theme.subtle]

  readonly property color tint: {
    var h = 0;
    for (var i = 0; i < name.length; i++)
      h = (h * 31 + name.charCodeAt(i)) % 9973;
    return tintPalette[h % tintPalette.length];
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

  // Ask for a size no theme keeps, so it returns its largest variant and downsamples
  // cleanly. Loaded synchronously: async shows a blank frame.
  Image {
    id: icon

    x: tile.x
    y: tile.y
    width: tile.width
    height: tile.height
    source: root.iconSource
    sourceSize.width: Theme.launcherIconSize * 4
    sourceSize.height: Theme.launcherIconSize * 4
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
    visible: source !== "" && status === Image.Ready
  }

  Text {
    id: title

    x: Theme.launcherTextLeft - Theme.launcherInset
    y: root.twoLine ? 5 : (parent.height - height) / 2
    width: parent.width - x - Theme.launcherInset
    text: root.name
    color: Theme.inkPrimary
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
    color: Theme.inkTertiary
    elide: Text.ElideRight
    visible: root.twoLine
    font.family: Theme.uiFont
    font.pixelSize: Theme.launcherDescSize
  }

  // A click still launches, but hover never moves the selection: the cursor is hidden.
  MouseArea {
    anchors.fill: parent
    activeFocusOnTab: true
    onPressed: root.forceActiveFocus()
    onClicked: root.activated()
  }

  Keys.onPressed: function (event) {
    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.activated();
      event.accepted = true;
    }
  }
}
