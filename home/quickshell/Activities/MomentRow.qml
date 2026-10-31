import QtQuick
import qs.Commons
import qs.Ui

// The usual moment (Penpot "Ariadne / Moment"): the sharing pill's row. A 20 px glyph on the
// left, a title and a subtitle that elide on the right inside the padding, and up to three 26 px
// buttons, the first listed leftmost and the last at the right edge. Laid out at the moment's
// own size; the growing island uncovers it.
Item {
  id: root

  // The spec Activities.raiseMoment made (Services/Activities.qml), with buttons as it lists them.
  property var moment: null

  signal acted(var button)

  readonly property var buttons: moment ? moment.buttons : []
  readonly property real inset: 16

  // Where the buttons begin, counted from the right edge.
  readonly property real buttonsLeft: buttonRow.x

  StrokeIcon {
    x: root.inset
    y: (root.height - size) / 2
    size: 20
    strokeWidth: 1.75
    path: root.moment ? root.moment.icon : ""
    color: root.moment ? root.moment.iconColor : Theme.accent
  }

  Text {
    x: 48
    y: 13
    width: Math.max(0, root.buttonsLeft - 12 - x)
    elide: Text.ElideRight
    text: root.moment ? root.moment.title : ""
    color: Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: Theme.momentTitleSize
    font.weight: Theme.weightSemi
  }

  Text {
    x: 48
    y: 33
    width: Math.max(0, root.buttonsLeft - 12 - x)
    elide: Text.ElideRight
    text: root.moment ? root.moment.subtitle : ""
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: Theme.momentSubtitleSize
  }

  Row {
    id: buttonRow

    x: root.width - root.inset - width
    y: (root.height - height) / 2
    spacing: Theme.activityButtonGap

    Repeater {
      model: root.buttons

      ActivityButton {
        required property var modelData

        compact: true
        kind: modelData.kind || "secondary"
        text: modelData.text
        icon: modelData.icon || ""
        width: modelData.width || implicitWidth
        onClicked: root.acted(modelData)
      }
    }
  }
}
