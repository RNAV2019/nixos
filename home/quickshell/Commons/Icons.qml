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

  readonly property string search: "󰍉"
  readonly property string application: "󰣆"

  readonly property string expandMore: "󰅀"
  readonly property string expandLess: "󰅃"
  readonly property string chevronLeft: "󰅁"
  readonly property string chevronRight: "󰅂"

  readonly property string mprisPlaying: "󰎇"
  readonly property string mprisPaused: "󰏤"

  readonly property var wifi: ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]
  readonly property string ethernet: "󰀂"
  readonly property string networkOff: "󰤮"
  readonly property string lock: "󰌾"
  readonly property string reboot: "󰜉"
  readonly property string shutdown: "󰐥"

  readonly property string bluetoothOn: ""
  readonly property string bluetoothOff: "󰂲"
  readonly property string bluetoothConnected: "󰂱"
  readonly property string bluetoothNoAdapter: ""

  readonly property string volumeMuted: ""
  readonly property string headphone: ""
  readonly property var volume: ["", " ", " "]

  // The control centre's own vocabulary.
  readonly property string back: "󰁍"
  readonly property string close: "󰅖"
  readonly property string settings: "󰒓"
  readonly property string refresh: "󰑐"
  readonly property string check: "󰄬"
  readonly property string peaceOn: "󰍶"
  readonly property string peaceOff: "󰂚"
  readonly property string nightLight: "󰖔"
  readonly property string previous: "󰒮"
  readonly property string next: "󰒭"
  readonly property string play: "󰐊"
  readonly property string pause: "󰏤"
  readonly property string microphone: "󰍬"
  readonly property string microphoneMuted: "󰍭"
  readonly property string bell: "󰂚"

  // The screen recorder. The ring-and-dot is the record mark wherever it
  // appears: the pill, the control centre tile and the saved notification.
  readonly property string record: "󰑊"
  readonly property string stop: "󰓛"
  readonly property string captureScreen: "󰍹"
  readonly property string captureWindow: "󰖯"
  readonly property string captureRegion: "󰆞"

  readonly property string brightness: "󰃟"
  readonly property string keyboardBacklight: "󰌌"

  // The power profiles card. Board 04b: the bolt and the half-circle are the
  // board's own outline-drawn glyphs, not their filled cousins.
  readonly property string bolt: "󱐋"
  readonly property string contrast: "󱎕"
  readonly property string batterySaver: "󰁹"

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
