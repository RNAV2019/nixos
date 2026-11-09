import QtQuick
import qs.Commons

// What every pressable control shares: hover and press tracking, the press scale, the dimmed
// disabled state, Space/Enter, an accessible name and a ring while the keyboard has focus.
// Button, Switch and the cells of a Segmented draw their own ground and content on top.
Item {
  id: root

  // A content-morph anchor (Ui/MorphScan.js): what it is, and what pairs it across panels.
  property string morphRole: "button"
  property string morphKey: ""
  property var morphSlot: undefined

  property string accessibleName: ""
  property int accessibleRole: Accessible.Button
  // False for a control that only reports: it still tracks the pointer, but takes no click, no
  // press, no key and no tab stop, and shows the arrow.
  property bool interactive: true
  property bool checkable: false
  property bool checked: false

  // Extra invisible margin around the control, beyond its drawn size.
  property real hitSlop: 0
  // Radius of the keyboard ring; the control's own corner by default.
  property real ringRadius: height / 2
  property real ringInset: 0

  // Reveal-under-pointer rows set this: the control stays laid out and tracks its own hover;
  // it cannot use `visible`, or the hover returns to the row and flickers.
  property bool revealed: true

  signal clicked
  signal doubleClicked

  readonly property bool hovered: area.containsMouse && root.enabled
  readonly property bool pressed: area.pressed
  // Focus that arrived by Tab, not by a click: only that one draws the ring.
  readonly property bool keyFocused: root.activeFocus && !root.pointerFocused
  property bool pointerFocused: false

  function activate() {
    if (root.enabled && root.revealed && root.interactive)
      root.clicked();
  }

  // A tile that starts sending while it holds the keys keeps them until they move on.
  activeFocusOnTab: root.interactive || root.activeFocus
  Accessible.role: root.accessibleRole
  Accessible.name: root.accessibleName
  Accessible.checkable: root.checkable
  Accessible.checked: root.checked
  Accessible.focusable: true
  Accessible.focused: root.activeFocus
  Accessible.onPressAction: root.activate()

  opacity: !root.revealed ? 0 : root.enabled ? 1 : Theme.disabledAlpha
  // Dimmed with a layer, not bare opacity: glyphs that are filled and stroked in one colour
  // composite twice where they overlap at half opacity, a bright ring around each glyph.
  // Rasterising first makes the dim even.
  layer.enabled: opacity > 0 && opacity < 1
  scale: root.pressed ? Theme.pressScale : 1

  Behavior on opacity {
    Morph {
      duration: Theme.morphState
    }
  }

  Behavior on scale {
    Morph {
      duration: Theme.morphState
    }
  }

  onActiveFocusChanged: if (!root.activeFocus)
    root.pointerFocused = false

  Rectangle {
    // A focus state, not contents: a content morph leaves it out.
    readonly property bool morphIgnore: true

    z: 1
    anchors.fill: parent
    anchors.margins: root.ringInset
    visible: root.keyFocused
    radius: root.ringRadius
    color: "transparent"
    border.width: 1
    border.color: Theme.focusRing
  }

  MouseArea {
    id: area

    anchors.fill: parent
    anchors.margins: -root.hitSlop
    hoverEnabled: true
    acceptedButtons: root.interactive ? Qt.LeftButton : Qt.NoButton
    cursorShape: root.interactive && root.enabled && root.revealed ? Qt.PointingHandCursor : Qt.ArrowCursor
    onPressed: if (root.activeFocusOnTab) {
      root.pointerFocused = true;
      root.forceActiveFocus();
    }
    onClicked: root.activate()
    onDoubleClicked: if (root.interactive && root.enabled && root.revealed)
      root.doubleClicked()
  }

  Keys.onPressed: function (event) {
    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.activate();
      event.accepted = true;
    }
  }
}
