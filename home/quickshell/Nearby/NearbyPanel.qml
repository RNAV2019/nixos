import QtQuick
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services
import qs.Ui

// The Nearby panel (boards 16a-16g). Two segmented tracks pick the protocol stack and the
// direction; Send is a drop well that collapses into a files card over the device tiles,
// Receive is the breathing radar with consent cards and arrivals. nearbyd drives all of it:
// every control is one `nearby` call, and the event stream redraws the panel.
Variants {
  id: root

  model: Quickshell.screens

  IslandSurface {
    id: win

    key: "nearby"
    openWidth: Theme.panelWidth(modelData, Theme.nearbyWidth)
    openHeight: (direction === "send" ? sendView : receiveView).contentHeight
    openRadius: Theme.nearbyRadius

    // "send" | "receive". A drop on the island always lands in Send.
    property string direction: "send"

    // Staged absolute paths, and their size, probed once per add.
    property var files: []
    property int filesBytes: 0

    // The drop well arms while files hover over it (board 16f), or when the island opened
    // this panel for a drag that has not landed yet.
    property bool dropArmed: false

    readonly property bool hasFiles: files.length > 0

    function addFiles(paths) {
      var next = files.slice();
      for (var i = 0; i < paths.length; i++) {
        if (next.indexOf(paths[i]) === -1)
          next.push(paths[i]);
      }
      files = next;
      probeSizes();
    }

    function clearFiles() {
      files = [];
      filesBytes = 0;
    }

    function probeSizes() {
      if (files.length === 0) {
        filesBytes = 0;
        return;
      }
      sizeProbe.command = ["stat", "-c", "%s", "--"].concat(files);
      sizeProbe.running = true;
    }

    Connections {
      target: Nearby

      function onSendRequested(paths, armed) {
        win.direction = "send";
        if (paths && paths.length > 0)
          win.addFiles(paths);
        win.dropArmed = armed;
      }

      function onReceiveRequested() {
        win.direction = "receive";
      }
    }

    onOpenChanged: {
      if (open) {
        if (direction === "send")
          Nearby.scanOn(25);
      } else {
        Nearby.scanOff();
        dropArmed = false;
      }
    }

    onDirectionChanged: {
      if (!open)
        return;
      if (direction === "send") {
        Nearby.scanOn(25);
      } else {
        // Receiving means the window is open: the radar and the timer chip only make
        // sense while devices can see us.
        Nearby.scanOff();
        Nearby.turnOn();
      }
    }

    // Peer ids live for one scan only, so the send view keeps re-arming one.
    Timer {
      interval: 20000
      running: win.open && win.direction === "send"
      repeat: true
      onTriggered: Nearby.scanOn(25)
    }

    Process {
      id: sizeProbe

      stdout: StdioCollector {
        onStreamFinished: {
          var total = 0;
          var lines = text.trim().split("\n");
          for (var i = 0; i < lines.length; i++) {
            var n = parseInt(lines[i], 10);
            if (!isNaN(n))
              total += n;
          }
          win.filesBytes = total;
        }
      }
    }

    FileDialog {
      id: picker

      fileMode: FileDialog.OpenFiles
      onAccepted: win.addFiles(selectedFiles.map(function (u) {
        return Nearby.pathFromUrl(u);
      }))
    }

    onKeyPressed: function (event) {
      if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
        direction = direction === "send" ? "receive" : "send";
        event.accepted = true;
      }
    }

    // The whole body is a drop target in Send mode; entering arms the well.
    DropArea {
      id: dropArea

      x: Theme.nearbyInset
      y: Theme.nearbyPadTop + Theme.nearbyHeaderHeight + Theme.nearbyBodyGap
      width: Theme.nearbyWidth - Theme.nearbyInset * 2
      height: direction === "send" ? (win.hasFiles ? Theme.nearbyFilesHeight : Theme.nearbyDropHeight) : 0
      enabled: win.open && direction === "send"

      onEntered: function (drag) {
        win.dropArmed = true;
      }

      onExited: {
        win.dropArmed = false;
      }

      onDropped: function (drop) {
        if (drop.hasUrls) {
          win.addFiles(Nearby.pathsFromUrls(drop.urls));
          win.dropArmed = false;
          drop.acceptProposedAction();
        }
      }
    }

    Item {
      id: sendView

      width: Theme.nearbyWidth
      height: contentHeight
      opacity: win.direction === "send" ? 1 : 0
      visible: opacity > 0

      readonly property real contentHeight: sendCol.implicitHeight + Theme.nearbyPadTop + Theme.nearbyPadBottom

      Behavior on opacity {
        Morph {
          duration: Theme.morphSurface
        }
      }

      Column {
        id: sendCol

        y: Theme.nearbyPadTop
        width: parent.width

        Item {
          width: Theme.nearbyWidth
          height: Theme.nearbyHeaderHeight

          SegmentedTrack {
            x: Theme.nearbyHeaderSide
            y: 0
            currentIndex: Nearby.mode === "apple" ? 1 : 0
            pending: Nearby.busy
            segments: [{
              "icon": IconPaths.robotHead,
              "label": "Android"
            }, {
              "icon": IconPaths.apple,
              "label": "Apple",
              "filled": true
            }]
            onChosen: function (index) {
              Nearby.setMode(index === 1 ? "apple" : "android");
            }
          }

          SegmentedTrack {
            x: Theme.nearbyWidth - Theme.nearbyHeaderSide - Theme.nearbyTrackWidth
            y: 0
            currentIndex: 0
            segments: [{
              "icon": IconPaths.arrowUp,
              "label": "Send"
            }, {
              "icon": IconPaths.arrowDown,
              "label": "Receive"
            }]
            onChosen: function (index) {
              win.direction = index === 1 ? "receive" : "send";
            }
          }
        }

        Item {
          width: Theme.nearbyWidth
          height: Theme.nearbyBodyGap
        }

        // The drop well (board 16a idle, 16f armed) or the files card (board 16b).
        Item {
          width: Theme.nearbyWidth
          height: win.hasFiles ? Theme.nearbyFilesHeight : Theme.nearbyDropHeight

          Rectangle {
            id: dropZone

            visible: !win.hasFiles
            x: Theme.nearbyInset
            width: Theme.nearbyWidth - Theme.nearbyInset * 2
            height: Theme.nearbyDropHeight
            radius: Theme.nearbyDropRadius
            color: win.dropArmed ? Theme.withAlpha(Theme.accentFill, 0.08) : Theme.withAlpha(Theme.surfaceSubtle, 0.85)

            Behavior on color {
              Tint {}
            }

            DashedOutline {
              anchors.fill: parent
              anchors.margins: 1
              cornerRadius: Theme.nearbyDropRadius
              strokeWidth: Theme.nearbyDropStroke
              strokeColor: win.dropArmed ? Theme.withAlpha(Theme.accentFill, 0.85) : Theme.withAlpha(Theme.separator, 0.9)

              Behavior on strokeColor {
                Tint {}
              }
            }

            Column {
              anchors.centerIn: parent
              spacing: 18

              StrokeIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                size: win.dropArmed ? Theme.nearbyDropGlyphArmed : Theme.nearbyDropGlyph
                strokeWidth: 1.6
                path: win.dropArmed ? IconPaths.download : IconPaths.upload
                color: win.dropArmed ? Theme.accentFill : Theme.inkSecondary

                Behavior on color {
                  Tint {}
                }
              }

              // Armed, the well is pure target: the button steps aside.
              Rectangle {
                visible: !win.dropArmed
                anchors.horizontalCenter: parent.horizontalCenter
                width: chooseLabel.implicitWidth + Theme.nearbyDeviceGlyph + 24
                height: 36
                radius: 18
                color: Theme.accentFill
                scale: chooseArea.pressed ? Theme.pressScale : 1

                Behavior on scale {
                  Morph {
                    duration: Theme.morphState
                  }
                }

                Row {
                  anchors.centerIn: parent
                  spacing: Theme.nearbySegmentGap

                  StrokeIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    size: Theme.nearbySegmentGlyph
                    strokeWidth: 2
                    path: IconPaths.plus
                    color: Theme.inkOnAccent
                  }

                  Text {
                    id: chooseLabel

                    anchors.verticalCenter: parent.verticalCenter
                    text: "Choose files"
                    color: Theme.inkOnAccent
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.nearbySegmentSize + 0.5
                    font.weight: Theme.weightSemi
                  }
                }

                MouseArea {
                  id: chooseArea

                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: picker.open()
                }

                Accessible.role: Accessible.Button
                Accessible.name: "Choose files"
                Accessible.onPressAction: picker.open()
              }
            }
          }

          FilesCard {
            visible: win.hasFiles
            x: Theme.nearbyInset
            y: 0
            files: win.files
            totalBytes: win.filesBytes
            onAddClicked: picker.open()
            onClearClicked: win.clearFiles()
          }
        }

        Item {
          width: Theme.nearbyWidth
          height: Theme.nearbyBodyGap
        }

        // "Nearby" and what the stack is doing, right-aligned (board 16b: Scanning…,
        // board 16g: the gold Wi-Fi note).
        Item {
          width: Theme.nearbyWidth
          height: 14

          Text {
            x: Theme.nearbySectionSide
            text: "Nearby"
            color: Theme.inkTertiary
            font.family: Theme.uiFont
            font.pixelSize: Theme.nearbySectionSize
            font.weight: Theme.weightMedium
          }

          Row {
            x: Theme.nearbyWidth - Theme.nearbySectionSide - width
            height: 14
            spacing: 5

            StrokeIcon {
              visible: Nearby.wifiPaused
              anchors.verticalCenter: parent.verticalCenter
              size: 14
              strokeWidth: 1.8
              path: IconPaths.wifiOff
              color: Theme.gold
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: Nearby.wifiPaused ? "Wi-Fi paused" : Nearby.scanning ? "Scanning…" : ""
              color: Nearby.wifiPaused ? Theme.gold : Theme.accentFill
              font.family: Theme.uiFont
              font.pixelSize: Theme.nearbySectionSize
              font.weight: Theme.weightMedium

              Behavior on color {
                Tint {}
              }
            }
          }
        }

        Item {
          width: Theme.nearbyWidth
          height: Theme.nearbySectionGap
        }

        // The device tiles, on a 100 px pitch from the panel's first slot.
        Item {
          width: Theme.nearbyWidth
          height: Theme.nearbyDeviceSize + Theme.nearbyDeviceNameGap + 14 + (win.hasFiles ? Theme.nearbyDeviceSubGap + Theme.nearbyDeviceSubHeight : 0)

          Row {
            x: 12
            y: 0

            Repeater {
              model: Nearby.peers.slice(0, 5)

              DeviceTile {
                required property var modelData

                peer: modelData
                filesReady: win.hasFiles
                transfer: Nearby.outgoingFor(modelData)
                onTapped: Nearby.send(win.files, modelData.id)
                onCancelTapped: {
                  if (transfer && transfer.id)
                    Nearby.cancel(transfer.id);
                }
              }
            }
          }
        }
      }
    }

    Item {
      id: receiveView

      width: Theme.nearbyWidth
      height: contentHeight
      opacity: win.direction === "receive" ? 1 : 0
      visible: opacity > 0

      readonly property int incomingCount: Math.min(3, Nearby.pendingInbound.length)
      readonly property int rowCount: Math.min(3, Nearby.received.length)
      readonly property real contentHeight: receiveCol.implicitHeight + Theme.nearbyPadTop + 18

      Behavior on opacity {
        Morph {
          duration: Theme.morphSurface
        }
      }

      Column {
        id: receiveCol

        y: Theme.nearbyPadTop
        width: parent.width

        Item {
          width: Theme.nearbyWidth
          height: Theme.nearbyHeaderHeight

          SegmentedTrack {
            x: Theme.nearbyHeaderSide
            y: 0
            currentIndex: Nearby.mode === "apple" ? 1 : 0
            pending: Nearby.busy
            segments: [{
              "icon": IconPaths.robotHead,
              "label": "Android"
            }, {
              "icon": IconPaths.apple,
              "label": "Apple",
              "filled": true
            }]
            onChosen: function (index) {
              Nearby.setMode(index === 1 ? "apple" : "android");
            }
          }

          SegmentedTrack {
            x: Theme.nearbyWidth - Theme.nearbyHeaderSide - Theme.nearbyTrackWidth
            y: 0
            currentIndex: 1
            segments: [{
              "icon": IconPaths.arrowUp,
              "label": "Send"
            }, {
              "icon": IconPaths.arrowDown,
              "label": "Receive"
            }]
            onChosen: function (index) {
              win.direction = index === 1 ? "receive" : "send";
            }
          }
        }

        Item {
          width: Theme.nearbyWidth
          height: Theme.nearbyBodyGap
        }

        RadarView {
          width: Theme.nearbyWidth
          deviceName: Nearby.deviceName
          remainingLabel: Nearby.remainingLabel
          receivable: Nearby.receivable
          wifiPaused: Nearby.wifiPaused
          onTimerClicked: Nearby.turnOff()
        }

        // Quick Share consent cards (board 16c); AirDrop is accepted by omdrop itself.
        Repeater {
          model: Nearby.pendingInbound.slice(0, 3)

          Item {
            required property var modelData
            required property int index

            width: Theme.nearbyWidth
            height: Theme.nearbyIncomingHeight + (index > 0 ? 2 : 18)

            IncomingCard {
              y: index > 0 ? 2 : 18
              x: Theme.nearbyInset
              transfer: modelData
              onAccepted: Nearby.accept(modelData.id)
              onDeclined: Nearby.decline(modelData.id)
            }
          }
        }

        Item {
          width: Theme.nearbyWidth
          height: receiveView.incomingCount > 0 ? Theme.nearbyReceivedGap : Theme.nearbyReceivedGap + 2
        }

        // "Received" and the Downloads link, which opens the folder the daemon saved to.
        Item {
          width: Theme.nearbyWidth
          height: 14

          Text {
            x: Theme.nearbySectionSide
            text: "Received"
            color: Theme.inkTertiary
            font.family: Theme.uiFont
            font.pixelSize: Theme.nearbySectionSize
            font.weight: Theme.weightMedium
          }

          Row {
            id: downloadsLink

            x: Theme.nearbyWidth - Theme.nearbySectionSide - width
            height: 14
            spacing: 5

            StrokeIcon {
              anchors.verticalCenter: parent.verticalCenter
              size: 14
              strokeWidth: 1.8
              path: IconPaths.folder
              color: Theme.accentFill
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Downloads"
              color: Theme.accentFill
              font.family: Theme.uiFont
              font.pixelSize: Theme.nearbySectionSize
              font.weight: Theme.weightMedium
            }
          }

          MouseArea {
            x: downloadsLink.x - 6
            y: -4
            width: downloadsLink.width + 12
            height: downloadsLink.height + 8
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Nearby.openDownloads()
          }

          Accessible.role: Accessible.Button
          Accessible.name: "Open Downloads"
          Accessible.onPressAction: Nearby.openDownloads()
        }

        Item {
          width: Theme.nearbyWidth
          height: Theme.nearbyRowsTop
        }

        Repeater {
          model: Nearby.received.slice(0, 3)

          Item {
            required property var modelData
            required property int index

            width: Theme.nearbyWidth
            height: Theme.nearbyRowHeight + (index > 0 ? Theme.nearbyRowGap : 0)

            ReceivedRow {
              id: receivedRow

              x: Theme.nearbyInset
              y: index > 0 ? Theme.nearbyRowGap : 0
              transfer: modelData
              fresh: Nearby.lastArrival === modelData.id
              onClicked: Nearby.openFile(receivedRow.path)
            }
          }
        }
      }
    }
  }
}
