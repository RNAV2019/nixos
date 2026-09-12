import QtQuick
import qs.Commons

// One row of tiles asking "which of these". The power menu, the profiles card and the
// recorder picker all draw this grid.
Item {
  id: root

  // Entries of { glyph, label }, rebuilt by the caller when a label changes.
  property var model: []

  // The tile the keyboard is on and the tile that is filled are not the same thing.
  property int currentIndex: 0
  property int activeIndex: -1
  property int inset: Theme.powerInset
  property string activeLabel: ""

  // Love where the machine's whole stance changes, accent where it is one pick of three.
  property color activeColor: Theme.accent

  // The power menu sets this: an armed tile must not wear the ring a selected one wears.
  property bool activeIsCommitting: false

  signal activated(int index)
  signal entered(int index)

  readonly property int count: model.length

  // The grid's own width, which is what the surfaces around it open to.
  readonly property int contentWidth: root.inset * 2 + count * Theme.powerTileWidth + Math.max(0, count - 1) * Theme.powerTileGap

  function tileX(i) {
    return root.inset + i * (Theme.powerTileWidth + Theme.powerTileGap);
  }

  implicitWidth: contentWidth
  implicitHeight: Theme.powerTileTop * 2 + Theme.powerTileHeight

  Repeater {
    model: root.model

    Item {
      id: tile

      required property int index
      required property var modelData

      readonly property bool isActive: root.activeIndex === tile.index
      readonly property bool isCurrent: root.currentIndex === tile.index
      readonly property bool ink: isActive

      x: root.tileX(index)
      y: Theme.powerTileTop
      width: Theme.powerTileWidth
      height: Theme.powerTileHeight

      activeFocusOnTab: true
      Accessible.role: Accessible.RadioButton
      Accessible.name: tile.modelData.label
      Accessible.checked: tile.isActive
      Accessible.focusable: true
      Accessible.focused: tile.isCurrent
      Accessible.onPressAction: root.activated(tile.index)

      Rectangle {
        anchors.fill: parent
        radius: Theme.powerTileRadius

        color: {
          if (tile.isActive)
            return hover.pressed ? Qt.darker(root.activeColor, 1.12) : root.activeColor;
          if (hover.pressed)
            return Theme.withAlpha(Theme.text, Theme.fillPressed);
          if (hover.containsMouse)
            return Theme.withAlpha(Theme.highlightMed, Theme.powerTileFillAlpha);
          return Theme.withAlpha(Theme.highlightLow, Theme.powerTileFillAlpha);
        }

        border.width: 1
        border.color: {
          if (tile.isActive && root.activeIsCommitting)
             return root.activeColor;
          if (tile.isCurrent || hover.containsMouse)
            return Theme.accent;
          if (tile.isActive)
            return root.activeColor;
          return Theme.withAlpha(Theme.highlightMed, Theme.powerTileBorderAlpha);
        }

        scale: hover.pressed ? 0.97 : 1

        Behavior on scale {
          Morph {
            duration: Theme.morphState
          }
        }

        Behavior on color {
          Tint {}
        }

        Behavior on border.color {
          Tint {}
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.powerGlyphTop - Theme.powerTileTop - height / 2 + Theme.powerGlyphSize / 2
        text: tile.modelData.glyph
         color: tile.ink ? Theme.inkOnAccent : Theme.inkPrimary
        font.family: Theme.iconFont
        font.pixelSize: Theme.powerGlyphSize

        Behavior on color {
          Tint {}
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.powerLabelTop - Theme.powerTileTop
         text: tile.isActive && root.activeLabel !== "" ? root.activeLabel : tile.modelData.label
         color: tile.ink ? Theme.inkOnAccent : Theme.inkPrimary
        font.family: Theme.uiFont
        font.pixelSize: Theme.powerLabelSize
        font.weight: tile.ink ? Font.Bold : Font.Medium

        Behavior on color {
          Tint {}
        }
      }

      MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: tile.forceActiveFocus()
        // Hovering moves the keyboard's place too, so the hovered tile is the one Return fires.
        onEntered: root.entered(tile.index)
        onClicked: root.activated(tile.index)
      }

      Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.activated(tile.index);
          event.accepted = true;
        }
      }
    }
  }
}
