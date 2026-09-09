import QtQuick
import qs.Commons

// One result. The row draws its icon and its two lines of text; the selected
// background and the accent marker belong to the list's highlight, which
// slides between rows rather than being redrawn on each one.
Item {
  id: root

  property string name: ""
  property string description: ""
  property string iconSource: ""

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

  // Ui uses IconImage elsewhere, but it asks the icon theme for exactly the
  // size it is drawn at. A theme that has no 26 px variant then hands back its
  // 16 or 22 px one to be scaled up, and the result is visibly soft. Asking
  // for a size no theme keeps forces the largest variant it has, which
  // downsamples cleanly instead.
  //
  // Loading is synchronous because these are small local files and the
  // alternative is every row showing its tinted initial for a frame before the
  // real icon replaces it, on every open.
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
    // An icon name the theme cannot place must not leave a hole where the
    // tinted initial would have been.
    visible: source !== "" && status === Image.Ready
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

  // A click still launches, for the one case where the pointer is already on a
  // row when the launcher opens. It does not track the pointer otherwise: the
  // cursor is hidden while the launcher is up, and a hidden pointer that moves
  // the selection out from under the arrow keys is worse than one that does
  // nothing at all. Which row is selected is the list's highlight to say.
  MouseArea {
    anchors.fill: parent
    onClicked: root.activated()
  }
}
