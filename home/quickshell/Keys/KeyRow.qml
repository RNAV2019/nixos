import QtQuick
import qs.Commons

// One line of the cheatsheet: the keys to press, then what they do. The caps end at `axis`, so
// down a column the last key of every chord sits beside its label and the labels share an edge.
Item {
  id: root

  property var caps: []
  property string label: ""
  // Where the labels start, which the column sets from its widest chord.
  property real axis: chordWidth + Theme.keysChordGap

  readonly property real chordWidth: chord.implicitWidth

  implicitWidth: axis + Math.ceil(text.implicitWidth)
  implicitHeight: Theme.keysRowHeight

  Row {
    id: chord

    x: root.axis - Theme.keysChordGap - width
    anchors.verticalCenter: parent.verticalCenter
    spacing: Theme.keycapGap

    Repeater {
      model: root.caps

      Keycap {
        required property string modelData

        text: modelData
      }
    }
  }

  Text {
    id: text

    x: root.axis
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    color: Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: Theme.keysLabelSize
  }
}
