import QtQuick
import Quickshell
import qs.Commons

Rectangle {
  id: root

  signal activated
  property alias containsMouse: mouse.containsMouse

  // See IconWidget.triggerPress.
  function triggerPress(button) {
    root.activated();
  }

  implicitWidth: label.implicitWidth + Theme.barPillPaddingWide * 2
  implicitHeight: Theme.barHeight
  radius: height / 2
  color: Theme.base

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Text {
    id: label
    anchors.centerIn: parent
    color: Theme.gold
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    text: Icons.calendar + " " + Qt.formatDateTime(clock.date, "dd MMMM yyyy") + "  " + Icons.clock + " " + Qt.formatDateTime(clock.date, "HH:mm")
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()
  }
}
