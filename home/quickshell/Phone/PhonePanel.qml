import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.Commons
import qs.Nearby
import qs.Services
import qs.Ui

// The phone panel (board "Phone panel"), opened from the phone satellite: the phone drawn on
// the left with its time and notification stubs, readings beside it, then actions, the
// clipboard and the phone's notifications. "Send files" grows the panel into Nearby's file
// picker; what it accepts goes to the phone through KDE Connect. The disc on the phone's corner
// grows it into the same picker to choose the picture drawn on the phone's screen. "Browse"
// mounts the phone's storage and opens it in the file manager; when the phone refuses, a note
// under the actions says what to allow.
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
      Phone.refreshClips();
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

    // "now", "5 min", "2 h"; empty for a notification from before the bridge started.
    function ago(ms) {
      if (!ms)
        return "";
      var mins = Math.floor((clock.date.getTime() - ms) / 60000);
      if (mins < 1)
        return "now";
      if (mins < 60)
        return mins + " min";
      return Math.floor(mins / 60) + " h";
    }

    Panel {
      id: panel

      surface: win

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
          Morph {
            duration: Theme.morphContent
          }
        }

        readonly property real inner: width - 2 * Theme.phoneInset
        readonly property real contentHeight: (notes.visible ? notes.y + notes.height : clips.y + clips.height) + Theme.phoneInset

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
                color: Theme.withAlpha(Theme.text, 0.7)
                font.family: Theme.uiFont
                font.pixelSize: 10
                font.weight: Theme.weightMedium
              }
            }

            // One stub per notification the phone has up, the newest at the bottom.
            Column {
              x: 6
              width: parent.width - 12
              anchors.bottom: parent.bottom
              anchors.bottomMargin: 8
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
                y: 148
                text: "Ringing"
                color: Theme.text
                font.family: Theme.uiFont
                font.pixelSize: 11
                font.weight: Theme.weightSemi
              }
            }
          }
        }

        // The wallpaper action: a disc over the phone's bottom-right corner, with a ring in the
        // panel's ground cutting it out of the body.
        Rectangle {
          x: 106
          y: 216
          width: 34
          height: 34
          radius: 17
          color: Theme.surface
        }

        Button {
          x: 123 - width / 2
          y: 233 - height / 2
          kind: Button.Disc
          size: Button.Compact
          icon: Icons.image
          // Clicking it opens the picker, which wants the panel's keys, so it takes no focus.
          activeFocusOnTab: false
          accessibleName: "Choose phone wallpaper"
          onClicked: win.chooseWallpaper()
        }

        // ---- who it is ----

        Text {
          id: deviceName

          x: Theme.phoneStatusLeft
          y: 22
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
          y: 52
          width: 6
          height: 6
          radius: 3
          color: Theme.accent
        }

        Text {
          x: Theme.phoneStatusLeft + 12
          y: 48
          text: Phone.link === "Wi-Fi" ? "Connected · same Wi-Fi" : Phone.link !== "" ? "Connected · " + Phone.link : "Connected"
          color: Theme.subtle
          font.family: Theme.uiFont
          font.pixelSize: Theme.phoneCaptionSize
          font.weight: Theme.weightMedium
        }

        // ---- readings ----

        Column {
          x: Theme.phoneStatusLeft
          y: Theme.phoneStatusTop
          width: home.width - x - Theme.phoneInset
          spacing: Theme.phoneStatusGap

          Repeater {
            model: [
              {
                label: "Battery",
                glyph: Phone.charging ? Icons.step(Icons.batteryCharging, Phone.charge) : Icons.step(Icons.batteryDefault, Phone.charge),
                value: !Phone.hasBattery ? "Unknown" : Phone.charge + "%" + (Phone.charging ? " · charging" : ""),
                level: Phone.hasBattery ? Phone.charge / 100 : -1,
                muted: false
              },
              {
                label: "Mobile",
                glyph: Phone.cellularStrength < 0 ? Icons.cellularOff : Icons.cellular[Math.min(4, Phone.cellularStrength)],
                value: Phone.cellularType !== "" ? Phone.cellularType : "Off on phone",
                level: -1,
                muted: Phone.cellularStrength < 0
              },
              {
                label: "Wi-Fi",
                glyph: Icons.wifiOn,
                value: Phone.wifiName !== "" ? Phone.wifiName : Phone.link === "Bluetooth" ? "Over Bluetooth" : "Not shared",
                level: -1,
                muted: false
              }
            ]

            ListRow {
              required property var modelData

              kind: ListRow.Hairline
              interactive: false
              width: parent.width
              height: Theme.phoneStatusHeight
              glyph: modelData.glyph
              glyphSize: 18
              glyphColor: modelData.muted ? Theme.inkTertiary : modelData.level >= 0 && Phone.low ? Theme.love : Theme.accent
              // A row with a level is label, gap and bar as one block centred on the row; the
              // bar runs from the label's edge to the reading's.
              label: modelData.label
              textLeft: 45
              labelTop: modelData.level >= 0 ? 12 : 16
              value: modelData.value
              valueColor: modelData.muted ? Theme.inkTertiary : Theme.subtle
              valueTop: modelData.level >= 0 ? 12 : 16

              // The row's own ground is highlightLow, so the groove is the next step up.
              LevelTrack {
                x: 45
                y: 33
                width: parent.width - 45 - 14
                height: 3
                visible: modelData.level >= 0
                color: Theme.highlightMed
                fillColor: Phone.low ? Theme.love : Theme.accent
                value: modelData.level
              }
            }
          }
        }

        // ---- actions ----

        // Browse could not reach the phone's files: what to allow, dismissable, and gone the
        // next time Browse is pressed. The rest of the panel moves down to make room.
        readonly property real noteSpace: Phone.browseError !== "" ? Theme.phoneNoteBarHeight + Theme.phoneNoteBarGap : 0

        Rectangle {
          id: browseNote

          x: Theme.phoneInset
          y: actions.y + actions.height + Theme.phoneNoteBarGap
          width: home.inner
          height: Theme.phoneNoteBarHeight
          radius: Theme.rowRadius
          color: Theme.withAlpha(Theme.gold, 0.12)
          border.width: 1
          border.color: Theme.withAlpha(Theme.gold, 0.4)
          visible: Phone.browseError !== ""

          StrokeIcon {
            x: 14
            y: 10
            size: 16
            path: Icons.info
            color: Theme.gold
          }

          Text {
            x: 38
            y: 11
            width: parent.width - x - 44
            elide: Text.ElideRight
            text: Phone.browseError
            color: Theme.text
            font.family: Theme.uiFont
            font.pixelSize: 12
            font.weight: Theme.weightMedium
          }

          Button {
            x: 451
            y: 11
            kind: Button.Icon
            iconSize: 14
            icon: Icons.close
            hitSlop: 6
            accessibleName: "Dismiss"
            onClicked: Phone.browseError = ""
          }
        }

        Row {
          id: actions

          x: Theme.phoneInset
          y: Theme.phoneInset + Theme.phoneDeviceHeight + Theme.phoneSectionGap
          spacing: Theme.phoneActionGap

          Repeater {
            model: [
              {
                label: Phone.ringing ? "Ringing…" : "Ring",
                glyph: Icons.ringVolume,
                width: 100,
                on: Phone.ringing,
                run: function () {
                  Phone.ring();
                }
              },
              {
                label: "Send files",
                glyph: Icons.uploadFile,
                width: 116,
                on: false,
                run: function () {
                  win.chooseFiles();
                }
              },
              {
                label: "Browse",
                glyph: Icons.folderOpen,
                width: 104,
                on: false,
                run: function () {
                  Phone.browse();
                }
              },
              {
                label: "Send clipboard",
                glyph: Icons.clipboard,
                width: 136,
                on: false,
                run: function () {
                  Phone.sendClipboard();
                }
              }
            ]

            Button {
              id: action

              required property var modelData

              width: modelData.width
              height: Theme.phoneActionHeight
              kind: modelData.on ? Button.Primary : Button.Neutral
              text: modelData.label
              icon: modelData.glyph
              iconSize: 16
              iconColor: modelData.on ? ink : Theme.accent
              onClicked: modelData.run()
            }
          }
        }

        // ---- the clipboard ----

        SectionLabel {
          id: clipsLabel

          x: Theme.phoneInset
          y: actions.y + actions.height + home.noteSpace + Theme.phoneSectionGap
          width: home.inner
          implicitHeight: 13
          verticalAlignment: Qt.AlignTop
          title: "Clipboard"

          Text {
            text: "Synced both ways"
            color: Theme.accent
            font.family: Theme.uiFont
            font.pixelSize: Theme.sectionSize
            font.weight: Theme.weightMedium
          }
        }

        // The id of the clip last copied back, for its check.
        property string copied: ""

        Timer {
          id: copiedReset

          interval: 1200
          onTriggered: home.copied = ""
        }

        Column {
          id: clips

          x: Theme.phoneInset
          y: clipsLabel.y + clipsLabel.height + 7
          width: home.inner
          spacing: Theme.phoneRowGap

          Repeater {
            model: Phone.clips

            ListRow {
              id: clipRow

              required property var modelData

              readonly property bool isLink: /^[a-z]+:\/\/\S+$/i.test(modelData.preview)

              kind: ListRow.Hairline
              width: parent.width
              height: Theme.phoneRowHeight
              glyph: clipRow.isLink ? Icons.link : Icons.notes
              glyphSize: 18
              label: modelData.preview
              textLeft: 47
              textGap: 14
              onClicked: {
                Phone.copyClip(clipRow.modelData.id);
                home.copied = clipRow.modelData.id;
                copiedReset.restart();
              }
              trailing: StrokeIcon {
                size: 16
                path: home.copied === clipRow.modelData.id ? Icons.check : Icons.copy
                color: home.copied === clipRow.modelData.id ? Theme.accent : Theme.text
                opacity: clipRow.hovered || home.copied === clipRow.modelData.id ? 1 : 0

                Behavior on opacity {
                  Morph {
                    duration: Theme.morphState
                  }
                }
              }
            }
          }

          ListRow {
            kind: ListRow.Hairline
            interactive: false
            width: parent.width
            height: Theme.phoneRowHeight
            visible: Phone.clips.length === 0
            value: "Nothing copied yet"
            valueCentred: true
          }
        }

        // ---- the phone's notifications ----

        SectionLabel {
          id: notesLabel

          x: Theme.phoneInset
          y: clips.y + clips.height + Theme.phoneSectionGap
          width: home.inner
          implicitHeight: 13
          verticalAlignment: Qt.AlignTop
          visible: notes.visible
          title: "On your phone"
          note: Phone.notifications.length === 1 ? "1 notification" : Phone.notifications.length + " notifications"
        }

        Column {
          id: notes

          x: Theme.phoneInset
          y: notesLabel.y + notesLabel.height + 7
          width: home.inner
          spacing: Theme.phoneRowGap
          visible: Phone.notifications.length > 0

          Repeater {
            model: Phone.notifications.slice(0, Theme.phoneNotesMax)

            ListRow {
              id: noteRow

              required property var modelData

              readonly property bool dismissShown: modelData.dismissable && (noteRow.hovered || dismissButton.hovered)

              kind: ListRow.Hairline
              interactive: false
              hoverTint: true
              width: parent.width
              height: Theme.phoneNoteHeight
              label: [modelData.app, modelData.title].filter(s => s !== "").join(" · ")
              labelWeight: Theme.weightSemi
              sublabel: modelData.text
              sublabelSize: 12
              sublabelColor: Theme.subtle
              textLeft: 55
              textRight: 64
              subRight: 20
              value: noteRow.dismissShown ? "" : win.ago(modelData.time)
              valueTop: 11

              Rectangle {
                x: 13
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 30
                radius: 15
                color: Theme.withAlpha(Theme.accent, 0.12)

                StrokeIcon {
                  anchors.centerIn: parent
                  size: 16
                  path: win.noteGlyph(noteRow.modelData)
                  color: Theme.accent
                }
              }

              Button {
                id: dismissButton

                x: parent.width - 12 - width
                y: 10
                kind: Button.Icon
                iconSize: 16
                icon: Icons.close
                hitSlop: 6
                accessibleName: "Dismiss notification"
                visible: noteRow.modelData.dismissable
                // Shown by the row, then held by itself; see ButtonBase.revealed.
                revealed: noteRow.dismissShown
                onClicked: Phone.dismiss(noteRow.modelData.id)
              }
            }
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
          Morph {
            duration: Theme.morphContent
          }
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
          Morph {
            duration: Theme.morphContent
          }
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
