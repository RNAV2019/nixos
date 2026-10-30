import QtQuick
import qs.Commons
import qs.Ui

// A small label pill. The accent form says something was done ("Copied", with a check); the
// neutral form names a format ("PNG", "URL").
Rectangle {
  id: root

  property string label: ""
  property bool accent: false
  property int pad: Theme.resultPillPad
  property int fontSize: Theme.resultPillSize

  implicitWidth: pad * 2 + (root.accent ? 12 + 6 : 0) + labelText.implicitWidth
  implicitHeight: Theme.trayTagHeight
  radius: height / 2
  color: root.accent ? Theme.withAlpha(Theme.accent, 0.16) : Theme.withAlpha(Theme.highlightLow, 0.9)
  border.width: root.accent ? 0 : 1
  border.color: Theme.withAlpha(Theme.separator, Theme.powerTileBorderAlpha)

  StrokeIcon {
    visible: root.accent
    x: root.pad
    y: (parent.height - height) / 2
    size: 12
    strokeWidth: 2
    path: IconPaths.check
    color: Theme.accent
  }

  Text {
    id: labelText

    x: root.accent ? root.pad + 18 : (parent.width - width) / 2
    y: (parent.height - height) / 2
    text: root.label
    color: root.accent ? Theme.accent : Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: root.fontSize
    font.weight: Theme.weightSemi
  }
}
