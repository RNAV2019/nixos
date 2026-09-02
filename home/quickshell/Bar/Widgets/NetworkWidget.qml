import QtQuick
import qs.Commons
import qs.Services

IconWidget {
  id: root

  readonly property var activeWifi: NetworkInfo.activeNetwork
  readonly property bool onEthernet: NetworkInfo.onEthernet

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
