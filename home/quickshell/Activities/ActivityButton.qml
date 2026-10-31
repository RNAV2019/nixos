import QtQuick
import qs.Commons
import qs.Ui

// The cards' and moments' pill button, after the sharing pill's: primary is the accent, secondary
// a quiet separator fill, ghost an outline, danger the urgent fill. Hover lifts a fill by 6%,
// press takes the shell's press scale.
Rectangle {
  id: root

  property string text: ""
  // An IconPaths icon, drawn before the label.
  property string icon: ""
  // "primary", "secondary", "ghost" or "danger".
  property string kind: "secondary"
  // The moment's smaller button: 26 high, label 11.
  property bool compact: false

  signal clicked

  readonly property color fill: kind === "primary" ? Theme.accentFill : kind === "danger" ? Theme.dangerFill : kind === "secondary" ? Theme.withAlpha(Theme.separator, 0.85) : "transparent"
  readonly property color ink: kind === "primary" ? Theme.inkOnAccent : kind === "danger" ? Theme.inkOnDanger : Theme.inkPrimary
  readonly property real labelSize: compact ? 11 : 12

  implicitWidth: content.implicitWidth + (compact ? 24 : 28)
  implicitHeight: compact ? Theme.momentButtonHeight : Theme.activityButtonHeight
  radius: height / 2
  color: kind === "ghost" ? (area.containsMouse ? Theme.withAlpha(Theme.inkPrimary, 0.06) : "transparent") : area.containsMouse ? Qt.lighter(fill, 1.06) : fill
  border.width: kind === "ghost" ? 1 : 0
  border.color: Theme.withAlpha(Theme.separator, 0.7)
  scale: area.pressed ? Theme.pressScale : 1

  Behavior on scale {
    Morph {
      duration: Theme.morphState
    }
  }

  Row {
    id: content

    anchors.centerIn: parent
    spacing: 6

    StrokeIcon {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.icon !== ""
      size: 13
      strokeWidth: 1.75
      path: root.icon
      color: root.ink
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.text
      color: root.ink
      font.family: Theme.uiFont
      font.pixelSize: root.labelSize
      font.weight: root.kind === "secondary" ? Theme.weightMedium : Theme.weightSemi
    }
  }

  MouseArea {
    id: area

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
