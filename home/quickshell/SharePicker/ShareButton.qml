import QtQuick
import qs.Commons
import qs.Ui

// The picker's footer buttons: the notification card's pill at the picker's own size. Primary
// is the accent fill, secondary the raised ground with a hairline.
Rectangle {
  id: root

  property string label: ""
  property string glyph: ""
  property bool primary: false

  signal clicked

  readonly property color ink: root.primary ? Theme.inkOnAccent : Theme.inkPrimary

  implicitWidth: row.implicitWidth + Theme.shareButtonPad * 2
  implicitHeight: Theme.shareButtonHeight
  radius: height / 2

  color: root.primary ? Theme.accentFill : Theme.withAlpha(Theme.surfaceSubtle, Theme.notifActionSecondaryAlpha)
  border.width: root.primary ? 0 : 1
  border.color: Theme.withAlpha(Theme.separator, Theme.powerTileBorderAlpha)
  scale: mouse.pressed ? Theme.pressScale : 1

  Behavior on scale {
    Morph {
      duration: Theme.morphState
    }
  }

  Accessible.role: Accessible.Button
  Accessible.name: root.label
  Accessible.onPressAction: root.clicked()

  Row {
    id: row

    anchors.centerIn: parent
    spacing: Theme.shareButtonGlyphGap

    StrokeIcon {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.glyph !== ""
      size: Theme.shareButtonGlyph
      strokeWidth: 1.75
      path: root.glyph
      color: root.ink
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.label
      color: root.ink
      font.family: Theme.uiFont
      font.pixelSize: Theme.shareButtonSize
      font.weight: root.primary ? Theme.weightSemi : Theme.weightMedium
    }
  }

  MouseArea {
    id: mouse

    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
