pragma Singleton

import QtQuick
import Quickshell

// The icons StrokeIcon draws. Each is a Material Symbols Rounded name, the shell's one icon
// set (Commons/Icons.qml), except the few marks Material has no counterpart for: board 13's
// submit arrow and Caps Lock, the Android and Apple platform marks and the battery outline the
// plugged-in moment fills itself. Those stay 24-grid SVG path data.
Singleton {
  readonly property string arrowUp: "arrow_upward"
  readonly property string arrowDown: "arrow_downward"
  // Board 13's submit arrow and Caps Lock mark, drawn there on 18 and 14 grids.
  readonly property string arrowRight: "M4.67 12h14.67M13.33 6l6 6-6 6"
  readonly property string capsLock: "M12 3.09L3.77 12h4.8v5.14h6.86V12h4.8zM8.57 21.26h6.86"
  readonly property string upload: "upload"
  readonly property string download: "download"
  readonly property string plus: "add"
  readonly property string x: "close"
  readonly property string check: "check"
  // The island's privacy marks.
  readonly property string camera: "videocam"
  readonly property string microphone: "mic"

  // The control centre's charge tile: Fast, Standard and the limiting mode.
  readonly property string battery: "battery_android_full"
  readonly property string zap: "bolt"
  readonly property string leaf: "eco"
  // The plugged-in moment's bare battery outline, whose fill it draws itself, and the sign-in
  // moment's Wi-Fi.
  readonly property string batteryOutline: "M4 7h12a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2zM22 11v2"
  readonly property string wifi: "wifi"
  // The rebuild pill's snowflake (NixOS) and failure cross.
  readonly property string snowflake: "ac_unit"
  readonly property string circleX: "cancel"

  readonly property string wifiOff: "wifi_off"

  // Drawn from the boards: the Android dome glyph and the filled Apple logo mark.
  readonly property string robotHead: "M4.5 17C4.5 12.86 7.86 9.5 12 9.5C16.14 9.5 19.5 12.86 19.5 17L4.5 17M7.5 8.6L6 6.2M16.5 8.6L18 6.2M9 13.2L9.01 13.2M15 13.2L15.01 13.2"
  readonly property string apple: "M16.4 12.7C16.4 10.4 18.3 9.3 18.4 9.2C17.3 7.6 15.6 7.4 15 7.4C13.6 7.2 12.2 8.3 11.5 8.3C10.8 8.3 9.7 7.5 8.5 7.5C7 7.5 5.5 8.4 4.7 9.8C3.1 12.6 4.3 16.9 5.9 19.2C6.7 20.3 7.6 21.6 8.8 21.5C10 21.5 10.4 20.8 11.8 20.8C13.2 20.8 13.6 21.5 14.8 21.5C16.1 21.5 16.9 20.4 17.6 19.2C18.5 17.9 18.9 16.6 18.9 16.6C18.9 16.6 16.4 15.6 16.4 15.6ZM14.2 5.9C14.8 5.1 15.3 4.1 15.2 3C14.3 3 13.1 3.6 12.5 4.4C11.9 5.1 11.4 6.1 11.5 7.1C12.5 7.2 13.6 6.6 14.2 5.9Z"

  // Nearby's device plates.
  readonly property string smartphone: "smartphone"
  readonly property string tablet: "tablet_android"
  readonly property string laptop: "laptop"

  // Nearby's file and folder glyphs, and the file picker's "N marked" counter.
  readonly property string fileText: "description"
  readonly property string file: "draft"
  readonly property string fileArchive: "folder_zip"

  readonly property string image: "image"

  readonly property string timer: "timer"

  readonly property string listChecks: "checklist"

  readonly property string folder: "folder"
}
