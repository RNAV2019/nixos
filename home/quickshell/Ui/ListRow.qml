import QtQuick
import qs.Commons

// The shell's list row, on ButtonBase. Grouped is the control centre's: a pill, or a stack of
// them rounding only the group's outer corners, that fills with accent when chosen. Hairline is
// the board's row: highlightLow under a 1 px highlightMed edge, radius 14. Flat has no ground of
// its own, for the file picker's columns. All three step highlightMed to the shell's hover alpha
// and press like any control; a row that only reports sets `interactive: false`.
//
// A row lays out a lead glyph, a label with an optional line under it, a reading at the far end
// and a trailing slot; anything else a feature draws is a child, placed by hand.
ButtonBase {
  id: root

  morphRole: "row"

  enum Kind {
    Grouped,
    Hairline,
    Flat
  }

  property int kind: ListRow.Grouped

  // Rows stacked as one group round only the group's outer corners: "first", "middle",
  // "last", "only" for a group of one, or "single" for a row on its own (the default, a full pill).
  property string groupPosition: "single"
  // Grouped: chosen, in accent. Hairline: wearing the arrival accent.
  property bool selected: false
  property bool accented: false
  property bool showCheck: false
  // Hairline: 0..1 of the row washed in accent from the left, or -1 for none.
  property real fillProgress: -1
  // Hairline: draw the edge over a progress fill, not as part of the ground.
  property bool edgeOver: fillProgress >= 0
  // Flat: the row's ground, whatever the feature says it is.
  property color flatColor: "transparent"
  // Whether the ground steps to the hover colour. A row that reports can still be hovered.
  property bool hoverTint: interactive

  property string glyph: ""
  property color glyphColor: selected ? Theme.inkOnAccent : kind === ListRow.Grouped ? Theme.inkSecondary : Theme.accent
  property real glyphSize: Theme.controlTileGlyphSize
  property real glyphStroke: 1.75
  // As on Tile: the grid the glyph is drawn on before it is scaled to `glyphSize`.
  property real glyphGrid: glyphSize
  property real glyphLeft: kind === ListRow.Grouped ? Theme.controlRowInset : 15

  property string label: ""
  property string sublabel: ""
  property string value: ""
  property color labelColor: selected ? Theme.inkOnAccent : Theme.inkPrimary
  property color valueColor: Theme.subtle
  property real labelSize: kind === ListRow.Grouped ? Theme.controlTileLabelSize : Theme.rowLabelSize
  property int labelWeight: sublabel !== "" ? Theme.weightSemi : Theme.weightRegular
  property real valueSize: 12
  property real sublabelSize: Theme.controlTileSubSize
  property color sublabelColor: selected ? Theme.withAlpha(Theme.inkOnAccent, 0.72) : Theme.inkTertiary
  property int valueWeight: Theme.weightMedium
  property int elide: Text.ElideRight
  // Where the text starts, and the room it leaves at the far end: the reading's or the slot's
  // edge less `textGap`, unless `textRight` says how much to leave. -1 and the label's top
  // centre it (or lay it over its second line).
  property real textLeft: glyph !== "" ? glyphLeft + 30 : glyphLeft + 6
  property real textGap: 12
  property real textRight: -1
  property real subRight: textRight
  property real labelTop: -1
  property real valueTop: -1
  property real valueInset: 14
  property bool valueCentred: false
  // Space between the reading and a trailing slot.
  property real valueGap: 8
  property real trailInset: kind === ListRow.Grouped ? 8 : 14

  // What sits at the far end: buttons, a switch, a mark. Laid out right to left.
  property alias trailing: slot.data
  default property alias content: body.data

  readonly property real groupRadius: Theme.controlRowGroupRadius
  readonly property real cornerRadius: kind === ListRow.Grouped ? Theme.controlRowRadius : kind === ListRow.Hairline ? Theme.rowRadius : Theme.pickerRowRadius
  readonly property color edgeColor: accented ? Theme.withAlpha(Theme.accentFill, 0.45) : Theme.lift(Theme.liftEdge)
  readonly property bool tinted: hovered && hoverTint
  readonly property real farEdge: Math.min(valueText.visible ? valueText.x : Infinity, slot.x)
  readonly property real textRoom: Math.max(0, farEdge - textLeft - textGap)

  implicitHeight: kind === ListRow.Grouped ? Theme.controlRowHeight : kind === ListRow.Hairline ? Theme.phoneRowHeight : Theme.pickerRowHeight
  ringRadius: cornerRadius
  Accessible.name: accessibleName !== "" ? accessibleName : label
  Accessible.description: sublabel

  Rectangle {
    anchors.fill: parent
    radius: root.cornerRadius
    topLeftRadius: root.kind !== ListRow.Grouped || root.groupPosition === "single" ? radius : root.groupPosition === "first" || root.groupPosition === "only" ? root.groupRadius : 0
    topRightRadius: topLeftRadius
    bottomLeftRadius: root.kind !== ListRow.Grouped || root.groupPosition === "single" ? radius : root.groupPosition === "last" || root.groupPosition === "only" ? root.groupRadius : 0
    bottomRightRadius: bottomLeftRadius
    border.width: root.kind === ListRow.Hairline && !root.edgeOver ? 1 : 0
    border.color: root.edgeColor
    color: {
      if (root.kind === ListRow.Flat)
        return root.flatColor;
      if (root.selected && root.kind === ListRow.Grouped)
        return Theme.accent;
      if (root.accented)
        return Theme.withAlpha(Theme.accentFill, 0.1);
      return Theme.lift(root.tinted ? Theme.liftHover : Theme.liftTile);
    }

    Behavior on color {
      Tint {}
    }

    Behavior on border.color {
      Tint {}
    }
  }

  RoundedClip {
    anchors.fill: parent
    visible: root.fillProgress >= 0
    radius: root.cornerRadius

    Rectangle {
      width: parent.width * Theme.clamp01(root.fillProgress)
      height: parent.height
      color: Theme.withAlpha(Theme.accentFill, 0.16)

      Behavior on width {
        enabled: !Theme.reduceMotion

        Morph {
          duration: Theme.duration(Theme.morphProgress)
        }
      }
    }
  }

  Rectangle {
    anchors.fill: parent
    visible: root.kind === ListRow.Hairline && root.edgeOver
    radius: root.cornerRadius
    color: "transparent"
    border.width: 1
    border.color: root.edgeColor

    Behavior on border.color {
      Tint {}
    }
  }

  StrokeIcon {
    x: root.glyphLeft + (root.glyphSize - size) / 2
    y: (root.height - size) / 2
    visible: root.glyph !== ""
    size: root.glyphGrid
    scale: root.glyphSize / root.glyphGrid
    strokeWidth: root.glyphStroke
    path: root.glyph
    color: root.glyphColor
  }

  Text {
    id: labelText
    objectName: "label"

    x: root.textLeft
    y: root.labelTop >= 0 ? root.labelTop : root.sublabel !== "" ? root.height / 2 - 17 : (root.height - height) / 2
    width: Math.min(implicitWidth, root.textRight >= 0 ? Math.max(0, root.width - x - root.textRight) : root.textRoom)
    text: root.label
    color: root.labelColor
    font.family: Theme.uiFont
    font.pixelSize: root.labelSize
    font.weight: root.labelWeight
    elide: root.elide
  }

  Text {
    objectName: "sublabel"
    x: root.textLeft
    y: root.height / 2 + 1
    width: Math.min(implicitWidth, root.subRight >= 0 ? Math.max(0, root.width - x - root.subRight) : root.textRoom)
    visible: root.sublabel !== ""
    text: root.sublabel
    color: root.sublabelColor
    font.family: Theme.uiFont
    font.pixelSize: root.sublabelSize
    elide: Text.ElideRight
  }

  Text {
    id: valueText
    objectName: "value"

    x: root.valueCentred ? (root.width - width) / 2 : (slot.width > 0 ? slot.x - root.valueGap : root.width - root.valueInset) - width
    y: root.valueTop >= 0 ? root.valueTop : (root.height - height) / 2
    visible: text !== ""
    text: root.value
    color: root.valueColor
    font.family: Theme.uiFont
    font.pixelSize: root.valueSize
    font.weight: root.valueWeight
  }

  Item {
    id: body

    anchors.fill: parent
  }

  Row {
    id: slot

    anchors.right: check.shown ? check.left : parent.right
    anchors.rightMargin: root.trailInset
    anchors.verticalCenter: parent.verticalCenter
    layoutDirection: Qt.RightToLeft
    spacing: 6
  }

  StrokeIcon {
    id: check

    anchors.right: parent.right
    anchors.rightMargin: Theme.controlRowInset
    anchors.verticalCenter: parent.verticalCenter
    // Leaves as it arrives, a fade and a slight scale, so it stays drawn until the fade is spent;
    // the row's layout follows `shown` and does not wait for it.
    readonly property bool shown: root.showCheck && root.selected

    visible: opacity > 0
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.5
    size: 16
    path: Icons.check
    color: Theme.inkOnAccent

    Behavior on opacity {
      Morph {
        duration: Theme.duration(Theme.morphState)
      }
    }

    Behavior on scale {
      Morph {
        duration: Theme.morphState
      }
    }
  }
}
