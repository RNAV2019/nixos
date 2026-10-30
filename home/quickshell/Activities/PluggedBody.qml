import QtQuick
import qs.Commons
import qs.Services
import qs.Ui
import "../Commons/Duration.js" as Duration

// The plugged-in moment (Penpot "Ariadne / Moment / Plugged in"), OSD-sized: a battery whose fill
// runs up to the charge, "Charging", the percentage, and how long until it is full when UPower
// can say. Read live, so a "Full in" that UPower only works out a second after the plug appears.
Item {
  id: root

  // Given by Activities/Moments.qml: the spec, and whether the island is showing it yet.
  property var moment: null
  property bool shown: false

  // Read live from the battery; a test hook can hand it a charge and a time instead (`data`).
  readonly property var fakes: moment && moment.data ? moment.data : null
  readonly property real level: fakes ? fakes.level : Battery.level
  readonly property real toFull: fakes ? fakes.toFull : Battery.present ? Battery.battery.timeToFull : 0

  // The fill climbs from empty once the moment is on screen, then follows the charge.
  property real fill: 0

  onShownChanged: if (shown)
    fillIn.restart()

  NumberAnimation {
    id: fillIn

    target: root
    property: "fill"
    from: 0
    to: root.level
    duration: Theme.duration(Theme.morphProgress)
    easing.type: Easing.OutCubic
  }

  Binding {
    target: root
    property: "fill"
    value: root.level
    when: root.shown && !fillIn.running
    restoreMode: Binding.RestoreNone
  }

  StrokeIcon {
    x: 20
    y: (root.height - size) / 2
    size: 24
    strokeWidth: 1.75
    path: IconPaths.batteryOutline
    color: Theme.accent
  }

  // Inside the outline: 13 x 7 on the 24 grid at (3.5, 8.5).
  Rectangle {
    x: 23.5
    y: (root.height - 24) / 2 + 8.5
    width: 13 * Theme.clamp01(root.fill)
    height: 7
    radius: 1
    color: Theme.accent
  }

  Text {
    x: 54
    y: (root.height - height) / 2
    text: "Charging"
    color: Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: Theme.momentTitleSize
    font.weight: Theme.weightSemi
  }

  Text {
    x: 116
    y: (root.height - height) / 2
    text: Math.round(root.level * 100) + "%"
    color: Theme.accent
    font.family: Theme.uiFont
    font.pixelSize: Theme.momentTitleSize
    font.weight: Theme.weightSemi
    font.features: {
      "tnum": 1
    }
  }

  // Right-aligned at 320 of 340; left out while UPower has no estimate.
  Text {
    x: 320 - width
    y: (root.height - height) / 2
    visible: root.toFull > 0
    text: "Full in " + Duration.describe(Math.ceil(root.toFull / 60) * 60000)
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: 11
  }
}
