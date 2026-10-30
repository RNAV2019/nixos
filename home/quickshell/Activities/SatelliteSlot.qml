import QtQuick
import qs.Commons
import qs.Services
import qs.Ui

// One place beside the pill (Activities/Satellites.qml makes two): it shows the activity it is
// given, or "+N" for those past two, and carries the circle in and out.
Item {
  id: slot

  // The bar's island, whose live right edge this hangs off, and what the strip says.
  required property var island
  required property int index
  required property bool home
  required property bool folded
  required property int hiddenCount
  // The circle nearer the pill, which a second one comes out from behind; null for the first.
  property Item previous: null

  // An activity, "count" or null.
  property var subject: null

  readonly property bool isCount: subject === "count"
  readonly property bool wants: !folded && subject !== null
  readonly property real step: Theme.satelliteSize + Theme.satelliteGap

  // What is drawn, latched: a circle leaving keeps its last look instead of blanking.
  property var look: null
  property string key: ""

  readonly property var countLook: ({
      kind: "count",
      icon: "",
      iconSize: Theme.satelliteGlyphSize,
      iconColor: Theme.inkPrimary,
      text: "+" + hiddenCount,
      textColor: Theme.inkPrimary,
      textSize: 12,
      caption: "",
      ring: -1,
      ringColor: Theme.accent,
      indeterminate: false,
      ground: Theme.surface,
      filled: false,
      haloColor: Theme.accent,
      attention: false,
      acknowledged: true
    })

  Binding {
    target: slot
    property: "look"
    value: slot.isCount ? slot.countLook : slot.subject ? slot.subject.look : null
    when: slot.subject !== null
    restoreMode: Binding.RestoreNone
  }

  Binding {
    target: slot
    property: "key"
    value: slot.isCount ? "+" : slot.subject ? slot.subject.key : ""
    when: slot.subject !== null
    restoreMode: Binding.RestoreNone
  }

  // 0 hidden behind the pill, 1 at its place, on the island's own spring.
  MorphSpring {
    id: reach

    target: slot.wants ? 1 : 0
  }

  // Scale and opacity come in on a short delayed fade and leave on a quicker one.
  property real presence: wants ? 1 : 0

  Behavior on presence {
    enabled: !Theme.reduceMotion

    SequentialAnimation {
      PauseAnimation {
        duration: slot.wants ? Theme.morphEnterDelay : 0
      }

      NumberAnimation {
        duration: slot.wants ? Theme.morphEnter : Theme.morphFarewell
        easing.type: Easing.OutCubic
      }
    }
  }

  // Standing, or still on its way out; the pill stays pushed aside for as long.
  readonly property bool occupies: wants || presence > 0.02

  // Where it rests, and where it starts from: the pill's edge, or the first circle's.
  readonly property real homeX: island.x + island.width + Theme.satelliteGap + index * step
  readonly property real hiddenX: previous ? previous.x : island.x + island.width - Theme.satelliteSize

  // Whether the card up is this circle's: its own activity's, or one it hides.
  readonly property bool cardHere: {
    if (Activities.cardKey === "" || key === "")
      return false;
    if (Activities.cardKey === key)
      return true;
    if (!isCount || Activities.cardKey === "+")
      return false;
    return Activities.hidden.some(function (a) {
      return a.key === Activities.cardKey;
    });
  }

  x: island.snap(hiddenX + (homeX - hiddenX) * reach.value)
  y: island.y
  width: Theme.satelliteSize
  height: Theme.satelliteSize
  z: 2 - index
  visible: presence > 0.001
  opacity: presence
  scale: 0.4 + 0.6 * presence

  Satellite {
    look: slot.look
    open: slot.cardHere
    onHoveredChanged: if (slot.key !== "")
      Activities.hoverSatellite(slot.key, hovered)
  }

  // The card hangs off whichever circle it belongs to.
  Binding {
    target: Activities
    property: "anchorX"
    value: slot.x
    when: slot.home && slot.cardHere
    restoreMode: Binding.RestoreNone
  }

  Binding {
    target: Activities
    property: "anchorY"
    value: slot.y + Theme.barMarginTop - Theme.oledShiftMax
    when: slot.home && slot.cardHere
    restoreMode: Binding.RestoreNone
  }
}
