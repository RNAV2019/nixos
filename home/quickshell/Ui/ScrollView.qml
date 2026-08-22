import QtQuick
import qs.Commons

// body provides a stable parent for measuring caller-provided content.
Item {
  id: root

  default property alias content: body.data

  // Disable only the Flickable; disabling this Item would disable nested input.
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

    // Advance three rows per wheel notch; Qt's default delta is too small here.
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
      duration: Theme.animFast
      easing.type: Easing.OutCubic
    }

    Item {
      id: body

      width: view.width
      implicitHeight: childrenRect.height
      // Fill static views without creating a circular height dependency.
      height: root.scrollable ? implicitHeight : view.height
    }
  }

  // A sibling of the Flickable, so it stays put instead of scrolling away.
  Rectangle {
    anchors.right: parent.right
    width: 3
    radius: width / 2
    color: Theme.withAlpha(Theme.text, Theme.fillSelected)
    visible: view.interactive
    y: view.visibleArea.yPosition * root.height
    height: Math.max(20, view.visibleArea.heightRatio * root.height)
  }
}
