import QtQuick
import qs.Commons

// A two-state switch. Off is a highlightMed track that steps up under the pointer; on is the
// accent, lifted the way a filled pill is. `enabled: false` dims it and ignores its clicks.
ButtonBase {
  id: root

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
    y: Theme.switchInset
    x: Theme.switchInset + knob.value * (root.width - width - Theme.switchInset * 2)
    width: Theme.switchKnob
    height: width
    radius: height / 2
    color: root.checked ? Theme.inkOnAccent : Theme.inkPrimary

    ProgressSpring {
      id: knob

      target: root.checked ? 1 : 0
      omega: Theme.microOmega
      label: "switch." + root.toString().replace(/^.*\(0x([0-9a-f]+)\).*$/, "$1")
    }
  }
}
