import QtQuick
import Quickshell
import qs.Commons

PopupWindow {
  id: root

  required property Item anchorItem
  property string text: ""
  property bool show: false

  // Crossing the bar should not strobe every tooltip on the way past, so a
  // hover has to settle before the bubble appears. Leaving clears instantly.
  readonly property int showDelay: 400

  property bool settled: false

  readonly property bool wanted: settled && show && text.length > 0

  onShowChanged: {
    if (show)
      settle.restart();
    else {
      settle.stop();
      settled = false;
    }
  }

  Timer {
    id: settle
    interval: root.showDelay
    onTriggered: root.settled = true
  }

  // Keep the window mapped until fade-out completes.
  visible: wanted || bubble.opacity > 0
  color: "transparent"

  implicitWidth: label.implicitWidth + 28
  implicitHeight: label.implicitHeight + 20

  anchor {
    item: root.anchorItem
    edges: Edges.Bottom
    gravity: Edges.Bottom
    margins.top: Theme.gapsOut
    adjustment: PopupAdjustment.Slide
  }

  Rectangle {
    id: bubble

    anchors.fill: parent
    radius: Theme.panelRowRadius
    color: Theme.base
    border.width: 1
    border.color: Theme.overlay

    opacity: root.wanted ? 1 : 0

    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animFast
        easing.type: Easing.OutCubic
      }
    }

    Text {
      id: label
      anchors.centerIn: parent
      text: root.text
      color: Theme.text
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSizeLarge
      textFormat: Text.PlainText
    }
  }
}
