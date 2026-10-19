pragma Singleton

import QtQuick
import Quickshell

// The Nearby panel's icons, as 24-grid path data for StrokeIcon. Icons match the
// glyphs in Penpot boards 16a-16g: most keep their Lucide source (ISC-licensed,
// https://lucide.dev), drawn as round-capped stroke marks; where Lucide diverged
// from the boards the glyph is recreated from the board's own geometry. Paths are
// kept on the 24 grid - StrokeIcon scales them to whatever size the board calls for.
Singleton {
  // Lucide (matches the boards 1:1).
  readonly property string arrowUp: "M5 12l7-7 7 7M12 19V5"
  readonly property string arrowDown: "M12 5v14M19 12l-7 7-7-7"
  // Board 13's submit arrow and Caps Lock mark, drawn there on 18 and 14 grids.
  readonly property string arrowRight: "M4.67 12h14.67M13.33 6l6 6-6 6"
  readonly property string capsLock: "M12 3.09L3.77 12h4.8v5.14h6.86V12h4.8zM8.57 21.26h6.86"
  readonly property string upload: "M12 3v12M17 8l-5-5-5 5M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"
  readonly property string download: "M12 15V3M7 10l5 5 5-5M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"
  readonly property string plus: "M5 12h14M12 5v14"
  readonly property string x: "M18 6L6 18M6 6l12 12"
  readonly property string check: "M20 6L9 17l-5-5"
  // The island's privacy marks, Lucide video and mic.
  readonly property string camera: "M16 13l5.223 3.482a.5.5 0 0 0 .777-.416V7.87a.5.5 0 0 0-.752-.432L16 10.5M4 6h10a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2z"
  readonly property string microphone: "M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3zM19 10v2a7 7 0 0 1-14 0v-2M12 19v3"

  // Lucide wifi-off - the board's arcs land on the same curve ends.
  readonly property string wifiOff: "M12 20h.01M8.5 16.429a5 5 0 0 1 7 0M5 12.859a10 10 0 0 1 5.17-2.69M19 12.859a10 10 0 0 0-2.007-1.523M2 8.82a15 15 0 0 1 4.177-2.643M22 8.82a15 15 0 0 0-11.288-3.764M2 2l20 20"

  // Recreated from the boards: the Android dome glyph (Lucide's `bot` is a
  // different robot) and the filled Apple logo mark.
  readonly property string robotHead: "M4.5 17C4.5 12.86 7.86 9.5 12 9.5C16.14 9.5 19.5 12.86 19.5 17L4.5 17M7.5 8.6L6 6.2M16.5 8.6L18 6.2M9 13.2L9.01 13.2M15 13.2L15.01 13.2"
  readonly property string apple: "M16.4 12.7C16.4 10.4 18.3 9.3 18.4 9.2C17.3 7.6 15.6 7.4 15 7.4C13.6 7.2 12.2 8.3 11.5 8.3C10.8 8.3 9.7 7.5 8.5 7.5C7 7.5 5.5 8.4 4.7 9.8C3.1 12.6 4.3 16.9 5.9 19.2C6.7 20.3 7.6 21.6 8.8 21.5C10 21.5 10.4 20.8 11.8 20.8C13.2 20.8 13.6 21.5 14.8 21.5C16.1 21.5 16.9 20.4 17.6 19.2C18.5 17.9 18.9 16.6 18.9 16.6C18.9 16.6 16.4 15.6 16.4 15.6ZM14.2 5.9C14.8 5.1 15.3 4.1 15.2 3C14.3 3 13.1 3.6 12.5 4.4C11.9 5.1 11.4 6.1 11.5 7.1C12.5 7.2 13.6 6.6 14.2 5.9Z"

  // Recreated device plates - narrower bodies with a home bar, not a dot.
  readonly property string smartphone: "M9.73 2.5L14.27 2.5A2.73 2.73 0 0 1 17 5.23L17 18.77A2.73 2.73 0 0 1 14.27 21.5L9.73 21.5A2.73 2.73 0 0 1 7 18.77L7 5.23A2.73 2.73 0 0 1 9.73 2.5ZM11 18.5L13 18.5"
  readonly property string tablet: "M7.23 3L16.77 3A2.73 2.73 0 0 1 19.5 5.73L19.5 18.27A2.73 2.73 0 0 1 16.77 21L7.23 21A2.73 2.73 0 0 1 4.5 18.27L4.5 5.73A2.73 2.73 0 0 1 7.23 3ZM11 18L13 18"
  readonly property string laptop: "M4 6.5C4 5.67 4.67 5 5.5 5L18.5 5C19.33 5 20 5.67 20 6.5L20 16L4 16L4 6.5M2 19L22 19"

  // Recreated file glyphs - sharp fold notch, board line lengths and dot slot.
  readonly property string fileText: "M14 3L7 3C5.9 3 5 3.9 5 5L5 19C5 20.1 5.9 21 7 21L17 21C18.1 21 19 20.1 19 19L19 8L14 3M14 3L14 8L19 8M9 13L15 13M9 17L13 17"
  readonly property string file: "M14 3L7 3C5.9 3 5 3.9 5 5L5 19C5 20.1 5.9 21 7 21L17 21C18.1 21 19 20.1 19 19L19 8L14 3M14 3L14 8L19 8"
  readonly property string fileArchive: "M14 3L7 3C5.9 3 5 3.9 5 5L5 19C5 20.1 5.9 21 7 21L17 21C18.1 21 19 20.1 19 19L19 8L14 3M14 3L14 8L19 8M11 6L12 6M11 9L12 9M11 12L12 12M10.5 15L12.5 15L12.5 18L10.5 18L10.5 15"

  // Recreated: small square dot at the top right, polyline hills in a wide frame.
  readonly property string image: "M6.33 4L17.67 4A3.33 3.33 0 0 1 21 7.33L21 16.67A3.33 3.33 0 0 1 17.67 20L6.33 20A3.33 3.33 0 0 1 3 16.67L3 7.33A3.33 3.33 0 0 1 6.33 4ZM4 17L9 12L13 16L15.5 13.5L20 18M15.5 8.5L15.51 8.5"

  // Recreated timer chip: hand hangs below the center as on the board.
  readonly property string timer: "M20 13A8 8 0 1 1 4 13A8 8 0 1 1 20 13ZM12 9L12 13L14.5 15M10 2L14 2"

  // Lucide list-checks, the file picker's "N marked" counter.
  readonly property string listChecks: "M3 17l2 2 4-4M3 7l2 2 4-4M13 6h8M13 12h8M13 18h8"

  // Recreated folder: straight tab step on a wide rounded body.
  readonly property string folder: "M3 7C3 5.9 3.9 5 5 5L9 5L11 7L19 7C20.1 7 21 7.9 21 9L21 17C21 18.1 20.1 19 19 19L5 19C3.9 19 3 18.1 3 17L3 7"
}
