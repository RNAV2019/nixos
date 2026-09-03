pragma Singleton

import QtQuick
import Quickshell

// Keep these Nerd Font glyphs in a UTF-8 source file; some are non-BMP.
Singleton {
  readonly property string nix: "❄"
  readonly property string calendar: "󰃭"
  readonly property string clock: ""
  readonly property string cpu: "󰍛"
  readonly property string claude: ""

  readonly property string monitor: "󰍹"
  readonly property string monitorMultiple: "󰍺"
  readonly property string monitorOff: "󰶐"

  readonly property string expandMore: "󰅀"
  readonly property string expandLess: "󰅃"

  readonly property string mprisPlaying: "󰎇"
  readonly property string mprisPaused: "󰏤"

  readonly property var wifi: ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]
  readonly property string ethernet: "󰀂"
  readonly property string networkOff: "󰤮"

  readonly property string bluetoothOn: ""
  readonly property string bluetoothOff: "󰂲"
  readonly property string bluetoothConnected: "󰂱"
  readonly property string bluetoothNoAdapter: ""

  readonly property string volumeMuted: ""
  readonly property string headphone: ""
  readonly property var volume: ["", " ", " "]

  readonly property string brightness: "󰃟"
  readonly property string keyboardBacklight: "󰌌"

  readonly property var batteryCharging: ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]
  readonly property var batteryDefault: ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
  readonly property string batteryFull: "󰂅"

  // Map a 0-100 percentage to a clamped icon index.
  function step(icons, percent) {
    if (!icons || icons.length === 0)
      return "";
    var i = Math.floor((percent / 100) * icons.length);
    return icons[Math.max(0, Math.min(icons.length - 1, i))];
  }
}
