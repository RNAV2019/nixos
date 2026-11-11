import QtQuick
import qs.Commons

// One column of the cheatsheet: its sections under each other on one axis.
Column {
  id: root

  property var sections: []

  // Caps to the left of it, labels and titles to the right: the widest chord in the column
  // plus the gap.
  readonly property real axis: {
    var widest = 0;
    for (var i = 0; i < groups.count; i++) {
      var group = groups.itemAt(i);
      if (group)
        widest = Math.max(widest, group.chordWidth);
    }
    return widest + Theme.keysChordGap;
  }

  spacing: Theme.keysSectionGap

  Repeater {
    id: groups

    model: root.sections

    KeySection {
      required property var modelData

      title: modelData.title
      rows: modelData.rows
      axis: root.axis
    }
  }
}
