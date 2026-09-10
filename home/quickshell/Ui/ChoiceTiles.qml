import QtQuick
import qs.Commons

// One row of tiles asking "which of these". The power menu, the profiles card
// and the recorder picker each drew this grid, and their own comments said so:
// "the power menu's own tile grid, to the pixel", "the tile grid is the power
// menu's and the recorder picker's, to the pixel". Three surfaces asking the
// same question in the same shape had three copies of it.
//
// The caller supplies the model, says which tile is active and which the
// keyboard is on, and hears back when one is chosen. Everything about how a
// tile looks in each of those states is here, once.
Item {
  id: root

  // Entries of { glyph, label }. Rebuilt by the caller when a label changes,
  // which is how the power menu relabels an armed tile Confirm.
  property var model: []

  // The tile the keyboard is on, and the tile that is filled. They are not the
  // same thing: the profiles card opens with the keyboard on the profile that
  // is already running, and the recorder picker moves both together.
  property int currentIndex: 0
  property int activeIndex: -1
  property int inset: Theme.powerInset
  property string activeLabel: ""

  // The fill an active tile takes. Love where the tile says the machine's
  // whole stance has changed or is about to, accent where it is merely the
  // one picked out of three.
  property color activeColor: Theme.accent

  // Whether the active tile's colour outranks the focus ring. The power menu
  // sets this: an armed tile is one press from ending the session, so it must
  // not be wearing the same accent ring as a tile that is merely selected.
  // Everywhere else the ring wins, because it is the only thing saying where
  // Return would land.
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

        // A press dips the whole tile rather than only its fill, so the target
        // reads as taking the click at any size.
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
        color: tile.ink ? Theme.base : Theme.text
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
        color: tile.ink ? Theme.base : Theme.text
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
        // Hovering moves the keyboard's place too, so the tile the eye is on
        // and the tile Return would fire are never different ones.
        onEntered: root.entered(tile.index)
        onClicked: root.activated(tile.index)
      }
    }
  }
}
