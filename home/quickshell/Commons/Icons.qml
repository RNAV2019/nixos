pragma Singleton

import QtQuick
import Quickshell

// Material Symbols Rounded, by ligature name: a Text in Theme.iconFont draws the glyph. One
// icon set for the whole shell, as saneAspect has it, filled at weight 400 everywhere. A name
// the font lacks shows as its letters, so check new ones at https://fonts.google.com/icons.
Singleton {
  readonly property string search: "search"

  // The launcher's '=' mode: one per kind of answer.
  readonly property string calculator: "calculate"
  readonly property string clock: "schedule"
  readonly property string calendar: "calendar_today"
  readonly property string numberBase: "123"
  // Its clipboard history.
  readonly property string clipboard: "content_paste"
  // Its emoji and symbol picker.
  readonly property string emoji: "mood"

  readonly property string chevronLeft: "chevron_left"
  readonly property string chevronRight: "chevron_right"

  // Wi-Fi is not Material's: the shell draws its own mark (Commons/IconPaths.qml), which
  // wifiGlyph below lights to a signal strength.
  readonly property string wifiOn: IconPaths.wifi
  readonly property string networkOff: IconPaths.wifiOff
  // The strength (0..1) from which the inner arc is lit, and the outer one. NetworkManager's
  // scale: about 0.3 is the weakest link that still carries anything, 0.6 a good one.
  readonly property real wifiFair: 0.3
  readonly property real wifiGood: 0.6
  readonly property string ethernet: "settings_ethernet"
  readonly property string lock: "lock"
  readonly property string reboot: "restart_alt"
  readonly property string shutdown: "power_settings_new"
  readonly property string person: "person"

  // An image clip in the clipboard history.
  readonly property string image: "image"

  readonly property string bluetoothOn: "bluetooth"
  readonly property string bluetoothOff: "bluetooth_disabled"
  readonly property string bluetoothConnected: "bluetooth_connected"
  readonly property string bluetoothNoAdapter: "bluetooth_disabled"

  // Peripherals BlueZ reports; matched against the device's advertised icon.
  readonly property string phone: "smartphone"
  readonly property string keyboard: "keyboard"
  readonly property string mouse: "mouse"

  // The phone panel (Phone/PhonePanel.qml): KDE Connect's actions, the phone's mobile signal
  // by bars (0-4), clipboard rows and notification avatars.
  readonly property string ringVolume: "ring_volume"
  readonly property string uploadFile: "upload_file"
  readonly property string folderOpen: "folder_open"
  readonly property var cellular: ["signal_cellular_0_bar", "signal_cellular_1_bar", "signal_cellular_2_bar", "signal_cellular_3_bar", "signal_cellular_4_bar"]
  readonly property string cellularOff: "signal_cellular_off"
  readonly property string link: "link"
  readonly property string notes: "notes"
  readonly property string copy: "content_copy"
  readonly property string mail: "mail"
  readonly property string chat: "chat"
  readonly property string notifications: "notifications"
  readonly property string info: "info"

  readonly property string volumeMuted: "volume_off"
  readonly property string headphone: "headphones"
  readonly property var volume: ["volume_mute", "volume_down", "volume_up"]

  readonly property string back: "arrow_back"
  readonly property string close: "close"
  readonly property string refresh: "refresh"
  readonly property string check: "check"
  readonly property string peaceOn: "do_not_disturb_on"
  readonly property string peaceOff: "do_not_disturb_off"
  readonly property string nightLight: "dark_mode"
  readonly property string previous: "skip_previous"
  readonly property string next: "skip_next"
  readonly property string play: "play_arrow"
  readonly property string pause: "pause"
  // The Now playing panel's quiet pair; repeat shows the one track when it is that one it repeats.
  readonly property string shuffle: "shuffle"
  readonly property string repeat: "repeat"
  readonly property string repeatOne: "repeat_one"
  readonly property string microphone: "mic"
  readonly property string microphoneMuted: "mic_off"

  readonly property string record: "radio_button_checked"
  readonly property string stop: "stop"
  readonly property string captureScreen: "screenshot_monitor"
  readonly property string captureWindow: "web_asset"
  readonly property string captureRegion: "crop_free"

  readonly property string monitor: "desktop_windows"
  readonly property string laptop: "laptop"
  readonly property string restore: "undo"

  // Edges or centres lined up along one axis.
  readonly property string alignLeft: "align_horizontal_left"
  readonly property string alignCentre: "align_horizontal_center"
  readonly property string alignRight: "align_horizontal_right"
  readonly property string alignTop: "align_vertical_top"
  readonly property string alignMiddle: "align_vertical_center"
  readonly property string alignBottom: "align_vertical_bottom"

  readonly property string brightness: "brightness_6"
  readonly property string keyboardBacklight: "backlight_high"

  readonly property string bolt: "bolt"
  readonly property string contrast: "contrast"
  readonly property string batterySaver: "eco"

  // The hover card's weather (Services/Weather.qml), by what the sky is doing; a clear or
  // part-cloudy sky has a night form.
  readonly property string weatherClear: "clear_day"
  readonly property string weatherClearNight: "bedtime"
  readonly property string weatherPartCloud: "partly_cloudy_day"
  readonly property string weatherPartCloudNight: "partly_cloudy_night"
  readonly property string weatherCloud: "cloud"
  readonly property string weatherFog: "foggy"
  readonly property string weatherRain: "rainy"
  readonly property string weatherSnow: "weather_snowy"
  readonly property string weatherThunder: "thunderstorm"

  readonly property var batteryCharging: ["battery_android_bolt"]
  readonly property var batteryDefault: ["battery_android_0", "battery_android_1", "battery_android_2", "battery_android_3", "battery_android_4", "battery_android_5", "battery_android_6", "battery_android_full"]

  // The Wi-Fi mark lit to a signal strength (0..1) in three levels, the rest of it dim: the
  // wedge alone, the inner arc from wifiFair, the outer from wifiGood. Struck through with no
  // link.
  function wifiGlyph(strength, connected) {
    if (!connected)
      return networkOff;
    return IconPaths.wifiLevels[strength >= wifiGood ? 2 : strength >= wifiFair ? 1 : 0];
  }

  function bluetoothGlyph(off, connected) {
    return off ? bluetoothOff : connected ? bluetoothConnected : bluetoothOn;
  }

  // The media card's transport marks: "play", "pause", "next" or "previous".
  function transportGlyph(kind) {
    return kind === "pause" ? pause : kind === "next" ? next : kind === "previous" ? previous : play;
  }

  function step(icons, percent) {
    if (!icons || icons.length === 0)
      return "";
    var i = Math.floor((percent / 100) * icons.length);
    return icons[Math.max(0, Math.min(icons.length - 1, i))];
  }
}
