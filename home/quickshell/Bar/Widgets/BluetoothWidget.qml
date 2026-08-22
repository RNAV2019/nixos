import QtQuick
import Quickshell.Bluetooth
import qs.Commons

IconWidget {
  id: root

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property int connectedCount: {
    if (!adapter)
      return 0;
    var n = 0;
    for (var i = 0; i < adapter.devices.values.length; i++) {
      if (adapter.devices.values[i].connected)
        n++;
    }
    return n;
  }

  glyph: {
    if (!adapter)
      return Icons.bluetoothNoAdapter;
    if (!adapter.enabled)
      return Icons.bluetoothOff;
    return connectedCount > 0 ? Icons.bluetoothConnected : Icons.bluetoothOn;
  }

  readonly property string tooltip: adapter ? "Devices connected: " + connectedCount : "No bluetooth controller"
}
