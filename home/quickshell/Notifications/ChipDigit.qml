import QtQuick
import qs.Commons
import qs.Ui

// One of the chip's two digits; the count change cross-fades them.
Text {
  required property bool front

  anchors.centerIn: parent
  color: Theme.inkPrimary
  opacity: front ? 1 : 0
  font.family: Theme.uiFont
  font.pixelSize: Theme.notifChipSize
  font.weight: Theme.weightSemi

  Behavior on opacity {
    Morph {
      duration: Theme.duration(Theme.morphContent)
    }
  }
}
