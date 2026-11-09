import QtQuick
import qs.Commons

// A section's heading: the title in tertiary ink, optionally a detail right after it
// ("3 · 18.4 MB") and a note at the far end. Children sit in a row at the far end, as the
// Nearby panel's links do; `action` is the same place for the one accent link a section
// carries ("Clear all"), with a glyph before it if `actionGlyph` is set.
Item {
  id: root

  // A content-morph anchor (Ui/MorphScan.js): what it is, and what pairs it across panels.
  property string morphRole: "section"
  property string morphKey: ""
  property var morphSlot: undefined

  property string title: ""
  property string detail: ""
  property string note: ""
  // Padding at both ends; Control's views already sit inside their own inset.
  property real inset: 0
  // Where the text sits in the row: on its top, centred, or (the default) seated
  // `bottomInset` off its foot as in Control's 22 px rows.
  property int verticalAlignment: Qt.AlignBottom
  property real bottomInset: 4
  property string action: ""
  property string actionGlyph: ""
  property real actionGlyphSize: 12
  default property alias trailing: trailingRow.data

  signal actionClicked

  implicitHeight: Theme.controlSectionHeight

  Text {
    id: titleText

    x: root.inset
    y: root.verticalAlignment === Qt.AlignTop ? 0 : root.verticalAlignment === Qt.AlignVCenter ? (root.height - height) / 2 : root.height - height - root.bottomInset
    text: root.title
    color: Theme.inkTertiary
    font.family: Theme.uiFont
    font.pixelSize: Theme.sectionSize
    font.weight: Theme.weightMedium
  }

  Text {
    x: titleText.x + titleText.implicitWidth + 8
    y: titleText.y
    visible: root.detail !== ""
    text: root.detail
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: Theme.sectionSize
    font.weight: Theme.weightMedium
  }

  Text {
    x: root.width - root.inset - width
    y: titleText.y
    visible: root.note !== ""
    text: root.note
    color: Theme.inkTertiary
    font.family: Theme.uiFont
    font.pixelSize: Theme.sectionSize
    font.weight: Theme.weightMedium
  }

  Row {
    id: trailingRow

    anchors.right: parent.right
    anchors.rightMargin: root.inset
    anchors.verticalCenter: titleText.verticalCenter
    spacing: 5
  }

  Row {
    id: actionRow

    anchors.right: parent.right
    anchors.rightMargin: root.inset
    anchors.verticalCenter: titleText.verticalCenter
    spacing: 4
    visible: root.action !== ""
    opacity: actionArea.pressed ? 0.7 : 1

    StrokeIcon {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.actionGlyph !== ""
      size: root.actionGlyphSize
      strokeWidth: 1.8
      path: root.actionGlyph
      color: Theme.accentFill
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.action
      color: Theme.accentFill
      font.family: Theme.uiFont
      font.pixelSize: Theme.sectionSize
      font.weight: Theme.weightMedium
    }
  }

  MouseArea {
    id: actionArea

    anchors.fill: actionRow
    anchors.margins: -6
    visible: root.action !== ""
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.actionClicked()

    Accessible.role: Accessible.Button
    Accessible.name: root.action
    Accessible.onPressAction: root.actionClicked()
  }
}
