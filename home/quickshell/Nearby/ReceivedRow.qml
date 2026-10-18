import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Services
import qs.Ui

// One arrival under "Received" (boards 16g, 16h): the file's glyph, its name and its size, with
// the download's progress drawn as the row's own background. A row that has just landed wears
// the accent ground and edge for a few seconds; a finished row opens its file on click.
Item {
  id: root

  // The transfer row from the daemon (direction "in", state "in_progress" or "finished").
  required property var transfer
  // True while the row wears its arrival accent.
  property bool fresh: false
  // 0..1, drawn as the row's background fill.
  property real progress: 1

  signal clicked
  // The cursor over the row, in the row's own coordinates, so the panel can float a preview.
  signal hoverMoved(real localX, real localY)
  signal hoverExited

  implicitWidth: Theme.nearbyWidth - Theme.nearbyInset * 2
  implicitHeight: Theme.nearbyRowHeight

  readonly property bool done: transfer && transfer.state === "finished"
  readonly property string name: Nearby.transferName(transfer)
  readonly property string path: {
    var paths = transfer && transfer.saved_paths ? transfer.saved_paths : [];
    return paths.length > 0 ? String(paths[0]) : "";
  }
  readonly property string kind: Nearby.fileKind(name)
  readonly property bool isImage: Nearby.isPreviewableImage(name)
  readonly property bool hovered: hoverArea.containsMouse

  readonly property string sizeLabel: {
    if (!transfer || !transfer.total_bytes)
      return "";
    if (!done)
      return Math.round(Theme.clamp01(progress) * 100) + "%";
    return Nearby.sizeLabel(transfer.total_bytes);
  }

  // The ground and the progress fill share one rounded mask, so the fill takes the row's corner
  // rather than spilling square past it.
  Item {
    anchors.fill: parent
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: bgMask
    }

    Rectangle {
      anchors.fill: parent
      color: root.fresh ? Theme.withAlpha(Theme.accentFill, 0.1) : root.hovered && root.done ? Theme.withAlpha(Theme.surfaceRaised, 0.9) : Theme.withAlpha(Theme.surfaceSubtle, 0.85)

      Behavior on color {
        Tint {}
      }
    }

    Rectangle {
      visible: !root.done
      width: parent.width * Theme.clamp01(root.progress)
      height: parent.height
      color: Theme.withAlpha(Theme.accentFill, 0.16)

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
      radius: Theme.nearbyRowRadius
      color: "black"
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: Theme.nearbyRowRadius
    color: "transparent"
    border.width: 1
    border.color: root.fresh ? Theme.withAlpha(Theme.accentFill, 0.45) : Theme.withAlpha(Theme.separator, 0.55)

    Behavior on border.color {
      Tint {}
    }
  }

  StrokeIcon {
    x: 15
    y: (root.height - size) / 2
    size: Theme.nearbyRowGlyph
    strokeWidth: 1.75
    path: Nearby.glyphFor(root.kind)
    color: Theme.accentFill
  }

  Text {
    x: Theme.nearbyRowTextLeft
    y: (root.height - height) / 2
    width: meta.x - x - 12
    elide: Text.ElideMiddle
    text: root.name
    color: Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: Theme.nearbyRowNameSize
    font.weight: Theme.weightRegular
  }

  Text {
    id: meta

    x: root.width - Theme.nearbyRowInset - width
    y: (root.height - height) / 2
    text: root.sizeLabel
    color: root.done ? Theme.inkSecondary : Theme.accentFill
    font.family: Theme.uiFont
    font.pixelSize: Theme.nearbyRowMetaSize
    font.weight: Theme.weightMedium
  }

  MouseArea {
    id: hoverArea

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.done ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: if (root.done)
      root.clicked()
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
  Accessible.onPressAction: if (root.done)
    root.clicked()
}
