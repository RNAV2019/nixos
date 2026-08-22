import QtQuick
import qs.Commons

Item {
  id: root

  property real value: 0
  property bool enabled: true
  // Emitted on press and continuously while dragging.
  signal moved(real value)

  readonly property int trackHeight: 6
  readonly property int handleSize: 12

  implicitHeight: handleSize + Theme.spacingSm

  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: root.trackHeight
    radius: height / 2
    color: Theme.overlay
    opacity: root.enabled ? 1 : 0.4

    Rectangle {
      width: Math.max(0, Math.min(1, root.value)) * parent.width
      height: parent.height
      radius: parent.radius
      color: Theme.accent
    }
  }

  Rectangle {
    id: handle
    width: root.handleSize
    height: root.handleSize
    radius: width / 2
    color: Theme.text
    visible: root.enabled
    anchors.verticalCenter: parent.verticalCenter
    x: Math.max(0, Math.min(1, root.value)) * (root.width - width)
  }

  MouseArea {
    // Expand the hit area without increasing the layout height.
    readonly property int grab: root.handleSize / 2

    anchors.fill: parent
    anchors.margins: -grab
    enabled: root.enabled
    preventStealing: true

    function apply(mx) {
      var v = (mx + grab - handle.width / 2) / (root.width - handle.width);
      root.moved(Math.max(0, Math.min(1, v)));
    }

    onPressed: function (mouse) {
      apply(mouse.x);
    }
    onPositionChanged: function (mouse) {
      if (pressed)
        apply(mouse.x);
    }

    // Scrolling over a slider should scroll the panel, not fight it.
    onWheel: function (wheel) {
      wheel.accepted = false;
    }
  }
}
