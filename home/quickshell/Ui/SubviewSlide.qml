import QtQuick
import qs.Commons

// The slide between a panel's home view and one sub-view, as the control centre does it:
// drilling in pushes the home view out to the left and the sub-view in from the right, backing
// out reverses it. There is no cross-fade; the card clips what is off it.
//
// One ProgressSpring (the island's pace, solved per frame) carries both views, so they stay
// edge to edge all the way across. Hand it the two views as `home` and `sub`; it owns their `x`
// (give them no x of their own; a view narrower than the slide is centred with `homeBase` and
// `subBase`) and their `visible`: a view the slide has settled away from is hidden, so it takes no
// input and no focus. Both are shown while the slide is moving.
//
// A sub-view built off the frame clock (a Loader) sets `subReady` from its status: the target
// waits for it, so the home view holds still rather than sliding out to an empty pane.
//
// `name` tells this slide from the others in the motion log (QS_MOTION_LOG=1): unique per
// instance, e.g. "nearby" or "phone".
Item {
  id: root

  property Item home: null
  property Item sub: null
  property bool subShown: false
  property bool subReady: true
  // One slide's length, the card's width unless the panel says otherwise.
  property real travel: width
  // Where each view rests (its x at progress 0 for `home`, at 1 for `sub`), for a view narrower
  // than the slide that sits centred in it.
  property real homeBase: 0
  property real subBase: 0
  property string name: ""

  // 0 with the home view in place, 1 with the sub-view in place.
  readonly property real progress: spring.value
  // True once the spring has come to rest, at either end.
  readonly property bool settled: !spring.running
  readonly property bool toSub: subShown && subReady

  ProgressSpring {
    id: spring

    target: root.toSub ? 1 : 0
    label: root.name !== "" ? "subview." + root.name : ""
  }

  Binding {
    target: root.home
    property: "x"
    value: root.homeBase - root.progress * root.travel
    when: root.home !== null
    restoreMode: Binding.RestoreNone
  }

  Binding {
    target: root.sub
    property: "x"
    value: root.subBase + (1 - root.progress) * root.travel
    when: root.sub !== null
    restoreMode: Binding.RestoreNone
  }

  Binding {
    target: root.home
    property: "visible"
    value: !(root.settled && root.toSub)
    when: root.home !== null
    restoreMode: Binding.RestoreNone
  }

  Binding {
    target: root.sub
    property: "visible"
    value: !(root.settled && !root.toSub)
    when: root.sub !== null
    restoreMode: Binding.RestoreNone
  }
}
