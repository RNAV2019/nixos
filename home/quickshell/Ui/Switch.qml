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
      return Theme.withAlpha(Theme.highlightMed, lit ? Theme.groundHoverAlpha : Theme.groundRestAlpha);
    }

    Behavior on color {
      Tint {}
    }
  }

  Rectangle {
    y: Theme.switchInset
    x: root.checked ? root.width - width - Theme.switchInset : Theme.switchInset
    width: Theme.switchKnob
    height: width
    radius: height / 2
    color: root.checked ? Theme.inkOnAccent : Theme.inkPrimary

    Behavior on x {
      enabled: !Theme.reduceMotion

      MicroSpring {}
    }
  }
}
