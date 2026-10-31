import QtQuick
import qs.Commons

// The small controls a panel header carries. Back, Label, Previous and Next sit on a disc and
// share one recipe: highlightMed at a rest alpha, a higher one under the pointer or pressed,
// and the press scale. Rescan and Reset are bare glyphs that step from subtle to text, as
// IconButton does.
Item {
  id: root

  enum Kind {
    Back,
    Label,
    Previous,
    Next,
    Rescan,
    Reset
  }

  property int kind: HeaderButton.Back
  // The Label kind's text.
  property string label: ""
  property string accessibleName: ""

  signal clicked

  readonly property bool hovered: area.containsMouse
  readonly property bool pressed: area.pressed
  readonly property bool disc: kind === HeaderButton.Back || kind === HeaderButton.Label || kind === HeaderButton.Previous || kind === HeaderButton.Next

  readonly property string glyph: {
    switch (kind) {
    case HeaderButton.Back:
      return Icons.back;
    case HeaderButton.Previous:
      return Icons.chevronLeft;
    case HeaderButton.Next:
      return Icons.chevronRight;
    case HeaderButton.Rescan:
      return Icons.refresh;
    case HeaderButton.Reset:
      return Icons.restore;
    }
    return "";
  }

  readonly property int glyphSize: kind === HeaderButton.Previous || kind === HeaderButton.Next ? Theme.calNavGlyphSize : Theme.headerIconSize

  // The nav chevrons stay subtle on their disc; the others lift to text.
  readonly property color ink: {
    if (kind === HeaderButton.Previous || kind === HeaderButton.Next)
      return Theme.subtle;
    if (disc)
      return Theme.text;
    return root.hovered ? Theme.text : Theme.subtle;
  }

  implicitWidth: {
    switch (kind) {
    case HeaderButton.Back:
      return Theme.controlBackSize;
    case HeaderButton.Label:
      return labelText.implicitWidth + 22;
    case HeaderButton.Previous:
    case HeaderButton.Next:
      return Theme.calNavSize;
    }
    return Theme.headerIconSize;
  }
  implicitHeight: {
    switch (kind) {
    case HeaderButton.Back:
      return Theme.controlBackSize;
    case HeaderButton.Label:
      return Theme.calTodayBtnHeight;
    case HeaderButton.Previous:
    case HeaderButton.Next:
      return Theme.calNavSize;
    }
    return Theme.headerIconSize;
  }
  width: implicitWidth
  height: implicitHeight

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: root.accessibleName !== "" ? root.accessibleName : root.label
  Accessible.focusable: true
  Accessible.focused: root.activeFocus
  Accessible.onPressAction: root.clicked()

  scale: root.pressed ? Theme.pressScale : 1

  Behavior on scale {
    Morph {
      duration: Theme.morphState
    }
  }

  Rectangle {
    anchors.fill: parent
    visible: root.disc
    radius: height / 2
    color: Theme.withAlpha(Theme.highlightMed, root.hovered || root.pressed ? Theme.headerButtonHoverAlpha : Theme.headerButtonRestAlpha)

    Behavior on color {
      Tint {}
    }
  }

  Text {
    anchors.centerIn: parent
    visible: root.kind !== HeaderButton.Label
    text: root.glyph
    color: root.ink
    font.family: Theme.iconFont
    font.pixelSize: root.glyphSize

    Behavior on color {
      Tint {}
    }
  }

  Text {
    id: labelText

    anchors.centerIn: parent
    visible: root.kind === HeaderButton.Label
    text: root.label
    color: root.ink
    font.family: Theme.uiFont
    font.pixelSize: Theme.calTodayBtnSize
    font.weight: Theme.weightMedium
  }

  MouseArea {
    id: area

    // A bare glyph keeps the comfortable hit area IconButton gave it.
    anchors.fill: parent
    anchors.margins: root.disc ? 0 : -8
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onPressed: root.forceActiveFocus()
    onClicked: root.clicked()
  }

  Keys.onPressed: function (event) {
    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.clicked();
      event.accepted = true;
    }
  }
}
