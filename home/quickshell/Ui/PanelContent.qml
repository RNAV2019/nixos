import QtQuick
import qs.Commons

Item {
  id: root

  property string panelName: ""
  property Item anchorTarget: null
  property bool active: false

  property int preferredWidth: Theme.panelWidthNarrow
  property int maxHeight: Theme.panelMaxHeight
  // Raised while an inline editor holds focus, so typing does not also drive
  // keyboard navigation. See Ui/PanelKeyCatcher.qml.
  property bool editing: false

  // Disable outer scrolling when a nested list scrolls below a fixed header.
  property bool scrollable: true
  // An explicit body height avoids circular sizing against availableHeight.
  property int bodyHeight: -1

  // The host replaces this 800px fallback with the available screen height.
  property int screenLimit: 800
  readonly property int availableHeight: Math.min(maxHeight, screenLimit)

  readonly property int preferredHeight: bodyHeight >= 0 ? bodyHeight + Theme.panelPadding * 2 : Math.min(scrollView.contentHeight + Theme.panelPadding * 2, availableHeight)

  signal dismissed

  function close() {
    dismissed();
  }

  default property alias content: scrollView.content

  anchors.fill: parent

  opacity: active ? 1 : 0
  visible: opacity > 0

  Behavior on opacity {
    NumberAnimation {
      duration: Theme.animFast
      easing.type: Easing.InOutQuad
    }
  }

  ScrollView {
    id: scrollView

    anchors.fill: parent
    anchors.margins: Theme.panelPadding
    scrollable: root.scrollable
  }
}
