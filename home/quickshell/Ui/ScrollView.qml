import QtQuick
import qs.Commons

Item {
  id: root

  default property alias content: body.data

  // Disable only the Flickable; disabling this Item would kill nested input.
  property bool scrollable: true

  readonly property alias contentHeight: body.implicitHeight
  readonly property alias scrolling: view.interactive

  Flickable {
    id: view

    anchors.fill: parent
    contentWidth: width
    contentHeight: body.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    interactive: root.scrollable && contentHeight > height

    // Qt's default wheel delta is too small here.
    WheelHandler {
      enabled: view.interactive
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: function (event) {
        var step = Theme.panelRowHeight * 3;
        var target = view.contentY - (event.angleDelta.y / 120) * step;
        scrollTo.to = Math.max(0, Math.min(view.contentHeight - view.height, target));
        scrollTo.restart();
      }
    }

    NumberAnimation {
      id: scrollTo
      target: view
      property: "contentY"
      duration: Theme.morphState
      easing.type: Easing.OutCubic
    }

    Item {
      id: body

      width: view.width
      implicitHeight: childrenRect.height
      // Avoids a circular height dependency.
      height: root.scrollable ? implicitHeight : view.height
    }
  }

  Rectangle {
    anchors.right: parent.right
    width: 3
    radius: width / 2
    color: Theme.withAlpha(Theme.text, Theme.fillSelected)
    visible: view.interactive
    y: view.visibleArea.yPosition * root.height
    height: Math.max(20, view.visibleArea.heightRatio * root.height)

    Behavior on y {
      NumberAnimation {
        duration: Theme.duration(Theme.morphState)
        easing.type: Easing.OutCubic
      }
    }

    Behavior on height {
      NumberAnimation {
        duration: Theme.duration(Theme.morphState)
        easing.type: Easing.OutCubic
      }
    }
  }
}
