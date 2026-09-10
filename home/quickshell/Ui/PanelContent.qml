import QtQuick
import qs.Commons
import qs.Ui

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

  // Content swaps ride the short clock, not the shape's: measured off the
  // source recording, a surface changes shape over ~300 ms while the contents
  // it carries change over about five frames. A 150 ms InOutQuad read as a
  // dissolve layered on top of the geometry's own reveal.
  Behavior on opacity {
    Morph {
      duration: Theme.morphContent
    }
  }

  ScrollView {
    id: scrollView

    anchors.fill: parent
    anchors.margins: Theme.panelPadding
    scrollable: root.scrollable
  }
}
