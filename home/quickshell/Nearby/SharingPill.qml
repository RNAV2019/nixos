import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Bar.Widgets
import qs.Commons
import qs.Services
import qs.Ui

// The Sharing Pill (boards 16i-16l): how an incoming share reaches you while the Sharing Panel
// is shut. The island grows out of its pill into: connecting (a phone is handshaking, 278 x 42)
// -> request (sender, payload, PIN, Decline / Accept; 420 x 64) -> receiving (an OSD-style
// track with the percentage and an × to cancel) -> saved (a check, the file's name and Open),
// and after a short dwell melts back into the clock. A request stays until it is answered; if
// the transfer behind it fails, the request goes with it. With the panel open, its own consent
// card takes over and the pill keeps out of the way.
Scope {
  id: root

  // The saved state outlives its transfer row, so it is held here for its dwell.
  property string savedId: ""
  property string savedName: ""
  property string savedPath: ""

  Timer {
    id: savedTimer

    interval: Theme.sharingConfirmDwell
    onTriggered: root.clearSaved()
  }

  function clearSaved() {
    savedTimer.stop();
    savedId = "";
    savedName = "";
    savedPath = "";
  }

  // The live request, if any.
  readonly property var offer: Nearby.pendingInbound.length > 0 ? Nearby.pendingInbound[0] : null

  // The live inbound download, newest first.
  readonly property var activeTransfer: {
    var list = Nearby.receivedList;
    for (var i = 0; i < list.length; i++) {
      if (list[i].state === "in_progress")
        return list[i];
    }
    return null;
  }
  readonly property real activeProgress: activeTransfer ? Nearby.progressOf(activeTransfer) : 0

  // A phone mid-handshake, nothing to answer yet. Only a recent one: a handshake that has gone
  // quiet is not worth holding the island for.
  readonly property var connecting: {
    var list = Nearby.inboundConnecting;
    var now = Date.now() / 1000;
    for (var i = 0; i < list.length; i++) {
      if (now - (list[i].started || 0) < 45)
        return list[i];
    }
    return null;
  }

  // "request" | "receiving" | "saved" | "connecting" | "" - one at a time, most urgent first.
  readonly property string mode: offer !== null ? "request" : activeTransfer !== null ? "receiving" : savedId !== "" ? "saved" : connecting !== null ? "connecting" : ""

  // Arm the saved state when the download being shown finishes. Only that row confirms: a
  // fallback to some other finished row would show "saved" for a transfer that failed.
  property string lastActiveId: ""

  onActiveTransferChanged: {
    if (activeTransfer) {
      lastActiveId = activeTransfer.id;
      return;
    }
    if (lastActiveId === "")
      return;
    var done = Nearby.transferById(lastActiveId);
    lastActiveId = "";
    if (done && done.state === "finished") {
      var paths = done.saved_paths || [];
      savedId = done.id;
      savedName = Nearby.transferName(done);
      savedPath = paths.length > 0 ? String(paths[0]) : "";
      savedTimer.restart();
    }
  }

  // A row cleared from the daemon takes its saved state with it.
  Connections {
    target: Nearby

    function onTransfersChanged() {
      if (root.savedId !== "" && Nearby.transferById(root.savedId) === null)
        root.clearSaved();
    }
  }

  Variants {
    model: Quickshell.screens

    // A request outranks a toast, since it waits for an answer; the progress and the
    // confirmations rank under one, and wait behind it. The OSD outranks both.
    TransientSurface {
      id: win

      key: "sharing"
      rank: root.mode === "request" ? 2 : 0

      readonly property bool panelOpen: Bus.surfaceOpen("nearby")
      readonly property bool outputBlocked: Bus.islandOpenFor(win.screenName) || panelOpen

      wanted: root.mode !== "" && win.focused && !win.outputBlocked

      // The last mode shown, held while the shape melts back so its contents fade rather than
      // blink out with the state that ended.
      property string shownMode: ""

      readonly property bool big: shownMode === "request"

      openWidth: big ? Theme.sharingOfferWidth : Theme.islandPillWidth
      openHeight: big ? Theme.sharingOfferHeight : Theme.islandPillHeight
      openRadius: big ? Theme.sharingOfferRadius : Theme.islandPillRadius

      // Click-through while only connecting; the card takes input when it has buttons.
      cardInput: win.shownMode !== "connecting"

      onOpening: win.shownMode = root.mode

      Connections {
        target: root

        function onModeChanged() {
          if (root.mode !== "")
            win.shownMode = root.mode;
        }
      }

      // ---- 16i connecting ----
      SharingState {
        name: "connecting"

        IslandPill {
          anchors.fill: parent
          layout: "glyphLabelDetailDots"
          label: "Connecting…"
          detail: root.connecting && root.connecting.peer ? root.connecting.peer : ""
          running: win.open

          StrokeIcon {
            anchors.centerIn: parent
            size: Theme.islandPillGlyphSize
            strokeWidth: 1.75
            path: IconPaths.smartphone
            color: Theme.inkSecondary
          }
        }
      }

      // ---- 16j request ----
      SharingState {
        name: "request"
        stateWidth: Theme.sharingOfferWidth
        stateHeight: Theme.sharingOfferHeight

        StrokeIcon {
          x: 16
          y: (parent.height - size) / 2
          size: 20
          strokeWidth: 1.75
          path: IconPaths.smartphone
          color: Theme.accentFill
        }

        Text {
          x: 48
          y: 13
          width: pin.x - x - 12
          elide: Text.ElideRight
          text: root.offer && root.offer.peer ? root.offer.peer : "Unknown device"
          color: Theme.inkPrimary
          font.family: Theme.uiFont
          font.pixelSize: Theme.nearbyRowNameSize
          font.weight: Theme.weightSemi
        }

        Text {
          x: 48
          y: 33
          width: pin.x - x - 12
          elide: Text.ElideMiddle
          text: Nearby.payloadLabel(root.offer)
          color: Theme.inkSecondary
          font.family: Theme.uiFont
          font.pixelSize: Theme.nearbyIncomingMetaSize
        }

        Text {
          id: pin

          x: decline.x - 10 - width
          y: (parent.height - height) / 2
          text: root.offer && root.offer.pin ? root.offer.pin : ""
          color: Theme.inkPrimary
          font.family: Theme.monoFont
          font.pixelSize: 12
          font.weight: Theme.weightSemi
          font.letterSpacing: 1
        }

        Button {
          id: decline

          x: accept.x - 8 - width
          y: (parent.height - height) / 2
          kind: Button.Ghost
          size: Button.Compact
          text: "Decline"
          onClicked: if (root.offer)
            Nearby.decline(root.offer.id)
        }

        Button {
          id: accept

          x: parent.width - 16 - width
          y: (parent.height - height) / 2
          kind: Button.Primary
          size: Button.Compact
          text: "Accept"
          onClicked: if (root.offer)
            Nearby.accept(root.offer.id)
        }
      }

      // ---- 16k receiving ----
      SharingState {
        name: "receiving"

        IslandPill {
          anchors.fill: parent
          layout: "glyphTrackReadingAction"
          reading: Math.round(Theme.clamp01(root.activeProgress) * 100) + "%"
          tabularReading: true
          value: root.activeProgress
          running: win.open
          onCancelled: if (root.activeTransfer)
            Nearby.cancel(root.activeTransfer.id)

          StrokeIcon {
            anchors.centerIn: parent
            size: Theme.islandPillGlyphSize
            strokeWidth: 1.75
            path: IconPaths.smartphone
            color: Theme.inkPrimary
          }
        }
      }

      // ---- 16l saved ----
      SharingState {
        name: "saved"

        IslandPill {
          anchors.fill: parent
          layout: "glyphLabelReading"
          label: root.savedName !== "" ? root.savedName : "Saved"
          labelElide: Text.ElideMiddle
          reading: "Open"
          readingColor: Theme.accentFill

          StrokeIcon {
            anchors.centerIn: parent
            size: Theme.islandPillGlyphSize
            strokeWidth: 2
            path: IconPaths.check
            color: Theme.accentFill
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          // Hovering holds the pill so Open is not pulled out from under the pointer.
          onContainsMouseChanged: {
            if (containsMouse)
              savedTimer.stop();
            else if (root.savedId !== "")
              savedTimer.restart();
          }
          onClicked: {
            if (root.savedPath !== "")
              Nearby.openFile(root.savedPath);
            else
              Nearby.openDownloads();
            root.clearSaved();
          }
        }
      }
    }
  }

  // Each state is laid out at its final size and centred, so the growing shape reveals it.
  // The open and the close are the card's own fade; this only crosses between states.
  component SharingState: PillState {
    property string name: ""
    property real stateWidth: Theme.islandPillWidth
    property real stateHeight: Theme.islandPillHeight

    x: (win.surface.width - stateWidth) / 2
    y: (win.surface.height - stateHeight) / 2
    width: stateWidth
    height: stateHeight
    shown: win.shownMode === name
    open: win.open
  }
}
