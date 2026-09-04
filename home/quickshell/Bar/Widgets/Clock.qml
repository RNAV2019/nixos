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

  // Split so the glyphs keep the Nerd Font, the date gets a proportional face
  // and the time stays on a fixed advance.
  Row {
    id: label

    anchors.centerIn: parent
    spacing: Theme.spacingSm

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Icons.calendar
      color: Theme.gold
      font.family: Theme.iconFont
      font.pixelSize: Theme.fontSize
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Qt.formatDateTime(clock.date, "dd MMMM yyyy")
      color: Theme.gold
      font.family: Theme.uiFont
      font.pixelSize: Theme.fontSize
      font.weight: Theme.weightMedium
      rightPadding: Theme.spacingMd
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Icons.clock
      color: Theme.gold
      font.family: Theme.iconFont
      font.pixelSize: Theme.fontSize
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Qt.formatDateTime(clock.date, "HH:mm")
      color: Theme.gold
      font.family: Theme.monoFont
      font.pixelSize: Theme.fontSize
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()
  }
}
