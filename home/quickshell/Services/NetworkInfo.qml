pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// The bar widget and the panel both need the same device lookups; evaluating
// them once here keeps a single scan of Networking.devices per change.
Singleton {
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

  readonly property var activeNetwork: {
    if (!wifiDevice)
      return null;
    for (var i = 0; i < wifiDevice.networks.values.length; i++) {
      if (wifiDevice.networks.values[i].connected)
        return wifiDevice.networks.values[i];
    }
    return null;
  }

  readonly property bool onEthernet: wiredDevice !== null && wiredDevice.connected

  readonly property var otherNetworks: {
    if (!wifiDevice)
      return [];
    var out = [];
    for (var i = 0; i < wifiDevice.networks.values.length; i++) {
      var n = wifiDevice.networks.values[i];
      if (!n.connected)
        out.push(n);
    }
    out.sort(function (a, b) {
      return b.signalStrength - a.signalStrength;
    });
    return out;
  }

  function secured(network) {
    return network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Unknown;
  }
}
