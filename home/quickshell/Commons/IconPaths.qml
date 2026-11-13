pragma Singleton

import QtQuick
import Quickshell

// The icons StrokeIcon draws. Each is a Material Symbols Rounded name, the shell's one icon
// set (Commons/Icons.qml), except the few marks Material has no counterpart for or draws
// otherwise than the shell wants: the login pill's submit arrow, the lock screen's outlined
// padlock, the Android and Apple platform marks, the battery outline the plugged-in moment
// fills itself and the Wi-Fi mark. Those stay 24-grid SVG path data.
Singleton {
  readonly property string arrowUp: "arrow_upward"
  readonly property string arrowDown: "arrow_downward"
  // The login pill's submit arrow.
  readonly property string arrowRight: "M4.67 12h14.67M13.33 6l6 6-6 6"
  // The locked island's padlock: an outline with its keyhole, where the shell's set is filled.
  readonly property string lockOutline: "M7.6 10.2h8.8a2.4 2.4 0 0 1 2.4 2.4v5.8a2.4 2.4 0 0 1-2.4 2.4H7.6a2.4 2.4 0 0 1-2.4-2.4v-5.8a2.4 2.4 0 0 1 2.4-2.4zM8.5 10.2V7.4a3.5 3.5 0 0 1 7 0v2.8M12 15.2v0.6"
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
  // The plugged-in moment's bare battery outline, whose fill it draws itself.
  readonly property string batteryOutline: "M4 7h12a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2zM22 11v2"

  // The shell's Wi-Fi mark: a wedge under two arcs, three parts with even gaps between them,
  // every end round. All of it turns about (12, 20.25) and lies between two lines 48 degrees
  // either side of straight up: the wedge is that sector out to 4.6 with its corners rounded
  // (1 at the arc, 0.7 at the point), and the arcs are bands 2.8 wide about radii 8.8 and
  // 14.4 with round ends, so the gaps are 2.8 too. Filled outlines, not strokes, so one fill
  // draws all three and the mark can be lit in part (Ui/StrokeIcon.qml, the `|`).
  readonly property string wifiWedge: "M11.53 19.83 L9.43 17.94 A1 1 0 0 1 9.57 16.34 A4.6 4.6 0 0 1 14.43 16.34 A1 1 0 0 1 14.57 17.94 L12.47 19.83 A0.7 0.7 0 0 1 11.53 19.83Z"
  readonly property string wifiInner: "M5.6 12.31 A10.2 10.2 0 0 1 18.4 12.31 A1.4 1.4 0 0 1 16.64 14.49 A7.4 7.4 0 0 0 7.36 14.49 A1.4 1.4 0 0 1 5.6 12.31Z"
  readonly property string wifiOuter: "M1.34 8.59 A15.8 15.8 0 0 1 22.66 8.59 A1.4 1.4 0 0 1 20.77 10.65 A13 13 0 0 0 3.23 10.65 A1.4 1.4 0 0 1 1.34 8.59Z"
  // The stroke through it with no link: a bar 2.2 wide with round ends, from (4.5, 4.85) to
  // (19.5, 19.85).
  readonly property string wifiSlash: "M5.28 4.07 L20.28 19.07 A1.1 1.1 0 0 1 18.72 20.63 L3.72 5.63 A1.1 1.1 0 0 1 5.28 4.07Z"

  // The mark by how much of it is lit: the wedge, the wedge and the inner arc, all three.
  // What is not lit is still drawn, dim.
  readonly property var wifiLevels: [wifiWedge + "|" + wifiInner + wifiOuter, wifiWedge + wifiInner + "|" + wifiOuter, wifiWedge + wifiInner + wifiOuter + "|"]
  // All of it lit: Wi-Fi as a thing, with no signal to report (a notice, the phone's Wi-Fi).
  readonly property string wifi: wifiLevels[2]
  // No link, or Wi-Fi off: the whole mark dim, struck through.
  readonly property string wifiOff: wifiSlash + "|" + wifiWedge + wifiInner + wifiOuter
  // The rebuild pill's snowflake (NixOS) and failure cross.
  readonly property string snowflake: "ac_unit"
  readonly property string circleX: "cancel"

  readonly property string folderOff: "folder_off"
  readonly property string phoneOff: "phonelink_off"

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
