import QtQuick
import qs.Commons

Rectangle {
  id: root

  property bool selected: false
  property bool enabled: true
  property alias hovered: hover.hovered

  signal clicked
  signal secondaryClicked

  default property alias content: layout.data

  implicitHeight: Theme.panelRowHeight
  radius: Theme.panelRowRadius
  color: Theme.rowFill(hover.hovered && root.enabled, root.selected)
  opacity: root.enabled ? 1 : 0.4

  Behavior on color {
    ColorAnimation {
      duration: Theme.animFast
    }
  }

  HoverHandler {
    id: hover
    enabled: root.enabled
    cursorShape: Qt.PointingHandCursor
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.enabled
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function (event) {
      if (event.button === Qt.RightButton)
        root.secondaryClicked();
      else
        root.clicked();
    }

    // Let wheel events propagate to the panel's Flickable.
    onWheel: function (wheel) {
      wheel.accepted = false;
    }
  }

  Item {
    id: layout
    anchors.fill: parent
    anchors.leftMargin: Theme.panelRowInset
    anchors.rightMargin: Theme.panelRowInset
  }
}
