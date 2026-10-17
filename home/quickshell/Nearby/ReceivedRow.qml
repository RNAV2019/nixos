import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui

// One arrival under "Received" (boards 16c, 16d): the file's glyph, its name and where it
// landed, with the transfer's progress as the row's own background. The newest row enters
// with an accent edge that fades away after four seconds; a click opens the file.
Rectangle {
  id: root

  // The transfer row from the daemon (direction "in", state "in_progress" or "finished").
  required property var transfer
  // True while the row wears its arrival edge.
  property bool fresh: false
  // 0..1, drawn as the row's background fill.
  property real progress: 1
  // Rows stacked as one group round only the group's outer corners: "first", "middle",
  // "last", "only" for a group of one, or "single" for a row on its own (the default, a full pill).
  property string groupPosition: "single"

  signal clicked
  // The cursor over the row, in the row's own coordinates, so the panel can float a preview.
  signal hoverMoved(real localX, real localY)
  signal hoverExited

  implicitWidth: Theme.nearbyWidth - Theme.nearbyInset * 2
  implicitHeight: Theme.nearbyRowHeight
  radius: Theme.nearbyRowRadius
  color: "transparent"
  topLeftRadius: groupPosition === "single" || groupPosition === "first" || groupPosition === "only" ? radius : 0
  topRightRadius: topLeftRadius
  bottomLeftRadius: groupPosition === "single" || groupPosition === "last" || groupPosition === "only" ? radius : 0
  bottomRightRadius: bottomLeftRadius
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

  readonly property string ext: name.toLowerCase().split(".").pop()
  readonly property bool isImage: ["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "avif", "heic"].indexOf(ext) !== -1

  readonly property string icon: {
    if (isImage)
      return IconPaths.image;
    if (["zip", "tar", "gz", "xz", "7z", "rar", "bz2", "zst"].indexOf(ext) !== -1)
      return IconPaths.fileArchive;
    return IconPaths.fileText;
  }

  // The ground and the progress fill share one rounded mask, so the fill takes the row's
  // corner rather than spilling square past it (the same trick FrostedSurface uses).
  Item {
    id: bg

    anchors.fill: parent
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: bgMask
    }

    Rectangle {
      anchors.fill: parent
      color: Theme.withAlpha(Theme.surfaceSubtle, 0.85)
    }

    Rectangle {
      width: parent.width * Theme.clamp01(root.progress)
      height: parent.height
      color: Theme.withAlpha(Theme.accentFill, 0.18)

      Behavior on width {
        enabled: !Theme.reduceMotion

        NumberAnimation {
          duration: 250
          easing.type: Easing.OutCubic
        }
      }
    }
  }

  Item {
    id: bgMask

    anchors.fill: parent
    visible: false
    layer.enabled: true

    Rectangle {
      anchors.fill: parent
      topLeftRadius: root.topLeftRadius
      topRightRadius: root.topRightRadius
      bottomLeftRadius: root.bottomLeftRadius
      bottomRightRadius: root.bottomRightRadius
      color: "black"
    }
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
    id: hoverArea

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
    onPositionChanged: root.hoverMoved(hoverArea.mouseX, hoverArea.mouseY)
    onContainsMouseChanged: {
      if (containsMouse)
        root.hoverMoved(hoverArea.mouseX, hoverArea.mouseY);
      else
        root.hoverExited();
    }
  }

  Accessible.role: Accessible.Button
  Accessible.name: root.name
  Accessible.onPressAction: root.clicked()
}
