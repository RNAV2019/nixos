import QtQuick
import qs.Commons

// A titled group of lines. The title stands on the labels' edge, with the caps hanging to its
// left.
Column {
  id: root

  property string title: ""
  property var rows: []
  property real axis: 0

  // The widest chord here, for the column to set one axis for all its sections.
  readonly property real chordWidth: {
    var widest = 0;
    for (var i = 0; i < lines.count; i++) {
      var line = lines.itemAt(i);
      if (line)
        widest = Math.max(widest, line.chordWidth);
    }
    return widest;
  }

  Item {
    implicitWidth: root.axis + Math.ceil(heading.implicitWidth)
    implicitHeight: Theme.keysTitleHeight

    Text {
      id: heading

      x: root.axis
      text: root.title
      color: Theme.inkTertiary
      font.family: Theme.uiFont
      font.pixelSize: Theme.sectionSize
      font.weight: Theme.weightMedium
    }
  }

  Repeater {
    id: lines

    model: root.rows

    KeyRow {
      required property var modelData

      caps: modelData.caps
      label: modelData.label
      axis: root.axis
    }
  }
}
