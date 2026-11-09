import QtQuick
import qs.Commons

// A two-state switch. Off is a highlightMed track that steps up under the pointer; on is the
// accent, lifted the way a filled pill is. `enabled: false` dims it and ignores its clicks.
//
// The knob stretches toward where it is going and settles round, as the switches of macOS and iOS
// do: its two edges are two springs, the one in front the quicker. Held, it leans a few pixels
// toward the side a click would send it.
ButtonBase {
  id: root

  morphRole: "switch"

  signal toggled(bool value)

  implicitWidth: Theme.switchWidth
  implicitHeight: Theme.switchHeight

  accessibleRole: Accessible.CheckBox
  accessibleName: "Switch"
  checkable: true
  Accessible.onToggleAction: root.activate()
  onClicked: root.toggled(!root.checked)

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: {
      var lit = root.hovered || root.pressed;
      if (root.checked)
        return Qt.lighter(Theme.accentFill, lit ? Theme.fillLift : 1);
      return Theme.lift(lit ? Theme.liftOff + Theme.liftHover - Theme.liftTile : Theme.liftOff);
    }

    Behavior on color {
      Tint {}
    }
  }

  Rectangle {
    id: knob

    // The room the knob crosses. The edges are springs over 0..1 of it, not over pixels, so a
    // switch that is laid out late does not slide into place.
    readonly property real travel: Math.max(0, root.width - Theme.switchKnob - Theme.switchInset * 2)
    readonly property real lean: root.pressed && travel > 0 ? Theme.switchHeldWiden / travel : 0
    readonly property string who: root.toString().replace(/^.*\(0x([0-9a-f]+)\).*$/, "$1")

    y: Theme.switchInset
    x: Theme.switchInset + leftEdge.value * travel
    // Never narrower than round, whatever the two springs are doing.
    width: Theme.switchKnob + Math.max(0, rightEdge.value - leftEdge.value) * travel
    height: Theme.switchKnob
    radius: height / 2
    color: root.checked ? Theme.inkOnAccent : Theme.inkPrimary

    // With the track's tint, not ahead of it in one frame.
    Behavior on color {
      Tint {}
    }

    // Going on, the right edge leads and the left follows at the pace the knob always had; going
    // off, the other way round. A click that reverses it mid-way swaps the paces and keeps both
    // edges' speeds, so the stretch changes side without a jump.
    ProgressSpring {
      id: leftEdge

      target: root.checked ? 1 - knob.lean : 0
      omega: root.checked ? Theme.microOmega : Theme.microOmega * Theme.switchLead
      label: "switch." + knob.who + ".l"
    }

    ProgressSpring {
      id: rightEdge

      target: root.checked ? 1 : knob.lean
      omega: root.checked ? Theme.microOmega * Theme.switchLead : Theme.microOmega
      label: "switch." + knob.who + ".r"
    }
  }
}
