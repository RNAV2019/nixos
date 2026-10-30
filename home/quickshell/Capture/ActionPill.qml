import QtQuick
import qs.Commons
import qs.Ui

// The result cards' button: 30 high, a glyph and a label. Primary is the accent; secondary a
// quiet fill with a hairline edge.
Rectangle {
  id: root

  property string label: ""
  property string glyph: ""
  property bool primary: false
  readonly property bool hovered: area.containsMouse

  signal clicked

  implicitWidth: Theme.notifActionPad * 2 + (root.glyph !== "" ? 14 + 6 : 0) + labelText.implicitWidth
  implicitHeight: Theme.notifActionHeight
  radius: height / 2
  color: root.primary ? Theme.accentFill : Theme.withAlpha(Theme.highlightLow, 0.9)
  border.width: root.primary ? 0 : 1
  border.color: Theme.withAlpha(Theme.separator, Theme.powerTileBorderAlpha)
  opacity: root.hovered ? 0.85 : 1
  scale: area.pressed ? Theme.pressScale : 1

  Accessible.role: Accessible.Button
  Accessible.name: root.label
  Accessible.onPressAction: root.clicked()

  Behavior on opacity {
    Morph {
      duration: Theme.morphState
    }
  }

  Behavior on scale {
    Morph {
      duration: Theme.morphState
    }
  }

  StrokeIcon {
    visible: root.glyph !== ""
    x: Theme.notifActionPad
    y: (parent.height - height) / 2
    size: 14
    strokeWidth: 1.75
    path: root.glyph
    color: root.primary ? Theme.inkOnAccent : Theme.inkPrimary
  }

  Text {
    id: labelText

    x: Theme.notifActionPad + (root.glyph !== "" ? 20 : 0)
    y: (parent.height - height) / 2
    text: root.label
    color: root.primary ? Theme.inkOnAccent : Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: Theme.notifActionSize
    font.weight: root.primary ? Theme.weightSemi : Theme.weightMedium
  }

  MouseArea {
    id: area

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
