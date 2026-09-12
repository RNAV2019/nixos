import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// The clock a surface carries over from the shape it grew out of. It must not move
// on the hand-over frame, the one frame where both surfaces are the same shape.
Item {
  id: clockRoot

  // The owning surface's IslandOrigin, which knows the shape this clock came from.
  property IslandOrigin origin

  // False while the surface's own contents are up.
  property bool shown: true
  property real clockShift: 0
  property alias date: clock.date
  readonly property real clockWidth: clockLabel.width

  SystemClock {
    id: clock

    precision: SystemClock.Minutes
  }

  RollingClock {
    id: clockLabel

    x: (parent.width - width) / 2 + clockRoot.clockShift
    y: clockRoot.origin && clockRoot.origin.fromCard ? clockRoot.origin.fromHeight / 2 - 8 * clockRoot.origin.fromOpenness - height / 2 : (parent.height - height) / 2
    text: Qt.formatDateTime(clock.date, "HH:mm")
    color: Theme.text
    font.family: Theme.uiFont
    font.pixelSize: Theme.islandClockSize + (clockRoot.origin ? clockRoot.origin.fromOpenness : 0) * (Theme.islandDisplaySize - Theme.islandClockSize)
    font.weight: Font.DemiBold
    opacity: clockRoot.shown ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
      enabled: !clockRoot.origin || (!clockRoot.origin.handedOver && !clockRoot.origin.held)

      Morph {
        duration: Theme.morphContent
      }
    }
  }
}
