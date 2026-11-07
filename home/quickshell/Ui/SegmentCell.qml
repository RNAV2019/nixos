import QtQuick
import qs.Commons

// One cell of a Segmented: an icon and/or a label that steps from subtle to text under the
// pointer, with a ground of its own while hovered. The chosen cell's accent plate belongs to
// the Segmented, which slides it between cells, so this one only changes its ink.
ButtonBase {
  id: root

  property string label: ""
  property string icon: ""
  property bool iconFilled: false
  property bool chosen: false
  // The cell's own measurements; the Segmented sets its size.
  property real fitPad: Theme.nearbyFitPad

  readonly property color ink: root.chosen ? Theme.inkOnAccent : root.hovered || root.pressed ? Theme.inkPrimary : Theme.inkSecondary
  // What the cell asks for when it is sized to its content.
  readonly property real fitWidth: row.implicitWidth + fitPad * 2

  accessibleRole: Accessible.RadioButton
  checkable: true
  checked: root.chosen
  activeFocusOnTab: false

  Rectangle {
    anchors.fill: parent
    visible: !root.chosen
    radius: height / 2
    color: Theme.lift(root.hovered || root.pressed ? Theme.liftHover : 0)

    Behavior on color {
      Tint {}
    }
  }

  Row {
    id: row

    anchors.centerIn: parent
    spacing: Theme.nearbySegmentGap

    StrokeIcon {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.icon !== ""
      size: Theme.nearbySegmentGlyph
      strokeWidth: 1.75
      path: root.icon
      filled: root.iconFilled
      color: root.ink

      Behavior on color {
        Tint {}
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.label !== ""
      text: root.label
      color: root.ink
      font.family: Theme.uiFont
      font.pixelSize: Theme.segmentLabelSize
      font.weight: Theme.weightSemi

      Behavior on color {
        Tint {}
      }
    }
  }
}
