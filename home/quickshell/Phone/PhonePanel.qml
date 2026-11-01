import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.Commons
import qs.Nearby
import qs.Services
import qs.Ui

// The phone panel (board "Phone panel"), opened from the phone satellite: the phone drawn on
// the left with its time and notification stubs, and beside it a 3 x 2 grid, readings (battery,
// mobile, Wi-Fi: flat, nothing to press) over actions (ring, send files, browse: control tiles).
// The card is as tall as the phone and its inset. "Send files" grows the panel into Nearby's file
// picker; what it accepts goes to the phone through KDE Connect. The disc at the foot of the
// phone's screen grows it into the same picker to choose the picture drawn there. "Browse"
// mounts the phone's storage and opens it in the file manager; when the phone refuses, the tile
// takes the note's gold and a note under the grid says what to allow.
Variants {
  id: root

  model: Quickshell.screens

  IslandSurface {
    id: win

    key: "phone"

    property bool picking: false
    // "files" for Send files, "wallpaper" for the phone preview's picture.
    property string pickKind: "files"
    property string lastDir: ""

    // The home view keeps this column while the card grows around the picker.
    readonly property real columnWidth: Theme.panelWidth(modelData, Theme.phoneWidth)

    openWidth: picking ? Theme.panelWidth(modelData, Theme.pickerWidth) : columnWidth
    openHeight: picking ? Theme.pickerHeight : home.contentHeight
    openRadius: Theme.phoneRadius

    onOpening: {
      picking = false;
      Phone.browseError = "";
      home.keyboardIndex = 0;
    }

    // Nothing to show once the phone is gone.
    Connections {
      target: Phone

      function onConnectedChanged() {
        if (!Phone.connected && win.open)
          win.hide();
      }

      // The file manager is on its way; the panel's job is done.
      function onMounted(path, purpose) {
        if (purpose === "open" && win.open)
          win.hide();
        else if (purpose === "pick" && win.open && win.picking)
          win.showPhone(path);
      }

      function onMountFailed(purpose) {
        if (purpose === "pick" && win.open && win.picking)
          wallpaperPicker.blocked = true;
      }
    }

    function chooseFiles() {
      pickKind = "files";
      picker.open(win.lastDir);
      picking = true;
    }

    // The wallpaper chooser opens on the laptop's Pictures; the phone side mounts first, and
    // gives way to its own empty state when the phone will not share.
    function chooseWallpaper() {
      pickKind = "wallpaper";
      wallpaperPicker.blocked = false;
      wallpaperPicker.source = "phone";
      wallpaperPicker.phoneName = Phone.name;
      wallpaperPicker.dir = "";
      picking = true;
      Phone.mount("pick");
    }

    function showPhone(path) {
      wallpaperPicker.blocked = false;
      wallpaperPicker.phoneRoot = path;
      wallpaperPicker.source = "phone";
      wallpaperPicker.dir = path + "/Pictures";
    }

    function chooseSource(source) {
      if (source === "phone") {
        wallpaperPicker.source = "phone";
        Phone.mount("pick");
      } else {
        wallpaperPicker.blocked = false;
        wallpaperPicker.source = "laptop";
        wallpaperPicker.dir = wallpaperPicker.home + "/Pictures";
      }
    }

    SystemClock {
      id: clock

      precision: SystemClock.Minutes
    }

    // A messaging app gets a chat bubble, mail an envelope, the rest a bell.
    function noteGlyph(n) {
      var app = (n.app || "").toLowerCase();
      if (/mail|outlook|proton/.test(app))
        return Icons.mail;
      if (/messag|whatsapp|signal|telegram|discord|chat|sms/.test(app))
        return Icons.chat;
      return Icons.notifications;
    }

    Panel {
      id: panel

      surface: win
      // The picker has its own keys; the home view moves across the action tiles.
      takesMove: !win.picking
      takesActivate: !win.picking

      onMoved: function (dx, dy) {
        home.keyboardMove(dx + dy);
      }
      onActivated: home.keyboardActivate()

      onKeyPressed: function (event) {
        if (win.picking)
          (win.pickKind === "wallpaper" ? wallpaperPicker : picker).handleKey(event);
      }

      // ================= Home =================

      Item {
        id: home

        x: (parent.width - width) / 2
        width: win.columnWidth
        height: contentHeight
        opacity: win.picking ? 0 : 1
        visible: opacity > 0
        enabled: !win.picking

        Behavior on opacity {
          ContentFade {}
        }

        readonly property real inner: width - 2 * Theme.phoneInset
        readonly property real contentHeight: 2 * Theme.phoneInset + Theme.phoneDeviceHeight + noteSpace

        // ---- the phone ----

        Rectangle {
          id: device

          x: Theme.phoneInset
          y: Theme.phoneInset
          width: Theme.phoneDeviceWidth
          height: Theme.phoneDeviceHeight
          radius: Theme.phoneDeviceRadius
          color: Theme.highlightLow
          border.width: 1
          border.color: Theme.withAlpha(Theme.highlightMed, 0.7)

          Rectangle {
            id: screen

            anchors.fill: parent
            anchors.margins: Theme.phoneScreenInset
            radius: Theme.phoneScreenRadius
            clip: true
            color: "transparent"

            // The picture the user chose, under a scrim that keeps the time and the notification
            // stubs legible, rounded to the screen's own corners; else the accent-to-base wash.
            readonly property bool pictured: Phone.wallpaper !== "" && !Phone.ringing && wallpaperImage.status === Image.Ready

            Rectangle {
              anchors.fill: parent
              radius: parent.radius
              visible: !screen.pictured
              gradient: Gradient {
                GradientStop {
                  position: 0
                  color: Theme.withAlpha(Theme.accent, Phone.ringing ? 0.55 : 0.32)
                }

                GradientStop {
                  position: 1
                  color: Theme.base
                }
              }
            }

            RoundedClip {
              anchors.fill: parent
              visible: screen.pictured
              radius: screen.radius

              Image {
                id: wallpaperImage

                anchors.fill: parent
                source: Phone.wallpaper
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                // Decoded at twice the screen's height, not the photo's.
                sourceSize.height: parent.height * 2
              }

              Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                  GradientStop {
                    position: 0
                    color: Theme.withAlpha(Theme.base, 0.45)
                  }

                  GradientStop {
                    position: 0.4
                    color: Theme.withAlpha(Theme.base, 0)
                  }

                  GradientStop {
                    position: 1
                    color: Theme.withAlpha(Theme.base, 0.6)
                  }
                }
              }
            }

            // The punch-hole camera.
            Rectangle {
              x: (parent.width - width) / 2
              y: 6
              width: 5
              height: 5
              radius: 2.5
              color: "black"
              border.width: 1
              border.color: Theme.withAlpha(Theme.text, Theme.phoneCameraRingAlpha)
            }

            Column {
              y: 28
              width: parent.width
              visible: !Phone.ringing

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: Theme.text
                font.family: Theme.uiFont
                font.pixelSize: 24
                font.weight: Theme.weightSemi
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "ddd d MMM")
                color: Theme.withAlpha(Theme.text, 0.9)
                font.family: Theme.uiFont
                font.pixelSize: Theme.phoneDateSize
                font.weight: Theme.weightMedium
              }
            }

            // One stub per notification the phone has up, the newest at the bottom.
            Column {
              x: 6
              width: parent.width - 12
              anchors.bottom: parent.bottom
              anchors.bottomMargin: Theme.phoneDiscBottom + Theme.phoneDiscSize + 8
              spacing: 4
              visible: !Phone.ringing

              Repeater {
                model: Phone.notifications.slice(0, Theme.phoneNotesMax).reverse()

                Rectangle {
                  required property var modelData

                  width: parent.width
                  height: 22
                  radius: 8
                  color: Theme.withAlpha("white", 0.1)

                  StrokeIcon {
                    x: 7
                    anchors.verticalCenter: parent.verticalCenter
                    size: 10
                    path: win.noteGlyph(modelData)
                    color: Theme.text
                  }

                  Rectangle {
                    x: 23
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(16, Math.min(parent.width - 30, modelData.title.length * 5))
                    height: 4
                    radius: 2
                    color: Theme.withAlpha("white", 0.35)
                  }
                }
              }
            }

            // Ringing: rings pulsing out of the glyph.
            Item {
              anchors.fill: parent
              visible: Phone.ringing

              Repeater {
                model: 2

                Rectangle {
                  id: pulse

                  required property int index

                  x: (parent.width - width) / 2
                  y: 94 - height / 2
                  width: 40
                  height: 40
                  radius: width / 2
                  color: Theme.withAlpha(Theme.accent, 0.12)
                  border.width: 1
                  border.color: Theme.withAlpha(Theme.accent, 0.3)

                  SequentialAnimation on scale {
                    running: Phone.ringing && win.open && !Theme.reduceMotion
                    loops: Animation.Infinite

                    PauseAnimation {
                      duration: pulse.index * 600
                    }

                    NumberAnimation {
                      from: 1
                      to: 2
                      duration: 1200
                      easing.type: Easing.OutCubic
                    }
                  }

                  opacity: 2 - scale
                }
              }

              Rectangle {
                x: (parent.width - width) / 2
                y: 94 - height / 2
                width: 40
                height: 40
                radius: width / 2
                color: Theme.accent

                StrokeIcon {
                  anchors.centerIn: parent
                  size: 20
                  path: Icons.ringVolume
                  color: Theme.inkOnAccent
                }
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 145
                text: "Ringing"
                color: Theme.text
                font.family: Theme.uiFont
                font.pixelSize: 11
                font.weight: Theme.weightSemi
              }
            }
          }
        }

        // The wallpaper action: a disc at the foot of the phone's screen, on its axis, with the
        // notification stubs above it. An opaque ground under the button keeps a picture from
        // showing through the glyph; a hairline ring over it keeps the edge on a busy one.
        Rectangle {
          id: disc

          x: device.x + (device.width - width) / 2
          y: device.y + device.height - Theme.phoneScreenInset - Theme.phoneDiscBottom - height
          width: Theme.phoneDiscSize
          height: width
          radius: width / 2
          color: Theme.surface
        }

        Button {
          anchors.centerIn: disc
          width: disc.width
          height: disc.height
          kind: Button.Disc
          size: Button.Compact
          icon: Icons.image
          // Clicking it opens the picker, which wants the panel's keys, so it takes no focus.
          activeFocusOnTab: false
          accessibleName: "Choose phone wallpaper"
          onClicked: win.chooseWallpaper()
        }

        Rectangle {
          anchors.fill: disc
          radius: disc.radius
          color: "transparent"
          border.width: 1
          border.color: Theme.withAlpha(Theme.text, Theme.phoneDiscRingAlpha)
        }

        // ---- who it is ----

        Text {
          id: deviceName

          x: Theme.phoneStatusLeft
          y: Theme.phoneNameTop
          width: home.width - x - Theme.phoneInset
          elide: Text.ElideRight
          text: Phone.name
          color: Theme.text
          font.family: Theme.uiFont
          font.pixelSize: 17
          font.weight: Theme.weightSemi
        }

        Rectangle {
          x: Theme.phoneStatusLeft
          y: Theme.phoneStatusTop + 4
          width: 6
          height: 6
          radius: 3
          color: Theme.accent
        }

        Text {
          x: Theme.phoneStatusLeft + 12
          y: Theme.phoneStatusTop
          text: "Connected"
          color: Theme.subtle
          font.family: Theme.uiFont
          font.pixelSize: Theme.phoneCaptionSize
          font.weight: Theme.weightMedium
        }

        // ---- the grid: readings above, actions below ----

        readonly property real tileWidth: Math.floor((width - Theme.phoneStatusLeft - Theme.phoneInset - 2 * Theme.controlTileGap) / 3)

        // Browse could not reach the phone's files: what to allow, dismissable, and gone the
        // next time Browse is pressed. The card grows to make room.
        readonly property bool blocked: Phone.browseError !== ""
        readonly property real noteSpace: blocked ? Theme.phoneNoteBarHeight + Theme.phoneNoteBarGap : 0

        // Arrows and hjkl walk the action tiles, which are the ones that take a press.
        property int keyboardIndex: 0

        function keyboardMove(delta) {
          keyboardIndex = (keyboardIndex + delta + actionTiles.count) % actionTiles.count;
        }

        function keyboardActivate() {
          actionTiles.itemAt(keyboardIndex).opened();
        }

        // Two rows of three with the control centre's gutter; the foot sits on the phone's.
        Item {
          id: tiles

          x: Theme.phoneStatusLeft
          y: Theme.phoneInset + Theme.phoneDeviceHeight - height
          width: home.width - x - Theme.phoneInset
          height: Theme.phoneReadingHeight + Theme.controlTileGap + Theme.controlTileStackedHeight

          Repeater {
            model: [
              {
                label: "Battery",
                glyph: Phone.charging ? Icons.step(Icons.batteryCharging, Phone.charge) : Icons.step(Icons.batteryDefault, Phone.charge),
                value: !Phone.hasBattery ? "Unknown" : Phone.charge + "%" + (Phone.charging ? " · charging" : ""),
                level: Phone.hasBattery ? Phone.charge / 100 : -1,
                off: false
              },
              {
                label: "Mobile",
                glyph: Phone.cellularStrength < 0 ? Icons.cellularOff : Icons.cellular[Math.min(4, Phone.cellularStrength)],
                value: Phone.cellularType !== "" ? Phone.cellularType : "Off on phone",
                level: -1,
                off: Phone.cellularStrength < 0
              },
              {
                label: "Wi-Fi",
                glyph: Icons.wifiOn,
                value: Phone.wifiName !== "" ? Phone.wifiName : Phone.link === "Bluetooth" ? "Over Bluetooth" : "Not shared",
                level: -1,
                off: false
              }
            ]

            PhoneReading {
              required property int index
              required property var modelData

              x: index * (home.tileWidth + Theme.controlTileGap)
              width: home.tileWidth
              label: modelData.label
              value: modelData.value
              glyph: modelData.glyph
              level: modelData.level
              // Off is the dimmer of the two inks that clear 4.5 : 1 on the ground.
              glyphColor: modelData.off ? Theme.inkSecondary : modelData.level >= 0 && Phone.low ? Theme.love : Theme.accent
              valueColor: modelData.off ? Theme.inkSecondary : Theme.withAlpha(Theme.inkPrimary, Theme.phoneReadingValueAlpha)
              levelColor: Phone.low ? Theme.love : Theme.accent
            }
          }

          Repeater {
            id: actionTiles

            model: [
              {
                label: Phone.ringing ? "Ringing…" : "Ring",
                sub: Phone.ringing ? "Stop on phone" : "Find phone",
                glyph: Icons.ringVolume,
                on: Phone.ringing,
                blocked: false,
                run: function () {
                  Phone.ring();
                }
              },
              {
                label: "Send files",
                sub: "From laptop",
                glyph: Icons.uploadFile,
                on: false,
                blocked: false,
                run: function () {
                  win.chooseFiles();
                }
              },
              {
                label: "Browse",
                sub: home.blocked ? "Needs access" : "Phone storage",
                glyph: Icons.folderOpen,
                on: false,
                blocked: home.blocked,
                run: function () {
                  Phone.browse();
                }
              }
            ]

            Tile {
              required property int index
              required property var modelData

              x: index * (home.tileWidth + Theme.controlTileGap)
              y: Theme.phoneReadingHeight + Theme.controlTileGap
              width: home.tileWidth
              stacked: true
              // Pressed, not toggled: the badge has no state of its own.
              opensView: true
              active: modelData.on
              current: home.keyboardIndex === index
              label: modelData.label
              sublabel: modelData.sub
              sublabelColor: active ? Theme.withAlpha(Theme.inkOnAccent, 0.72) : Theme.inkSecondary
              // Idle actions wear the accent so they do not read as off; Browse wears the note's
              // gold while the phone refuses it.
              glyphColor: active ? Theme.inkOnAccent : Theme.withAlpha(modelData.blocked ? Theme.gold : Theme.accent, modelData.blocked ? Theme.phoneBlockedGlyphAlpha : Theme.phoneActionGlyphAlpha)
              outlineTint: modelData.blocked ? Theme.withAlpha(Theme.gold, Theme.phoneBlockedOutlineAlpha) : "transparent"
              glyph: modelData.glyph
              onOpened: modelData.run()
            }
          }
        }

        Rectangle {
          id: browseNote

          x: Theme.phoneInset
          y: tiles.y + tiles.height + Theme.phoneNoteBarGap
          width: home.inner
          height: Theme.phoneNoteBarHeight
          radius: Theme.rowRadius
          color: Theme.withAlpha(Theme.gold, 0.12)
          border.width: 1
          border.color: Theme.withAlpha(Theme.gold, 0.4)
          visible: home.blocked

          StrokeIcon {
            x: Theme.phoneNotePad
            y: 10
            size: 16
            path: Icons.info
            color: Theme.gold
          }

          Text {
            x: Theme.phoneNotePad + 24
            y: 11
            width: parent.width - x - Theme.phoneNotePad - 28
            elide: Text.ElideRight
            text: Phone.browseError
            color: Theme.text
            font.family: Theme.uiFont
            font.pixelSize: 12
            font.weight: Theme.weightMedium
          }

          Button {
            x: parent.width - Theme.phoneNotePad - width
            y: 11
            kind: Button.Icon
            iconSize: 14
            icon: Icons.close
            hitSlop: 6
            accessibleName: "Dismiss"
            onClicked: Phone.browseError = ""
          }
        }
      }

      // ================= File picker =================

      FilePicker {
        id: picker

        x: (parent.width - Theme.pickerWidth) / 2
        width: Theme.pickerWidth
        height: Theme.pickerHeight
        opacity: win.picking && win.pickKind === "files" ? 1 : 0
        visible: opacity > 0
        enabled: win.picking && win.pickKind === "files"

        Behavior on opacity {
          ContentFade {}
        }

        onDirChanged: win.lastDir = dir
        onAccepted: function (paths) {
          Phone.share(paths);
          win.hide();
        }
        onCancelled: win.picking = false
      }

      // The same picker for one picture, with the phone's storage and the laptop's to choose
      // between.
      FilePicker {
        id: wallpaperPicker

        x: (parent.width - Theme.pickerWidth) / 2
        width: Theme.pickerWidth
        height: Theme.pickerHeight
        images: true
        title: "Choose phone wallpaper"
        opacity: win.picking && win.pickKind === "wallpaper" ? 1 : 0
        visible: opacity > 0
        enabled: win.picking && win.pickKind === "wallpaper"

        Behavior on opacity {
          ContentFade {}
        }

        onSourceChosen: function (source) {
          win.chooseSource(source);
        }
        onAccepted: function (paths) {
          Phone.setWallpaper(paths[0]);
          win.picking = false;
        }
        onCancelled: win.picking = false
      }
    }
  }
}
