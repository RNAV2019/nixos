pragma Singleton

import QtQuick
import Quickshell

// The icons StrokeIcon draws. Each is a Material Symbols Rounded name, the shell's one icon
// set (Commons/Icons.qml), except the few marks Material has no counterpart for: board 13's
// submit arrow and Caps Lock, the Android and Apple platform marks, the Claude spark and the
// battery outline the plugged-in moment fills itself. Those stay 24-grid SVG path data.
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
  // The share picker's Share button (its sources are the tools' monitor, app-window and crop).
  readonly property string screenShare: "screen_share"
  // The notification reply row sends with the plane (a group's chevron is chevronDown, turned over).
  readonly property string send: "send"
  // The island's privacy marks.
  readonly property string camera: "videocam"
  readonly property string microphone: "mic"

  // The polkit prompt's requester disc and details chevrons.
  readonly property string lock: "lock"
  readonly property string chevronRight: "chevron_right"
  readonly property string chevronDown: "expand_more"

  // The lock screen's glance row, transport and face scan; the live activities' controls use them too.
  readonly property string battery: "battery_android_full"
  readonly property string batteryCharging: "battery_android_bolt"
  // The control centre's charge tile: Fast, and the limiting mode.
  readonly property string zap: "bolt"
  readonly property string leaf: "eco"
  readonly property string skipBack: "skip_previous"
  readonly property string skipForward: "skip_next"
  readonly property string pause: "pause"
  readonly property string play: "play_arrow"
  readonly property string scanFace: "familiar_face_and_zone"

  readonly property string wifiOff: "wifi_off"

  // Drawn from the boards: the Android dome glyph and the filled Apple logo mark.
  readonly property string robotHead: "M4.5 17C4.5 12.86 7.86 9.5 12 9.5C16.14 9.5 19.5 12.86 19.5 17L4.5 17M7.5 8.6L6 6.2M16.5 8.6L18 6.2M9 13.2L9.01 13.2M15 13.2L15.01 13.2"
  readonly property string apple: "M16.4 12.7C16.4 10.4 18.3 9.3 18.4 9.2C17.3 7.6 15.6 7.4 15 7.4C13.6 7.2 12.2 8.3 11.5 8.3C10.8 8.3 9.7 7.5 8.5 7.5C7 7.5 5.5 8.4 4.7 9.8C3.1 12.6 4.3 16.9 5.9 19.2C6.7 20.3 7.6 21.6 8.8 21.5C10 21.5 10.4 20.8 11.8 20.8C13.2 20.8 13.6 21.5 14.8 21.5C16.1 21.5 16.9 20.4 17.6 19.2C18.5 17.9 18.9 16.6 18.9 16.6C18.9 16.6 16.4 15.6 16.4 15.6ZM14.2 5.9C14.8 5.1 15.3 4.1 15.2 3C14.3 3 13.1 3.6 12.5 4.4C11.9 5.1 11.4 6.1 11.5 7.1C12.5 7.2 13.6 6.6 14.2 5.9Z"

  // Nearby's device plates.
  readonly property string smartphone: "smartphone"
  readonly property string smartphoneCharging: "charging_station"
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

  // The screenshot tray and the screen tools.
  readonly property string crop: "crop"
  readonly property string appWindow: "web_asset"
  readonly property string monitor: "desktop_windows"
  readonly property string scanText: "document_scanner"
  readonly property string qrCode: "qr_code"
  readonly property string pipette: "colorize"
  // A still camera; `camera` above is the video glyph the privacy marks use.
  readonly property string photo: "photo_camera"
  readonly property string images: "photo_library"
  readonly property string pencilLine: "edit"
  readonly property string copy: "content_copy"
  // The phone card's Ring phone and Send files.
  readonly property string bellRing: "notifications_active"
  readonly property string folderOpen: "folder_open"
  readonly property string trash: "delete"
  readonly property string search: "search"
  readonly property string sparkles: "auto_awesome"
  readonly property string externalLink: "open_in_new"
  // The live activities' glyphs: the square of Stop, the cup of a break, and the bare
  // battery outline, whose fill the plugged-in moment draws itself.
  readonly property string square: "stop"
  readonly property string coffee: "coffee"
  readonly property string batteryOutline: "M4 7h12a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2zM22 11v2"
  // The Claude, rebuild and USB activities' glyphs; the spark of Claude is drawn.
  readonly property string claude: "M12 3v18M3 12h18M5.6 5.6l12.8 12.8M18.4 5.6L5.6 18.4"
  readonly property string snowflake: "ac_unit"
  readonly property string hardDrive: "hard_drive"
  readonly property string eject: "eject"
  readonly property string circleX: "cancel"
  readonly property string packageCheck: "inventory"
  readonly property string fileDiff: "difference"
  readonly property string scrollText: "receipt_long"
  readonly property string terminal: "terminal"
  readonly property string loaderCircle: "progress_activity"
  // The event card and moments, the sign-in moment and the launcher's timer rows.
  readonly property string calendarClock: "calendar_clock"
  readonly property string mapPin: "location_on"
  readonly property string wifi: "wifi"
  readonly property string repeat: "repeat"
}
