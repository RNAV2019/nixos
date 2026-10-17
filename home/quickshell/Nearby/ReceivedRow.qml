import QtQuick
import qs.Commons
import qs.Ui

// One arrival under "Received" (boards 16c, 16d): the file's glyph, its name and where it
// landed. The newest row enters with an accent edge that fades away after four seconds;
// a click opens the file.
Rectangle {
  id: root

  // The transfer row from the daemon (direction "in", state "finished").
  required property var transfer
  // True while the row wears its arrival edge.
  property bool fresh: false

  signal clicked

  implicitWidth: Theme.nearbyWidth - Theme.nearbyInset * 2
  implicitHeight: Theme.nearbyRowHeight
  radius: Theme.nearbyRowRadius
  color: Theme.withAlpha(Theme.surfaceSubtle, 0.85)
  border.width: 1
  border.color: Theme.withAlpha(Theme.separator, 0.55)

  readonly property string name: {
    var paths = transfer && transfer.saved_paths ? transfer.saved_paths : [];
    if (paths.length > 0)
      return paths[0].split("/").pop();
    var files = transfer && transfer.files ? transfer.files : [];
    return files.length > 0 ? files[0].split("/").pop() : "file";
  }

  readonly property string path: {
    var paths = transfer && transfer.saved_paths ? transfer.saved_paths : [];
    return paths.length > 0 ? paths[0] : "";
  }

  readonly property string sizeLabel: {
    if (!transfer || !transfer.total_bytes)
      return "";
    var b = transfer.total_bytes;
    if (b < 1024)
      return b + " B";
    if (b < 1024 * 1024)
      return (b / 1024).toFixed(1) + " KB";
    return (b / (1024 * 1024)).toFixed(1) + " MB";
  }

  readonly property string icon: {
    var n = name.toLowerCase();
    var ext = n.split(".").pop();
    if (["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "avif", "heic"].indexOf(ext) !== -1)
      return IconPaths.image;
    if (["zip", "tar", "gz", "xz", "7z", "rar", "bz2", "zst"].indexOf(ext) !== -1)
      return IconPaths.fileArchive;
    return IconPaths.fileText;
  }

  // The arrival edge, on the row's left; gone after four seconds.
  Rectangle {
    visible: root.fresh
    x: 0
    y: 4
    width: 3
    height: parent.height - 8
    radius: width / 2
    color: Theme.accentFill
    opacity: 0.9

    Behavior on opacity {
      Morph {
        duration: Theme.morphSurface
      }
    }
  }

  function startFade() {
    if (fresh)
      fadeEdge.restart();
  }

  onFreshChanged: startFade()
  Component.onCompleted: startFade()

  Timer {
    id: fadeEdge

    interval: Theme.nearbyArrivalGlow
    onTriggered: root.fresh = false
  }

  StrokeIcon {
    x: Theme.nearbyRowInset + 2
    y: (root.height - Theme.nearbyRowGlyph) / 2
    size: Theme.nearbyRowGlyph
    strokeWidth: 1.75
    path: root.icon
    color: Theme.accentFill
  }

  Text {
    x: Theme.nearbyRowTextLeft
    y: (root.height - 15) / 2
    width: root.width - Theme.nearbyRowTextLeft - Theme.nearbyRowInset - 80
    elide: Text.ElideRight
    text: root.name
    color: Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: Theme.nearbyRowNameSize
    font.weight: Theme.weightRegular
  }

  Text {
    x: root.width - Theme.nearbyRowInset - width
    y: (root.height - 15) / 2
    text: root.sizeLabel
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: Theme.nearbyRowMetaSize
    font.weight: Theme.weightMedium
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }

  Accessible.role: Accessible.Button
  Accessible.name: root.name
  Accessible.onPressAction: root.clicked()
}
