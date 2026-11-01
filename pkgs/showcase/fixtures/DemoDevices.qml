pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.UPower

// Made-up Wi-Fi networks, Bluetooth devices and battery for the showcase stage, in the shapes
// Quickshell's own objects have. showcase.sh points the shell's readers at this in place of
// NetworkManager, BlueZ and UPower, so nothing of the machine's real surroundings is drawn.
Singleton {
  id: root

  // ---- Wi-Fi ----

  property bool wifiEnabled: true

  readonly property var wifiDevice: QtObject {
    readonly property int type: DeviceType.Wifi
    readonly property string name: "wlan0"
    readonly property bool connected: true
    property bool scannerEnabled: false
    readonly property var networks: ({
        "values": root.networks
      })
  }

  function network(name, strength, secure, connected) {
    return {
      "name": name,
      "signalStrength": strength,
      "security": secure ? WifiSecurityType.Wpa2Psk : WifiSecurityType.Open,
      "connected": connected,
      "known": connected,
      "stateChanging": false,
      "device": root.wifiDevice
    };
  }

  readonly property var networks: [network("Labyrinth", 0.88, true, true), network("Minotaur 5G", 0.72, true, false), network("Thread", 0.61, true, false), network("Daedalus-Guest", 0.44, false, false), network("Ariadne's Thread", 0.37, true, false), network("Cretan Cafe", 0.21, false, false)]

  // What Networking.devices.values is: the Wi-Fi card, and no wired port.
  readonly property var devices: [wifiDevice]

  // ---- Bluetooth ----

  function device(name, address, icon, connected, paired, battery) {
    return {
      "name": name,
      "address": address,
      "icon": icon,
      "connected": connected,
      "paired": paired,
      "pairing": false,
      "state": connected ? BluetoothDeviceState.Connected : BluetoothDeviceState.Disconnected,
      "batteryAvailable": battery >= 0,
      "battery": battery
    };
  }

  readonly property var adapter: QtObject {
    property bool enabled: true
    property bool discovering: false
    readonly property var devices: ({
        "values": [root.device("Pixel Buds Pro", "00:00:5E:00:53:01", "audio-headset", true, true, 0.82), root.device("Keychron K3", "00:00:5E:00:53:02", "input-keyboard", false, true, -1), root.device("MX Master 3", "00:00:5E:00:53:03", "input-mouse", false, true, -1), root.device("JBL Flip 6", "00:00:5E:00:53:04", "audio-speakers", false, false, -1), root.device("Pixel 9", "00:00:5E:00:53:05", "phone", false, false, -1)]
      })
  }

  // ---- the launcher ----

  // The desktop entries it lists: what this desktop is made of, and not what the machine has.
  readonly property var apps: ["org.gnome.Nautilus", "com.mitchellh.ghostty", "Helix", "helium", "btop", "mpv", "org.pwmt.zathura", "org.pulseaudio.pavucontrol", "sonora", "org.kde.kdeconnect.app", "Handy", "blueman-manager"]

  // ---- a clock that runs ----

  // Date.now() stands still on the stage, and a rebuild's progress is made of the time that
  // passes, so the rebuild service reads this one instead.
  property real elapsed: 0

  Timer {
    interval: 20
    repeat: true
    running: true
    onTriggered: root.elapsed += 20
  }

  // ---- the battery ----

  readonly property var battery: QtObject {
    readonly property bool isLaptopBattery: true
    readonly property bool isPresent: true
    readonly property int state: UPowerDeviceState.Discharging
    readonly property real percentage: 0.78
    readonly property real changeRate: 7.4
    readonly property real timeToEmpty: 19800
    readonly property real timeToFull: 0
  }
}
