import QtQuick
import qs.Commons
import qs.Ui

// The bar every control-centre view wears: a back button, the view's name, and
// whatever that view needs on the right.
//
// The back button is in the same place on every view, including the root, where
// it closes the panel rather than popping a view. That is deliberate - the
// control centre is one surface that changes contents, so the control that
// takes you out of it should not move.
Item {
  id: root

  property string title: ""

  default property alias trailing: slot.data

  signal backed

  implicitHeight: Theme.controlHeaderHeight

  Rectangle {
    id: back

    x: Theme.controlBackLeft
    y: (parent.height - height) / 2
    width: Theme.controlBackSize
    height: Theme.controlBackSize
    radius: height / 2
    color: Theme.withAlpha(Theme.highlightMed, backHover.containsMouse ? 0.95 : 0.75)
    scale: backHover.pressed ? 0.97 : 1

    Behavior on color {
      Tint {}
    }

    Behavior on scale {
      Morph { duration: Theme.morphState }
    }

    Text {
      anchors.centerIn: parent
      text: Icons.back
      color: Theme.text
      font.family: Theme.iconFont
      font.pixelSize: 16
    }

    MouseArea {
      id: backHover

      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.backed()
    }
  }

  Text {
    x: back.x + back.width + 12
    y: (parent.height - height) / 2
    width: Math.max(0, slot.x - x - 12)
    text: root.title
    color: Theme.text
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlTitleSize
    font.weight: Theme.weightMedium
    elide: Text.ElideRight
  }

  // Laid out right to left, so a view can add a control without measuring the
  // ones already there.
  Row {
    id: slot

    anchors.right: parent.right
    anchors.rightMargin: Theme.controlInset + 5
    anchors.verticalCenter: parent.verticalCenter
    layoutDirection: Qt.RightToLeft
    spacing: 10
  }
}
