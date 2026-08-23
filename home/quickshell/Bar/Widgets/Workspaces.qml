import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons

Rectangle {
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
  radius: Theme.workspaceRadius
  color: Theme.base

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Theme.workspaceGap

    Repeater {
      model: root.ids

      Rectangle {
        id: dot

        required property int modelData

        readonly property var ws: root.workspaceFor(modelData)
        readonly property bool isActive: ws !== null && ws.active
        readonly property bool isUrgent: ws !== null && ws.urgent

        width: isActive ? 36 : 20
        height: 16
        radius: height / 2
        color: isActive ? Theme.love : (mouse.containsMouse ? Theme.highlightMed : Theme.overlay)

        Behavior on width {
          NumberAnimation {
            duration: Theme.animFast
            easing.type: Easing.InOutQuad
          }
        }
        Behavior on color {
          ColorAnimation {
            duration: Theme.animFast
            easing.type: Easing.InOutQuad
          }
        }

        MouseArea {
          id: mouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + dot.modelData + " })")
        }
      }
    }
  }
}
