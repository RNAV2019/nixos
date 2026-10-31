import QtQuick
import qs.Commons
import qs.Services
import qs.Ui
import "../Commons/Duration.js" as Duration

// The plugged-in moment (Penpot "Ariadne / Moment / Plugged in"), an island pill row: a battery
// whose fill runs up to the charge, "Charging", the percentage, and how long until it is full when
// UPower can say. Read live, so a "Full in" that UPower only works out a second after the plug
// appears.
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

  IslandPill {
    anchors.fill: parent
    layout: "glyphLabelDetailReading"
    label: "Charging"
    detail: Math.round(root.level * 100) + "%"
    reading: root.toFull > 0 ? "Full in " + Duration.describe(Math.ceil(root.toFull / 60) * 60000) : ""

    StrokeIcon {
      anchors.centerIn: parent
      size: Theme.islandPillGlyphSizeWide
      strokeWidth: 1.75
      path: IconPaths.batteryOutline
      color: Theme.accent
    }

    // Inside the outline: 13 x 7 on the 24 grid at (3.5, 8.5).
    Rectangle {
      x: 3.5
      y: 8.5
      width: 13 * Theme.clamp01(root.fill)
      height: 7
      radius: 1
      color: Theme.accent
    }
  }
}
