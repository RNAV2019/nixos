import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// The one left-anchored surface. It has to stay put while the island morphs
// beside it, so it never takes part in the island's own geometry.
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

  implicitWidth: row.implicitWidth + Theme.workspacePadding * 2
  implicitHeight: Theme.barHeight
  surfaceRadius: Theme.workspaceRadius

  Behavior on implicitWidth {
    Morph {}
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

        // The active workspace is the only one that carries the accent, and it
        // widens rather than brightening, so the row reads at a glance.
        width: isActive ? Theme.workspaceSlotActiveWidth : Theme.workspaceSlotWidth
        height: Theme.workspaceSlotHeight
        radius: Theme.workspaceSlotRadius
        color: {
          if (isActive)
            return Theme.accent;
          if (isUrgent)
            return Theme.urgent;
          return mouse.containsMouse ? Theme.highlightHigh : Theme.overlay;
        }

        Behavior on width {
          Morph {}
        }

        Behavior on color {
          ColorAnimation {
            duration: Theme.morphToggle
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.morphCurve
          }
        }

        MouseArea {
          id: mouse

          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + slot.modelData + " })")
        }
      }
    }
  }
}
