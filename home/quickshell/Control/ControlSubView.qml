import QtQuick
import qs.Commons
import qs.Ui

// Base for the control centre's sub-views: the enable/focus wiring, the accessible pane,
// the geometry, the Esc/Backspace route and the scrolling body that every view duplicated.
// Rows are dropped into the body via the default property; the header is this component's
// own ViewHeader, fed through `title` and `headerTrailing`.
Item {
  id: root

  property bool active: false

  property string title: ""
  property string accessibleName: ""

  // View-specific header controls, laid out in the header's trailing slot.
  property alias headerTrailing: header.trailing

  enabled: active
  focus: active
  activeFocusOnTab: true

  Accessible.role: Accessible.Pane
  Accessible.name: root.accessibleName
  Accessible.focusable: true
  Accessible.focused: root.activeFocus

  signal backed

  readonly property int inset: Theme.controlInset
  readonly property int span: width - inset * 2

  readonly property int contentHeight: Math.min(Theme.controlViewMaxHeight, Theme.controlHeaderHeight + Math.ceil(body.implicitHeight) + Theme.controlPadBottom)

  default property alias content: body.data

  Keys.onPressed: function (event) {
    if (event.key !== Qt.Key_Escape && event.key !== Qt.Key_Backspace)
      return;
    root.backKeyPressed();
    event.accepted = true;
  }

  // A view may swallow the back key first, e.g. to close an open password field.
  function backKeyPressed() {
    root.backed();
  }

  ViewHeader {
    id: header

    width: parent.width
    title: root.title
    onBacked: root.backed()
  }

  ScrollView {
    x: root.inset
    y: Theme.controlHeaderHeight
    width: root.span
    height: Math.max(0, root.contentHeight - Theme.controlHeaderHeight - Theme.controlPadBottom)

    Column {
      id: body

      width: root.span
      spacing: Theme.controlRowGap
    }
  }
}
