import QtQuick
import Quickshell.Networking
import qs.Commons

IconWidget {
  id: root

  readonly property var wifiDevice: {
    for (var i = 0; i < Networking.devices.values.length; i++) {
      var d = Networking.devices.values[i];
      if (d.type === DeviceType.Wifi)
        return d;
    }
    return null;
  }

  readonly property var wiredDevice: {
    for (var i = 0; i < Networking.devices.values.length; i++) {
      var d = Networking.devices.values[i];
      if (d.type === DeviceType.Wired)
        return d;
    }
    return null;
  }

  readonly property var activeWifi: {
    if (!wifiDevice)
      return null;
    for (var i = 0; i < wifiDevice.networks.values.length; i++) {
      if (wifiDevice.networks.values[i].connected)
        return wifiDevice.networks.values[i];
    }
    return null;
  }

  readonly property bool onEthernet: wiredDevice !== null && wiredDevice.connected

  glyph: {
    if (onEthernet)
      return Icons.ethernet;
    if (!activeWifi)
      return Icons.networkOff;
    return Icons.step(Icons.wifi, activeWifi.signalStrength * 100);
  }

  label: onEthernet ? "" : (activeWifi ? activeWifi.name : "")

  readonly property string tooltip: {
    if (onEthernet)
      return "Connected";
    if (!activeWifi)
      return "Disconnected";
    // Quickshell's Networking service does not expose channel frequency.
    return activeWifi.name + " — " + Math.round(activeWifi.signalStrength * 100) + "%";
  }
}
