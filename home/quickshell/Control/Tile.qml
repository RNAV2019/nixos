import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  property string label: ""
  property string sublabel: ""
  property string glyph: ""
  property bool on: false
  property bool opensView: false
  property bool keyFocused: false
  property string accessibleName: ""

  signal toggled
  signal opened

  readonly property bool hovered: badgeHover.containsMouse || bodyHover.containsMouse
  readonly property bool pressed: badgeHover.pressed || bodyHover.pressed

  height: Theme.controlTileHeight
  radius: Theme.controlTileRadius

  activeFocusOnTab: true
  Accessible.role: root.opensView ? Accessible.Button : Accessible.CheckBox
  Accessible.name: root.accessibleName !== "" ? root.accessibleName : root.label
  Accessible.description: root.sublabel
  Accessible.checkable: !root.opensView
  Accessible.checked: root.on
  Accessible.focusable: true
  Accessible.focused: root.activeFocus
  Accessible.onPressAction: {
    if (root.opensView)
      root.opened();
    else
      root.toggled();
  }
  Accessible.onToggleAction: if (!root.opensView)
    root.toggled()

  color: {
    if (on)
       return hovered ? Qt.lighter(Theme.accentFill, 1.08) : Theme.accentFill;
       return Theme.withAlpha(hovered ? Theme.highlightMed : Theme.surfaceSubtle, 0.9);
  }

  border.width: on ? 0 : 1
  border.color: root.keyFocused ? Theme.focusRing : Theme.withAlpha(Theme.separator, 0.7)
  scale: pressed ? Theme.pressScale : 1

  Behavior on color {
    Tint {}
  }

  Behavior on scale {
    Morph { duration: Theme.morphState }
  }

  Rectangle {
    id: badge

    x: Theme.controlTileBadgeLeft
    y: (parent.height - height) / 2
    width: Theme.controlTileBadge
    height: Theme.controlTileBadge
    radius: height / 2
    color: root.on ? Theme.withAlpha(Theme.inkOnAccent, badgeHover.containsMouse ? 0.28 : 0.16) : Theme.withAlpha(Theme.inkPrimary, badgeHover.containsMouse ? 0.14 : 0.07)

    Behavior on color {
      Tint {}
    }

    Text {
      anchors.centerIn: parent
      text: root.glyph
      color: root.on ? Theme.inkOnAccent : Theme.inkSecondary
      font.family: Theme.iconFont
      font.pixelSize: Theme.controlTileGlyphSize
    }
  }

  Text {
    id: name

    x: Theme.controlTileTextLeft
    y: 12
    width: Math.max(0, root.width - x - 10)
    text: root.label
    color: root.on ? Theme.inkOnAccent : Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlTileLabelSize
    font.weight: Theme.weightSemi
    elide: Text.ElideRight
  }

  Text {
    x: name.x
    y: 30
    width: name.width
    text: root.sublabel
    color: root.on ? Theme.withAlpha(Theme.inkOnAccent, 0.72) : Theme.inkTertiary
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlTileSubSize
    elide: Text.ElideRight
  }

  // The badge's target includes its gutter, so the split falls where the text begins.
  MouseArea {
    id: badgeHover

    x: 0
    y: 0
    width: Theme.controlTileTextLeft
    height: parent.height
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onPressed: root.forceActiveFocus()
    onClicked: root.toggled()
  }

  MouseArea {
    id: bodyHover

    x: badgeHover.width
    y: 0
    width: Math.max(0, parent.width - x)
    height: parent.height
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onPressed: root.forceActiveFocus()
    onClicked: root.opensView ? root.opened() : root.toggled()
  }

  Keys.onPressed: function (event) {
    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (root.opensView)
        root.opened();
      else
        root.toggled();
      event.accepted = true;
    }
  }
}
