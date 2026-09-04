import QtQuick
import qs.Commons

Rectangle {
  id: root

  signal activated

  // See IconWidget.triggerPress.
  function triggerPress(button) {
    root.activated();
  }

  implicitWidth: Theme.barNixMinWidth + Theme.barNixPadding * 2
  implicitHeight: Theme.barHeight
  radius: height / 2
  color: Theme.base

  Text {
    anchors.centerIn: parent
    text: Icons.nix
    color: Theme.love
    font.family: Theme.iconFont
    font.pixelSize: Theme.barNixFontSize
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()
  }
}
