import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// The clock a surface carries over from the shape it grew out of, in one
// place. It was written out whole in the launcher and the control centre, and
// drawn as a fixed pill-sized copy in the four surfaces that had no card
// geometry to reason about; this is the launcher's version, and every island
// surface carries it now.
//
// The clock belongs to neither state. It is what the pill was showing at the
// moment the key was pressed, and it stays in the growing box, drawn on its
// centre, until the contents have taken over.
//
// Out of the pill that is a small clock on the box's centre. Out of the card
// it is the card's own: larger, and held 8 px above the centre the card had
// rather than the centre this box is growing into, so the panel grows past it
// instead of carrying it down. Either way the clock does not move on the frame
// the hand-over happens, which is the only frame where the two surfaces are
// the same shape and the eye could catch it.
Item {
  id: clockRoot

  // The owning surface's IslandOrigin, which knows the shape this clock was
  // carried over from.
  property IslandOrigin origin

  // False while the surface's contents are up: the clock belongs to the shape
  // the surface grew out of, not to what is drawn in it.
  property bool shown: true

  SystemClock {
    id: clock

    precision: SystemClock.Minutes
  }

  Text {
    x: (parent.width - width) / 2
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
