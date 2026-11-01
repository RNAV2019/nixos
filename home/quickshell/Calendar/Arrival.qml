import QtQuick
import qs.Commons

// A month or day stepping in: its layer fades up and slides the last of the way from the side it
// came from. CalendarPanel sets the travel, signed by the direction of the step.
ParallelAnimation {
  id: arrival

  property Item layer
  property real travel: 0

  NumberAnimation {
    target: arrival.layer
    property: "opacity"
    from: 0
    to: 1
    duration: Theme.duration(Theme.morphEnter)
    easing.type: Easing.OutCubic
  }

  NumberAnimation {
    target: arrival.layer
    property: "shift"
    from: arrival.travel
    to: 0
    duration: Theme.duration(Theme.morphEnter)
    easing.type: Easing.OutCubic
  }
}
