import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services
import qs.Ui

// The Sharing Panel (boards 16a-16h). Two segmented tracks pick the protocol stack and the
// direction. Send starts as one "Choose files" button over the nearby devices (16a); the
// button opens the keyboard file picker, which grows the panel to 960 x 412 (16b, 16c), and
// what it picks - or what was dropped on the pill (16d) - lists as rows (16e). Tapping a device
// sends; its tile rings with progress, checks when delivered (16f), then the tile and the
// staged files reset while the panel stays open. Receive is the rippling radar with consent
// cards that stay until answered and the arrivals list (16g, 16h). nearbyd drives all of it:
// every control is one `nearby` call, and the event stream redraws the panel.
Variants {
  id: root

  model: Quickshell.screens

  IslandSurface {
    id: win

    key: "nearby"

    // "send" | "receive". Every open starts in Send unless something asked for Receive.
    property string direction: "send"
    property string requestedDirection: ""
    property bool picking: false

    openWidth: picking ? Theme.panelWidth(modelData, Theme.pickerWidth) : Theme.panelWidth(modelData, Theme.nearbyWidth)
    openHeight: picking ? Theme.pickerHeight : (direction === "send" ? sendView.contentHeight : receiveView.contentHeight)
    openRadius: Theme.nearbyRadius

    // ---- staged files ----

    // Absolute paths, in the order they were added, and their sizes.
    property var files: []
    property var fileBytes: ({})
    readonly property bool hasFiles: files.length > 0
    readonly property real filesBytes: {
      var total = 0;
      for (var i = 0; i < files.length; i++)
        total += fileBytes[files[i]] > 0 ? fileBytes[files[i]] : 0;
      return total;
    }

    // Outbound transfers a tile must not show: sends from an earlier staging, and finished or
    // failed sends whose moment on the tile is over.
    property var ignoreIds: []
    // Transfer id -> when its tile lets it go (ms since epoch).
    property var settleAt: ({})

    // Keyed models for the device tiles and the arrivals: the daemon re-sends a peer on every
    // sighting and a transfer on every progress tick, and rebuilding the delegates each time
    // restarted their entrances and dropped their hover, so the rows flickered under the
    // pointer. These keep one delegate per id and only add, remove and reorder.
    ListModel {
      id: peerModel
    }

    ListModel {
      id: rowModel
    }

    function syncKeyed(model, ids) {
      for (var i = model.count - 1; i >= 0; i--) {
        if (ids.indexOf(model.get(i).key) === -1)
          model.remove(i);
      }
      for (var j = 0; j < ids.length; j++) {
        var at = -1;
        for (var k = j; k < model.count; k++) {
          if (model.get(k).key === ids[j]) {
            at = k;
            break;
          }
        }
        if (at === -1)
          model.insert(j, {
            "key": ids[j]
          });
        else if (at !== j)
          model.move(at, j, 1);
      }
    }

    function syncPeers() {
      syncKeyed(peerModel, Nearby.peersForMode.slice(0, 4).map(function (p) {
        return p.id;
      }));
    }

    function syncRows() {
      syncKeyed(rowModel, Nearby.receivedList.map(function (t) {
        return t.id;
      }));
    }

    Component.onCompleted: {
      syncPeers();
      syncRows();
    }

    function stage(paths) {
      if (!paths || paths.length === 0)
        return;
      if (!hasFiles)
        ignoreIds = Nearby.outboundIds();
      // Folders become their files; sizes come back with the list.
      stager.running = false;
      stager.command = ["sh", "-c", "for p; do if [ -d \"$p\" ]; then find -L \"$p\" -type f -not -path '*/.*' -printf '%s\\t%p\\n' 2>/dev/null | head -n 500; elif [ -e \"$p\" ]; then stat -L --printf '%s\\t%n\\n' -- \"$p\"; fi; done", "sh"].concat(paths);
      stager.running = true;
    }

    function removeFile(path) {
      files = files.filter(function (f) {
        return f !== path;
      });
    }

    function clearFiles() {
      files = [];
      fileBytes = {};
    }

    function chooseFiles() {
      picker.open(win.lastDir);
      picking = true;
    }

    property string lastDir: ""

    Process {
      id: stager

      stdout: StdioCollector {
        onStreamFinished: {
          var next = win.files.slice();
          var sizes = Object.assign({}, win.fileBytes);
          var lines = text.split("\n");
          for (var i = 0; i < lines.length; i++) {
            var tab = lines[i].indexOf("\t");
            if (tab < 0)
              continue;
            var p = lines[i].substring(tab + 1);
            sizes[p] = parseInt(lines[i].substring(0, tab), 10) || 0;
            if (next.indexOf(p) === -1)
              next.push(p);
          }
          win.fileBytes = sizes;
          win.files = next;
        }
      }
    }

    // A send's tile holds its result for a beat - the check for a delivery, the reason for a
    // failure - and then lets the transfer go. Once every send of the round has ended and one of
    // them delivered, the staged files clear and the panel is back at board 16a.
    function reviewRound() {
      var now = Date.now();
      var next = Object.assign({}, settleAt);
      var pending = false;
      for (var i = 0; i < Nearby.transfers.length; i++) {
        var t = Nearby.transfers[i];
        if (t.direction !== "out" || ignoreIds.indexOf(t.id) !== -1)
          continue;
        if (Nearby.isTerminalState(t.state) && next[t.id] === undefined)
          next[t.id] = now + (t.state === "finished" ? Theme.nearbySentDwell : Theme.nearbyFailDwell);
      }
      for (var k in next)
        pending = true;
      settleAt = next;
      if (pending)
        settleTimer.start();
    }

    Timer {
      id: settleTimer

      interval: 100
      repeat: true
      onTriggered: {
        var now = Date.now();
        var next = Object.assign({}, win.settleAt);
        var ignore = win.ignoreIds.slice();
        var delivered = false;
        var left = 0;
        for (var id in next) {
          if (now < next[id]) {
            left++;
            continue;
          }
          ignore.push(id);
          var t = Nearby.transferById(id);
          if (t && t.state === "finished")
            delivered = true;
          delete next[id];
        }
        win.settleAt = next;
        win.ignoreIds = ignore;
        if (delivered && left === 0 && !Nearby.outboundInFlight(ignore))
          win.clearFiles();
        if (left === 0)
          stop();
      }
    }

    Connections {
      target: Nearby

      function onTransfersChanged() {
        win.reviewRound();
      }

      function onPeersForModeChanged() {
        win.syncPeers();
      }

      function onReceivedListChanged() {
        win.syncRows();
      }

      function onSendRequested(paths) {
        win.requestedDirection = "send";
        win.direction = "send";
        win.picking = false;
        win.stage(paths);
      }

      function onReceiveRequested() {
        win.requestedDirection = "receive";
        win.direction = "receive";
        win.picking = false;
      }

      function onForceOpen() {
        // Each Variants delegate checks its own focus, so only one opens.
        if (!win.open && win.focused)
          win.show();
      }
    }

    onOpening: {
      direction = requestedDirection !== "" ? requestedDirection : "send";
      requestedDirection = "";
      picking = false;
    }

    onOpenChanged: {
      if (open) {
        // Android is the default: an AirDrop window left from an earlier open (it holds the
        // Wi-Fi) goes back, unless a transfer is riding it.
        if (Nearby.mode === "apple" && !Nearby.busy && !Nearby.appleTransferActive)
          Nearby.setMode("android");
        if (direction === "send")
          Nearby.scanOn(0);
        else
          Nearby.turnOnForever();
      } else {
        Nearby.scanOff();
        picking = false;
        previewActive = false;
        if (Nearby.mode === "apple" && !Nearby.busy && !Nearby.appleTransferActive)
          Nearby.setMode("android");
        if (!Nearby.outboundInFlight(ignoreIds))
          clearFiles();
      }
    }

    onDirectionChanged: {
      if (!open)
        return;
      previewActive = false;
      if (direction === "send") {
        Nearby.scanOn(0);
      } else {
        // Receiving means visible, until switched off from the chip: a phone's own "Everyone"
        // window lasts ten minutes, so ours should not run out under it.
        Nearby.scanOff();
        if (!Nearby.receivable)
          Nearby.turnOnForever();
      }
    }

    onKeyPressed: function (event) {
      if (picking) {
        picker.handleKey(event);
        return;
      }
      if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
        direction = direction === "send" ? "receive" : "send";
        event.accepted = true;
      } else if (direction === "send" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
        chooseFiles();
        event.accepted = true;
      }
    }

    // ---- the hover preview, drawn past the card's clip ----

    property bool previewActive: false
    property string previewPath: ""
    property real previewX: 0
    property real previewY: 0

    overlay: [
      HoverPreview {
        active: win.previewActive && win.open && !win.picking
        path: win.previewPath
        anchorX: win.previewX
        anchorY: win.previewY
      }
    ]

    // ---- the header both directions share ----

    component Header: Item {
      width: Theme.nearbyWidth
      height: Theme.nearbyHeaderHeight

      SegmentedTrack {
        x: Theme.nearbyHeaderSide
        currentIndex: Nearby.mode === "apple" ? 1 : 0
        pending: Nearby.busy
        segments: [
          {
            "icon": IconPaths.robotHead,
            "label": "Android"
          },
          {
            "icon": IconPaths.apple,
            "label": "Apple",
            "filled": true
          }
        ]
        onChosen: function (index) {
          Nearby.setMode(index === 1 ? "apple" : "android");
        }
      }

      SegmentedTrack {
        x: Theme.nearbyWidth - Theme.nearbyHeaderSide - Theme.nearbyTrackWidth
        currentIndex: win.direction === "receive" ? 1 : 0
        segments: [
          {
            "icon": IconPaths.arrowUp,
            "label": "Send"
          },
          {
            "icon": IconPaths.arrowDown,
            "label": "Receive"
          }
        ]
        onChosen: function (index) {
          win.direction = index === 1 ? "receive" : "send";
        }
      }
    }

    // A section line: the tertiary label on the left, whatever sits on the right.
    component SectionLine: Item {
      id: line

      property string label: ""
      // A secondary note right after the label ("3 · 18.4 MB").
      property string detail: ""
      default property alias trailing: trailingRow.data

      width: Theme.nearbyWidth
      height: 14

      Text {
        id: labelText

        x: Theme.nearbySectionSide
        anchors.verticalCenter: parent.verticalCenter
        text: line.label
        color: Theme.inkTertiary
        font.family: Theme.uiFont
        font.pixelSize: Theme.nearbySectionSize
        font.weight: Theme.weightMedium
      }

      Text {
        x: labelText.x + labelText.implicitWidth + 8
        anchors.verticalCenter: parent.verticalCenter
        visible: line.detail !== ""
        text: line.detail
        color: Theme.inkSecondary
        font.family: Theme.uiFont
        font.pixelSize: Theme.nearbySectionSize
        font.weight: Theme.weightMedium
      }

      Row {
        id: trailingRow

        anchors.right: parent.right
        anchors.rightMargin: Theme.nearbySectionSide
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5
      }
    }

    // A capped list that scrolls fades out at the bottom edge while there is more below.
    component ScrollFade: Rectangle {
      required property Flickable list

      x: list.x
      y: list.y + list.height - height
      width: list.width
      height: 22
      opacity: list.contentHeight > list.height + 1 && !list.atYEnd ? 1 : 0
      visible: opacity > 0

      Behavior on opacity {
        Morph {
          duration: Theme.morphState
        }
      }

      gradient: Gradient {
        GradientStop {
          position: 0
          color: Theme.withAlpha(Theme.surface, 0)
        }

        GradientStop {
          position: 1
          color: Theme.surface
        }
      }
    }

    // An accent glyph + label link in a section line ("+ Add", "Downloads").
    component SectionLink: Item {
      id: link

      property string icon: ""
      property string label: ""
      property int glyph: 12

      signal clicked

      implicitWidth: linkRow.implicitWidth
      implicitHeight: 14

      Row {
        id: linkRow

        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        StrokeIcon {
          anchors.verticalCenter: parent.verticalCenter
          size: link.glyph
          strokeWidth: 1.8
          path: link.icon
          color: Theme.accentFill
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: link.label
          color: Theme.accentFill
          font.family: Theme.uiFont
          font.pixelSize: Theme.nearbySectionSize
          font.weight: Theme.weightMedium
        }
      }

      opacity: linkArea.pressed ? 0.7 : 1

      MouseArea {
        id: linkArea

        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: link.clicked()
      }

      Accessible.role: Accessible.Button
      Accessible.name: link.label
      Accessible.onPressAction: link.clicked()
    }

    // ================= Send =================

    Item {
      id: sendView

      x: (parent.width - Theme.nearbyWidth) / 2
      width: Theme.nearbyWidth
      height: contentHeight
      opacity: win.direction === "send" && !win.picking ? 1 : 0
      visible: opacity > 0
      enabled: visible

      readonly property int shownPeers: peerModel.count
      readonly property int visibleRows: Math.min(win.files.length, Theme.nearbyFilesMax)
      readonly property real rowsHeight: visibleRows > 0 ? visibleRows * Theme.nearbyFileHeight + (visibleRows - 1) * Theme.nearbyFileGap : 0

      // Board 16a: button 74-118, Nearby at 138, tiles at 160; 16e: Files at 80, rows from
      // 100 on a 46 px pitch, Nearby 20 below the last row.
      readonly property real nearbyY: win.hasFiles ? Theme.nearbyPadTop + Theme.nearbyHeaderHeight + Theme.nearbySectionTop + 14 + Theme.nearbySectionToRows + rowsHeight + 20 : Theme.nearbyPadTop + Theme.nearbyHeaderHeight + Theme.nearbyBodyGap + Theme.nearbyChooseHeight + 20
      readonly property real tilesY: nearbyY + 22
      readonly property real tileHeight: Theme.nearbyDeviceSize + Theme.nearbyDeviceNameGap + 14 + (win.hasFiles ? Theme.nearbyDeviceSubGap + Theme.nearbyDeviceSubHeight : 0)
      readonly property real contentHeight: tilesY + tileHeight + Theme.nearbyPadBottom

      Behavior on opacity {
        Morph {
          duration: Theme.morphContent
        }
      }

      Header {
        y: Theme.nearbyPadTop
      }

      // Board 16a: one full-width accent button while nothing is staged.
      Rectangle {
        id: chooseButton

        x: Theme.nearbyInset
        y: Theme.nearbyPadTop + Theme.nearbyHeaderHeight + Theme.nearbyBodyGap
        width: Theme.nearbyWidth - Theme.nearbyInset * 2
        height: Theme.nearbyChooseHeight
        radius: Theme.nearbyChooseRadius
        color: chooseArea.containsMouse ? Qt.lighter(Theme.accentFill, 1.06) : Theme.accentFill
        opacity: win.hasFiles ? 0 : 1
        visible: opacity > 0
        scale: chooseArea.pressed ? Theme.pressScale : 1

        Behavior on opacity {
          Morph {
            duration: Theme.morphContent
          }
        }

        Behavior on scale {
          Morph {
            duration: Theme.morphState
          }
        }

        Behavior on color {
          Tint {}
        }

        Row {
          anchors.centerIn: parent
          spacing: 8

          StrokeIcon {
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.nearbyChooseGlyph
            strokeWidth: 2.1
            path: IconPaths.plus
            color: Theme.inkOnAccent
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Choose files"
            color: Theme.inkOnAccent
            font.family: Theme.uiFont
            font.pixelSize: Theme.nearbyChooseSize
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

      // Board 16e: "Files 3 · 18.4 MB" with an accent "+ Add", then one row per file.
      SectionLine {
        y: Theme.nearbyPadTop + Theme.nearbyHeaderHeight + Theme.nearbySectionTop
        label: "Files"
        detail: win.files.length + (win.filesBytes > 0 ? " · " + Nearby.sizeLabel(win.filesBytes) : "")
        opacity: win.hasFiles ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          Morph {
            duration: Theme.morphContent
          }
        }

        SectionLink {
          icon: IconPaths.plus
          label: "Add"
          onClicked: win.chooseFiles()
        }

      }

      ListView {
        id: fileList

        x: Theme.nearbyInset
        y: Theme.nearbyPadTop + Theme.nearbyHeaderHeight + Theme.nearbySectionTop + 14 + Theme.nearbySectionToRows
        width: Theme.nearbyWidth - Theme.nearbyInset * 2
        height: sendView.rowsHeight
        visible: win.hasFiles
        clip: true
        spacing: Theme.nearbyFileGap
        interactive: win.files.length > Theme.nearbyFilesMax
        boundsBehavior: Flickable.StopAtBounds
        model: win.files

        delegate: StagedFileRow {
          required property string modelData

          width: fileList.width
          path: modelData
          bytes: win.fileBytes[modelData] !== undefined ? win.fileBytes[modelData] : -1
          onRemoveClicked: win.removeFile(modelData)
        }

        add: Transition {
          NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.duration(160)
          }
        }
      }

      ScrollFade {
        list: fileList
      }

      // "Nearby", and what the stack is doing on the right: a daemon notice, the gold Wi-Fi
      // note in Apple mode (16f), or Scanning… (16a).
      SectionLine {
        y: sendView.nearbyY
        label: "Nearby"

        StrokeIcon {
          visible: Nearby.noticeText === "" && Nearby.wifiPaused
          anchors.verticalCenter: parent.verticalCenter
          size: 14
          strokeWidth: 1.8
          path: IconPaths.wifiOff
          color: Theme.gold
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: Math.min(implicitWidth, Theme.nearbyWidth - 120)
          elide: Text.ElideRight
          text: Nearby.noticeText !== "" ? Nearby.noticeText : Nearby.busy ? (Nearby.mode === "apple" ? "Starting AirDrop…" : "Switching…") : Nearby.wifiPaused ? "Wi-Fi paused" : Nearby.scanning ? "Scanning…" : ""
          color: Nearby.noticeText !== "" ? (Nearby.noticeLevel === "error" ? Theme.love : Theme.inkSecondary) : Nearby.wifiPaused ? Theme.gold : Theme.accentFill
          font.family: Theme.uiFont
          font.pixelSize: Theme.nearbySectionSize
          font.weight: Theme.weightMedium

          Behavior on color {
            Tint {}
          }
        }
      }

      // The tiles: 56 px discs centred on 120 px columns, the row centred on the panel.
      Row {
        x: (Theme.nearbyWidth - sendView.shownPeers * Theme.nearbyDeviceSlot) / 2
        y: sendView.tilesY

        Behavior on x {
          enabled: !Theme.reduceMotion

          SurfaceSpring {}
        }

        Repeater {
          model: peerModel

          DeviceTile {
            required property string key

            readonly property var peerData: Nearby.peerById(key)

            width: Theme.nearbyDeviceSlot
            peer: peerData
            filesReady: win.hasFiles
            transfer: Nearby.outgoingFor(peerData, win.ignoreIds)
            onTapped: if (peerData)
              Nearby.send(win.files, peerData.id)
            onCancelTapped: {
              if (transfer && transfer.id)
                Nearby.cancel(transfer.id);
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
      opacity: win.picking ? 1 : 0
      visible: opacity > 0
      enabled: win.picking

      Behavior on opacity {
        Morph {
          duration: Theme.morphContent
        }
      }

      onDirChanged: win.lastDir = dir
      onAccepted: function (paths) {
        win.picking = false;
        win.stage(paths);
      }
      onCancelled: win.picking = false
    }

    // ================= Receive =================

    Item {
      id: receiveView

      x: (parent.width - Theme.nearbyWidth) / 2
      width: Theme.nearbyWidth
      height: contentHeight
      opacity: win.direction === "receive" && !win.picking ? 1 : 0
      visible: opacity > 0
      enabled: visible

      readonly property int rowCount: rowModel.count
      readonly property int visibleRows: Math.min(rowCount, Theme.nearbyRowsMax)
      readonly property real radarY: Theme.nearbyPadTop + Theme.nearbyHeaderHeight + Theme.nearbyRadarTop
      readonly property real chipsBottom: radarY + radar.implicitHeight
      readonly property real noticeHeight: Nearby.noticeText !== "" ? 22 : 0
      readonly property real cardsTop: chipsBottom + noticeHeight
      readonly property real receivedY: cardsTop + (cards.height > 0 ? cards.height + Theme.nearbyReceivedAfterCard : Theme.nearbyReceivedGap)
      readonly property real rowsY: receivedY + 14 + 6
      readonly property real rowsHeight: visibleRows > 0 ? visibleRows * Theme.nearbyRowHeight + (visibleRows - 1) * Theme.nearbyRowGap : 0
      readonly property real contentHeight: rowCount > 0 ? rowsY + rowsHeight + Theme.nearbyReceiveBottom : cardsTop + (cards.height > 0 ? cards.height + Theme.nearbyPadBottom : Theme.nearbyPadBottom + 4)

      Behavior on opacity {
        Morph {
          duration: Theme.morphContent
        }
      }

      Header {
        y: Theme.nearbyPadTop
      }

      RadarView {
        id: radar

        y: receiveView.radarY
        width: Theme.nearbyWidth
        deviceName: Nearby.deviceName
        remainingLabel: Nearby.remainingLabel
        receivable: Nearby.receivable
        wifiPaused: Nearby.wifiPaused
        onTimerClicked: Nearby.receivable ? Nearby.turnOff() : Nearby.turnOnForever()
      }

      Text {
        visible: Nearby.noticeText !== ""
        x: Theme.nearbySectionSide
        y: receiveView.chipsBottom + 8
        width: Theme.nearbyWidth - Theme.nearbySectionSide * 2
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: Nearby.noticeText
        color: Nearby.noticeLevel === "error" ? Theme.love : Theme.inkSecondary
        font.family: Theme.uiFont
        font.pixelSize: Theme.nearbySectionSize
        font.weight: Theme.weightMedium
      }

      // Consent cards (board 16g). A request animates in and stays until it is answered - or
      // until the transfer behind it fails, when it animates out on its own. The model keeps a
      // card a moment past its request so the way out can be seen.
      ListModel {
        id: cardModel
      }

      function syncCards() {
        var live = {};
        var pending = Nearby.pendingInbound;
        for (var i = 0; i < pending.length; i++)
          live[pending[i].id] = pending[i];
        for (var j = 0; j < cardModel.count; j++) {
          var id = cardModel.get(j).tid;
          if (live[id]) {
            cardModel.setProperty(j, "snapshot", JSON.stringify(live[id]));
            cardModel.setProperty(j, "live", true);
            delete live[id];
          } else if (cardModel.get(j).live) {
            cardModel.setProperty(j, "live", false);
          }
        }
        for (var k in live)
          cardModel.append({
            "tid": k,
            "live": true,
            "snapshot": JSON.stringify(live[k])
          });
      }

      Connections {
        target: Nearby

        function onPendingInboundChanged() {
          receiveView.syncCards();
        }
      }

      Component.onCompleted: syncCards()

      Column {
        id: cards

        y: receiveView.cardsTop
        width: Theme.nearbyWidth

        Repeater {
          model: cardModel

          Item {
            id: cardSlot

            required property string tid
            required property bool live
            required property string snapshot
            required property int index

            width: Theme.nearbyWidth
            clip: true

            // 0 -> 1 as the card arrives, back to 0 as it leaves; the slot's height rides it,
            // so the list below slides rather than jumps.
            property real shown: 0
            readonly property real full: Theme.nearbyIncomingTop + Theme.nearbyIncomingHeight

            height: full * shown
            Component.onCompleted: shown = live ? 1 : 0
            onLiveChanged: shown = live ? 1 : 0
            onShownChanged: if (!live && shown <= 0.001)
              Qt.callLater(function () {
                for (var i = 0; i < cardModel.count; i++) {
                  if (cardModel.get(i).tid === cardSlot.tid && !cardModel.get(i).live) {
                    cardModel.remove(i);
                    break;
                  }
                }
              })

            Behavior on shown {
              NumberAnimation {
                duration: Theme.duration(cardSlot.live ? 260 : 200)
                easing.type: cardSlot.live ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 1.2
              }
            }

            IncomingCard {
              x: Theme.nearbyInset
              y: Theme.nearbyIncomingTop
              transfer: JSON.parse(cardSlot.snapshot)
              opacity: Math.min(1, cardSlot.shown * 1.4)
              scale: 0.96 + 0.04 * Math.min(1, cardSlot.shown)
              enabled: cardSlot.live
              onAccepted: Nearby.accept(cardSlot.tid)
              onDeclined: Nearby.decline(cardSlot.tid)
            }
          }
        }
      }

      SectionLine {
        y: receiveView.receivedY
        label: "Received"
        visible: receiveView.rowCount > 0

        SectionLink {
          icon: IconPaths.folder
          glyph: 14
          label: "Downloads"
          onClicked: Nearby.openDownloads()
        }
      }

      ListView {
        id: receivedList

        y: receiveView.rowsY
        x: Theme.nearbyInset
        width: Theme.nearbyWidth - Theme.nearbyInset * 2
        height: receiveView.rowsHeight
        spacing: Theme.nearbyRowGap
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        model: rowModel
        // Hovering a row while the list moves would leave the preview behind it.
        onContentYChanged: win.previewActive = false

        delegate: ReceivedRow {
            id: receivedRow

            required property string key

            width: receivedList.width
            transfer: Nearby.transferById(key)
            fresh: Nearby.freshArrival === key
            progress: Nearby.progressOf(transfer)
            onClicked: Nearby.openFile(receivedRow.path)
            onHoverMoved: function (lx, ly) {
              if (!receivedRow.done || receivedRow.path === "") {
                win.previewActive = false;
                return;
              }
              // Into the card, then the window: a PanelWindow is not an Item to map onto, but
              // the overlay shares the window's origin and the card's offset is known.
              var p = receivedRow.mapToItem(win.surface, lx, ly);
              win.previewX = win.surface.x + p.x;
              win.previewY = win.surface.y + p.y;
              win.previewPath = receivedRow.path;
              win.previewActive = true;
            }
            onHoverExited: win.previewActive = false
          }
      }

      ScrollFade {
        list: receivedList
      }
    }
  }
}
