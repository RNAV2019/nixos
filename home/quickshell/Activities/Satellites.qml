import QtQuick
import qs.Commons
import qs.Services
import qs.Ui

// The satellites beside one bar's island: up to two circles to the right of the shut pill, the
// first at the pill's edge plus a gap and the second a circle and a gap beyond (Penpot "Ariadne
// / Island with satellites"). They only stand on the output the activities are on
// (Activities.home), and fold into the pill while the island is wanted for anything else.
//
// The pair is centred on the screen, which is the pill's job: it slides left by half a circle
// and a gap for each (Activities/PillSlide.qml, from the count published here), and these
// follow its live edge. A circle appears out of the pill's right edge as the pill is pushed
// aside, a second out of the first's, and each leaves the same way back.
Item {
  id: root

  // The bar's island, whose live geometry the circles hang off.
  required property var island
  required property string screenName

  // Dimmed with the pills when the machine has sat idle (Services/OledCare.qml).
  opacity: OledCare.level

  readonly property bool home: screenName !== "" && screenName === Activities.home

  // Folded away while the island is something other than the resting pill: another surface
  // is standing in for it, or it is open, taking a file drop, or still settling back.
  readonly property bool folded: !home || Activities.islandBusy(screenName) || island.suppressed || island.expanded || island.dropArmed || island.height > Theme.barHeight + 0.5

  // The circles standing or still on their way out, which is how far the pill is pushed.
  readonly property int occupied: slotA.occupies ? (slotB.occupies ? 2 : 1) : 0

  // What the second circle stands for when three or more are going: "+N", and the list.
  readonly property int hiddenCount: Activities.hidden.length

  readonly property real step: Theme.satelliteSize + Theme.satelliteGap

  // The input region: the circles and the gaps between them.
  readonly property alias strip: strip

  Item {
    id: strip

    x: root.island.x + root.island.width
    y: root.island.y
    width: root.occupied > 0 && !root.folded ? root.occupied * root.step : 0
    height: Theme.satelliteSize
  }

  Binding {
    target: Activities
    property: "slideCount"
    value: root.occupied
    when: root.home
  }

  Binding {
    target: Activities
    property: "slideFolded"
    value: root.folded
    when: root.home
  }

  onFoldedChanged: if (folded)
    Activities.closeCard()

  SatelliteSlot {
    id: slotA

    island: root.island
    index: 0
    home: root.home
    folded: root.folded
    hiddenCount: root.hiddenCount
    subject: Activities.slots.length > 0 ? Activities.slots[0] : null
  }

  SatelliteSlot {
    id: slotB

    island: root.island
    index: 1
    previous: slotA
    home: root.home
    folded: root.folded
    hiddenCount: root.hiddenCount
    subject: Activities.slots.length > 1 ? Activities.slots[1] : (root.hiddenCount > 0 ? "count" : null)
  }
}
