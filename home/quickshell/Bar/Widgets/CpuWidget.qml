import QtQuick
import qs.Commons
import qs.Services

IconWidget {
  id: root

  glyph: Icons.cpu
  readonly property string tooltip: "CPU " + Math.round(SystemStats.cpuUsage * 100) + "%   RAM " + Math.round(SystemStats.memoryUsage * 100) + "%"
}
