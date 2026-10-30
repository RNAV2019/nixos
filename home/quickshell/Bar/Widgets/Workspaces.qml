import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Services
import qs.Ui

FrostedSurface {
  id: root

  readonly property var ids: WindowList.allIds

  function workspaceFor(id) {
    return WindowList.workspaceFor(id);
  }

  function focus(id) {
    Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
  }

  implicitWidth: row.implicitWidth + Theme.workspacePadding * 2
  implicitHeight: Theme.barHeight
  surfaceRadius: Theme.workspaceRadius

  Behavior on implicitWidth {
    enabled: !Theme.reduceMotion

    MicroSpring {}
  }

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

        width: isActive ? Theme.workspaceSlotActiveWidth : Theme.workspaceSlotWidth
        height: Theme.workspaceSlotHeight
        radius: Theme.workspaceSlotRadius
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: "Workspace " + slot.modelData
        Accessible.focusable: true
        Accessible.focused: slot.activeFocus
        Accessible.onPressAction: root.focus(slot.modelData)
        color: {
          if (isActive)
            return Theme.accent;
          if (isUrgent)
            return Theme.urgent;
          return mouse.containsMouse ? Theme.highlightHigh : Theme.overlay;
        }

        Behavior on width {
          enabled: !Theme.reduceMotion

          MicroSpring {}
        }

        Behavior on color {
          Tint {}
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
