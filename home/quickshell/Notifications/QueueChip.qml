import QtQuick
import qs.Commons
import qs.Ui

// "+2": the toasts waiting behind this one.
Rectangle {
  id: chip

  property int count: 0
  property bool shown: true

  // The last number worth drawing, so it can fade out with the chip rather than before it.
  property int last: 0
  // Which of the two digits is the front one: each count change swaps them over.
  property bool flip: false

  onCountChanged: {
    if (chip.count <= 0 || chip.count === chip.last)
      return;
    if (chip.last > 0)
      chip.flip = !chip.flip;
    (chip.flip ? digitB : digitA).text = "+" + chip.count;
    chip.last = chip.count;
  }

  width: Theme.notifChipWidth
  height: Theme.notifChipHeight
  radius: height / 2
  color: Theme.lift(Theme.liftControl)
  opacity: chip.shown && chip.count > 0 ? 1 : 0
  visible: opacity > 0

  Behavior on opacity {
    Morph {
      duration: Theme.duration(Theme.morphContent)
    }
  }

  Accessible.role: Accessible.StaticText
  Accessible.name: chip.count + " more notifications"

  ChipDigit {
    id: digitA

    front: !chip.flip
  }

  ChipDigit {
    id: digitB

    front: chip.flip
  }
}
