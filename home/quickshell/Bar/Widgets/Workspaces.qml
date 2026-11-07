import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

FrostedSurface {
  id: root

  readonly property int persistent: 5

  readonly property var ids: {
    var seen = {};
    var out = [];
    for (var i = 1; i <= persistent; i++) {
      seen[i] = true;
      out.push(i);
    }
    for (var j = 0; j < Hyprland.workspaces.values.length; j++) {
      var id = Hyprland.workspaces.values[j].id;
      if (id > 0 && !seen[id]) {
        seen[id] = true;
        out.push(id);
      }
    }
    out.sort(function (a, b) {
      return a - b;
    });
    return out;
  }

  function workspaceFor(id) {
    for (var i = 0; i < Hyprland.workspaces.values.length; i++) {
      if (Hyprland.workspaces.values[i].id === id)
        return Hyprland.workspaces.values[i];
    }
    return null;
  }

  function focus(id) {
    Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
  }

  // The pill follows the row, and each slot springs its own width, so pill and dots move on one clock.
  implicitWidth: row.implicitWidth + Theme.workspacePadding * 2
  implicitHeight: Theme.barHeight
  surfaceRadius: Theme.workspaceRadius

  Row {
    id: row

    anchors.centerIn: parent
    spacing: Theme.workspaceGap

    Repeater {
      model: root.ids

      Rectangle {
        id: slot

        required property int modelData

        readonly property var ws: root.workspaceFor(modelData)
        readonly property bool isActive: ws !== null && ws.active
        readonly property bool isUrgent: ws !== null && ws.urgent

        width: slotSpring.value
        height: Theme.workspaceSlotHeight
        radius: Theme.workspaceSlotRadius
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: "Workspace " + slot.modelData
        Accessible.focusable: true
        Accessible.focused: slot.activeFocus
        Accessible.onPressAction: root.focus(slot.modelData)
        MorphSpring {
          id: slotSpring

          target: slot.isActive ? Theme.workspaceSlotActiveWidth : Theme.workspaceSlotWidth
          omega: Theme.microOmega
          label: "ws.slot." + slot.modelData
        }

        color: {
          if (isActive)
            return Theme.accent;
          if (isUrgent)
            return Theme.urgent;
          return mouse.containsMouse ? Theme.highlightHigh : Theme.overlay;
        }

        Behavior on color {
          Tint {}
        }

        // The active slot blooms softly in the accent, the shell's only glow (saneAspect's).
        RectangularShadow {
          anchors.fill: parent
          z: -1
          radius: slot.radius
          blur: Theme.workspaceGlowBlur
          color: Theme.withAlpha(Theme.accent, Theme.workspaceGlowAlpha)
          opacity: slot.isActive ? 1 : 0
          visible: opacity > 0

          Behavior on opacity {
            NumberAnimation {
              duration: Theme.duration(Theme.tintFade)
              easing.type: Easing.OutQuad
            }
          }
        }

        MouseArea {
          id: mouse

          anchors.fill: parent
          activeFocusOnTab: true
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onPressed: slot.forceActiveFocus()
          onClicked: root.focus(slot.modelData)
        }
      }
    }
  }
}
