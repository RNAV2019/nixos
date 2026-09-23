import QtQuick
import qs.Commons
import qs.Ui

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
    focus: true
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: "Back"
    Accessible.focusable: true
    Accessible.focused: back.activeFocus
    Accessible.onPressAction: root.backed()
    color: Theme.withAlpha(Theme.highlightMed, backHover.containsMouse ? 0.95 : 0.75)
    scale: backHover.pressed ? Theme.pressScale : 1

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
      onPressed: back.forceActiveFocus()
      onClicked: root.backed()
    }

    Keys.onPressed: function (event) {
      if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        root.backed();
        event.accepted = true;
      }
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

  Row {
    id: slot

    anchors.right: parent.right
    anchors.rightMargin: Theme.controlInset + 5
    anchors.verticalCenter: parent.verticalCenter
    layoutDirection: Qt.RightToLeft
    spacing: 10
  }
}
