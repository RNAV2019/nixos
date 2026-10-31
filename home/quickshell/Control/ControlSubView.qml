import QtQuick
import qs.Commons
import qs.Ui

// Base for the control centre's sub-views: the enable/focus wiring, the accessible pane,
// the geometry, the back route and the scrolling body that every view duplicated.
// Rows are dropped into the body via the default property; the header is a Panel's, fed
// through `title` and `headerTrailing`.
Item {
  id: root

  required property IslandSurface surface

  property bool active: false

  property string title: ""
  property string accessibleName: ""

  // View-specific header controls, laid out in the header's trailing slot.
  property alias headerTrailing: panel.headerActions

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

  readonly property int contentHeight: Math.min(Theme.controlViewMaxHeight, Theme.panelHeaderHeight + Math.ceil(body.implicitHeight) + Theme.controlPadBottom)

  default property alias content: body.data

  // A view may swallow the back key first, e.g. to close an open password field.
  function backKeyPressed() {
    root.backed();
  }

  Panel {
    id: panel

    surface: root.surface
    width: root.width
    height: root.height
    title: root.title
    hasBack: true
    onBacked: root.backKeyPressed()

    ScrollView {
      x: root.inset
      y: Theme.panelHeaderHeight
      width: root.span
      height: Math.max(0, root.contentHeight - Theme.panelHeaderHeight - Theme.controlPadBottom)

      Column {
        id: body

        width: root.span
        spacing: Theme.controlRowGap
      }
    }
  }
}
