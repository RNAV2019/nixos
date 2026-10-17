import QtQuick
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

    // While the chooser runs it is a free-standing toplevel, so the window must stop
    // swallowing the clicks that land on it and keep only its own card as a target. The rest
    // of the time the whole window stays a dismiss target, as every other surface's does.
    passThrough: filePicker.running

    // "send" | "receive". A drop on the island always lands in Send.
    property string direction: "send"

    // Staged absolute paths, and their size, probed once per add.
    property var files: []
    property int filesBytes: 0

    // The hover preview over an image row: what to show and where the cursor is, in the
    // window's coordinates. Drawn through IslandSurface.overlay so the card never trims it.
    property bool previewActive: false
    property string previewSource: ""
    property real previewX: 0
    property real previewY: 0

    readonly property bool hasFiles: files.length > 0

    // A sibling of the card, so the preview can spill past the panel without being clipped.
    overlay: [
      HoverPreview {
        active: win.previewActive
        source: win.previewSource
        anchorX: win.previewX
        anchorY: win.previewY
      }
    ]

    // Spawns zenity as a separate window rather than an in-process dialog, which the panel's
    // full-screen layer surface would otherwise cover. Paths arrive one per line on stdout.
    function chooseFiles() {
      filePicker.running = false;
      filePicker.running = true;
    }

    // Outbound sends that predate the current staging. A finished send from an earlier round
    // must not put a check on a tile the moment files are staged again.
    property var preStageIds: []

    function addFiles(paths) {
      var next = files.slice();
      for (var i = 0; i < paths.length; i++) {
        if (next.indexOf(paths[i]) === -1)
          next.push(paths[i]);
      }
      files = next;
      preStageIds = Nearby.terminalOutboundIds();
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

      function onSendRequested(paths) {
        win.direction = "send";
        if (paths && paths.length > 0)
          win.addFiles(paths);
      }

      function onReceiveRequested() {
        win.direction = "receive";
      }
    }

    onOpenChanged: {
      if (open) {
        // A panel opened straight into a direction (a drop, the receive IPC) has to arm
        // the stack itself; onDirectionChanged only fires on a change while open.
        if (direction === "send")
          Nearby.scanOn(0);
        else
          Nearby.turnOnForever();
      } else {
        Nearby.scanOff();
      }
    }

    onDirectionChanged: {
      if (!open)
        return;
      if (direction === "send") {
        // One scan for as long as Send is up; the daemon keeps its peer table across a
        // scan, so there is nothing to re-arm and no churn to slow discovery down.
        Nearby.scanOn(0);
      } else {
        // Receiving means the window is open: the radar and the timer chip only make
        // sense while devices can see us. The window stays open until it is turned off,
        // since the phone's own "Everyone" reverts after 10 minutes regardless.
        Nearby.scanOff();
        Nearby.turnOnForever();
      }
    }

    // The external chooser: its own process, so it is not caught by the layer surface.
    Process {
      id: filePicker

      command: ["zenity", "--file-selection", "--multiple", "--separator=\n", "--title", "Choose files to send"]

      stdout: StdioCollector {
        onStreamFinished: {
          var out = text.trim();
          if (out !== "")
            win.addFiles(out.split("\n"));
        }
      }

      onExited: function (code) {
        if (code !== 0 && code !== 1)
          Nearby.showNotice("error", "File chooser failed (" + code + ")");
      }
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

    onKeyPressed: function (event) {
      if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
        direction = direction === "send" ? "receive" : "send";
        event.accepted = true;
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

        // The files card (board 16b), or the chooser well when nothing is staged yet. The
        // well is not a drop target any more: drops land on the collapsed pill.
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
            color: Theme.withAlpha(Theme.surfaceSubtle, 0.85)

            DashedOutline {
              anchors.fill: parent
              anchors.margins: 1
              cornerRadius: Theme.nearbyDropRadius
              strokeWidth: Theme.nearbyDropStroke
              strokeColor: Theme.withAlpha(Theme.separator, 0.9)
            }

            Column {
              anchors.centerIn: parent
              spacing: 18

              StrokeIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                size: Theme.nearbyDropGlyph
                strokeWidth: 1.6
                path: IconPaths.upload
                color: Theme.inkSecondary
              }

              Rectangle {
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
                  onClicked: win.chooseFiles()
                }

                Accessible.role: Accessible.Button
                Accessible.name: "Choose files"
                Accessible.onPressAction: win.chooseFiles()
              }
            }
          }

          FilesCard {
            visible: win.hasFiles
            x: Theme.nearbyInset
            y: 0
            files: win.files
            totalBytes: win.filesBytes
            onAddClicked: win.chooseFiles()
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
            anchors.right: parent.right
            anchors.rightMargin: Theme.nearbySectionSide
            height: 14
            spacing: 5

            readonly property bool notice: Nearby.noticeText !== ""

            StrokeIcon {
              visible: Nearby.wifiPaused && !parent.notice
              anchors.verticalCenter: parent.verticalCenter
              size: 14
              strokeWidth: 1.8
              path: IconPaths.wifiOff
              color: Theme.gold
            }

            // A daemon notice ("AirDrop did not start: …") takes the slot; otherwise the
            // gold Wi-Fi note, then Scanning.
            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: Math.min(implicitWidth, Theme.nearbyWidth - Theme.nearbySectionSide * 2 - 20)
              elide: Text.ElideRight
              text: parent.notice ? Nearby.noticeText : Nearby.wifiPaused ? "Wi-Fi paused" : Nearby.scanning ? "Scanning…" : ""
              color: parent.notice && Nearby.noticeLevel === "error" ? Theme.love : Nearby.wifiPaused ? Theme.gold : Theme.accentFill
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
                transfer: Nearby.outgoingFor(modelData, win.preStageIds)
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
      readonly property int rowCount: Math.min(4, Nearby.receivedList.length)
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

        // A daemon notice, so a failed mode switch or window says why instead of looking
        // like nothing happened.
        Item {
          width: Theme.nearbyWidth
          height: Nearby.noticeText !== "" ? 22 : 0
          visible: height > 0
          clip: true

          Text {
            anchors.right: parent.right
            anchors.rightMargin: Theme.nearbySectionSide
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, Theme.nearbyWidth - Theme.nearbySectionSide * 2)
            elide: Text.ElideRight
            text: Nearby.noticeText
            color: Nearby.noticeLevel === "error" ? Theme.love : Theme.inkSecondary
            font.family: Theme.uiFont
            font.pixelSize: Theme.nearbySectionSize
            font.weight: Theme.weightMedium
          }
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

        // "Received", a Clear that empties the list, and the Downloads link that opens the
        // folder the daemon saved to.
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
            id: downloadsArea

            x: downloadsLink.x - 6
            y: -4
            width: downloadsLink.width + 12
            height: downloadsLink.height + 8
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Nearby.openDownloads()

            Accessible.role: Accessible.Button
            Accessible.name: "Open Downloads"
            Accessible.onPressAction: Nearby.openDownloads()
          }

          // Clear sits to the left of Downloads and only appears once there is a history.
          Row {
            id: clearLink

            x: downloadsLink.x - width - 16
            height: 14
            spacing: 5
            visible: Nearby.receivedList.length > 0

            StrokeIcon {
              anchors.verticalCenter: parent.verticalCenter
              size: 14
              strokeWidth: 1.8
              path: IconPaths.x
              color: clearArea.containsMouse ? Theme.inkPrimary : Theme.inkSecondary
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Clear"
              color: clearArea.containsMouse ? Theme.inkPrimary : Theme.inkSecondary
              font.family: Theme.uiFont
              font.pixelSize: Theme.nearbySectionSize
              font.weight: Theme.weightMedium
            }
          }

          MouseArea {
            id: clearArea

            visible: clearLink.visible
            x: clearLink.x - 6
            y: -4
            width: clearLink.width + 12
            height: clearLink.height + 8
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Nearby.clearReceived()

            Accessible.role: Accessible.Button
            Accessible.name: "Clear received"
            Accessible.onPressAction: Nearby.clearReceived()
          }
        }

        Item {
          width: Theme.nearbyWidth
          height: Theme.nearbyRowsTop
        }

        Repeater {
          model: Nearby.receivedList.slice(0, 4)

          Item {
            required property var modelData
            required property int index

            width: Theme.nearbyWidth
            height: Theme.nearbyRowHeight

            ReceivedRow {
              id: receivedRow

              x: Theme.nearbyInset
              y: 0
              transfer: modelData
              fresh: Nearby.lastArrival === modelData.id
              progress: Nearby.progressOf(modelData)
              groupPosition: {
                var n = Nearby.receivedList.length;
                if (n <= 1)
                  return "only";
                if (index === 0)
                  return "first";
                if (index === n - 1)
                  return "last";
                return "middle";
              }
              onClicked: Nearby.openFile(receivedRow.path)
              onHoverMoved: function (lx, ly) {
                if (!receivedRow.isImage) {
                  win.previewActive = false;
                  return;
                }
                // Map to the card, not the window: a Quickshell PanelWindow is not a
                // QQuickItem, so mapToItem(win, …) throws. The overlay shares the window's
                // origin, so the card's own offset puts the cursor back in window space.
                var p = receivedRow.mapToItem(win.surface, lx, ly);
                win.previewX = win.surface.x + p.x;
                win.previewY = win.surface.y + p.y;
                win.previewSource = "file://" + receivedRow.path;
                win.previewActive = true;
              }
              onHoverExited: win.previewActive = false
            }
          }
        }
      }
    }
  }
}
