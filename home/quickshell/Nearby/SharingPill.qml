import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Bar.Widgets
import qs.Commons
import qs.Services
import qs.Ui

// The Sharing Pill (boards 16i-16l): how an incoming share reaches you while the Sharing Panel
// is shut. The island grows out of its pill into: connecting (a phone is handshaking, 278 x 48)
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

    PanelWindow {
      id: win

      required property var modelData

      readonly property bool focused: Monitors.isFocused(win.screen)
      readonly property string screenName: win.screen ? win.screen.name : ""
      readonly property int collapsedWidth: Theme.islandCollapsedWidth(Media.active, Recorder.recording)

      readonly property bool panelOpen: Bus.ownerOf("nearby") !== ""
      readonly property bool outputBlocked: Bus.islandHeldFor(screenName) || panelOpen
      readonly property bool wantsOpen: root.mode !== "" && focused && !outputBlocked
      property bool open: false

      // The last mode shown, held while the shape melts back so its contents fade rather than
      // blink out with the state that ended.
      property string shownMode: ""

      readonly property bool big: shownMode === "request"
      readonly property real targetW: big ? Theme.sharingOfferWidth : Theme.sharingProgressWidth
      readonly property real targetH: big ? Theme.sharingOfferHeight : Theme.sharingProgressHeight
      readonly property real targetR: big ? Theme.sharingOfferRadius : Theme.sharingProgressRadius

      onWantsOpenChanged: {
        if (wantsOpen && !open) {
          shownMode = root.mode;
          origin.claim(targetW, targetH, targetR, Theme.morphSurface);
          open = true;
        } else if (!wantsOpen && open) {
          open = false;
          origin.release();
        }
      }

      Connections {
        target: root

        function onModeChanged() {
          if (root.mode !== "")
            win.shownMode = root.mode;
        }
      }

      readonly property bool visibleNow: open || origin.held || surface.width > collapsedWidth + 0.5

      IslandOrigin {
        id: origin

        window: win
      }

      Connections {
        target: Bus

        function onSurfacesClosingForLock() {
          win.open = false;
          origin.release();
        }

        // The panel or another surface taking the island takes it from the pill too.
        function onIslandClaimed(screen) {
          if (!win.open || !win.screen || screen !== win.screen.name)
            return;
          origin.publish(surface.width, surface.height, surface.surfaceRadius);
          origin.hold(surface.width, surface.height, surface.surfaceRadius);
          win.open = false;
        }
      }

      screen: modelData
      visible: !Bus.locking && visibleNow
      color: "transparent"

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "quickshell-sharing"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      anchors {
        top: true
        left: true
        right: true
      }

      implicitHeight: Theme.barMarginTop + Theme.sharingOfferHeight + Theme.gapsOut
      exclusionMode: ExclusionMode.Ignore

      // Click-through while shut or only connecting; the card takes input when it has buttons.
      mask: win.open && win.shownMode !== "connecting" ? cardMask : emptyMask

      Region {
        id: emptyMask
      }

      Region {
        id: cardMask

        item: surface
      }

      onVisibleNowChanged: {
        if (visibleNow)
          Bus.setTransientScreen("sharing", screenName);
        else if (screenName !== "" && Bus.transientScreen("sharing") === screenName)
          Bus.setTransientScreen("sharing", "");
      }

      FrostedSurface {
        id: surface

        x: snap((win.width - width) / 2)
        y: snap(Theme.barMarginTop)
        clipContent: true

        implicitWidth: win.open ? win.targetW : origin.held ? origin.heldWidth : origin.originWidth
        implicitHeight: win.open ? win.targetH : origin.held ? origin.heldHeight : origin.originHeight
        surfaceRadius: Math.min(height / 2, win.targetR)

        Behavior on implicitWidth {
          enabled: !Theme.reduceMotion && !origin.snapping

          SurfaceSpring {}
        }

        Behavior on implicitHeight {
          enabled: !Theme.reduceMotion && !origin.snapping

          SurfaceSpring {}
        }

        CollapsedPill {
          anchors.fill: parent
          origin: origin
          shown: !win.open && !origin.held
        }

        // Each state is laid out at its final size and centred, so the growing shape reveals it.
        component PillState: Item {
          property string name: ""
          property real stateWidth: Theme.sharingProgressWidth
          property real stateHeight: Theme.sharingProgressHeight

          x: (surface.width - stateWidth) / 2
          y: (surface.height - stateHeight) / 2
          width: stateWidth
          height: stateHeight
          opacity: win.open && win.shownMode === name ? 1 : 0
          visible: opacity > 0
          enabled: opacity > 0.5

          Behavior on opacity {
            Morph {
              duration: Theme.morphContent * 2
            }
          }
        }

        // ---- 16i connecting ----
        PillState {
          name: "connecting"

          StrokeIcon {
            x: 20
            y: (parent.height - size) / 2
            size: 18
            strokeWidth: 1.75
            path: IconPaths.smartphone
            color: Theme.inkSecondary
          }

          Row {
            x: 52
            y: (parent.height - height) / 2
            width: 180

            Text {
              id: connectingLabel

              text: "Connecting… "
              color: Theme.inkSecondary
              font.family: Theme.uiFont
              font.pixelSize: 12
              font.weight: Theme.weightMedium
            }

            Text {
              width: 180 - connectingLabel.implicitWidth
              elide: Text.ElideRight
              text: root.connecting && root.connecting.peer ? root.connecting.peer : ""
              color: Theme.inkPrimary
              font.family: Theme.uiFont
              font.pixelSize: 12
              font.weight: Theme.weightMedium
            }
          }

          // Three dots passing a beat along, brightest first.
          Row {
            id: dots

            x: 238
            y: (parent.height - 6) / 2
            spacing: 4

            property real beat: 0

            NumberAnimation on beat {
              from: 0
              to: 3
              duration: 1200
              loops: Animation.Infinite
              running: win.open && win.shownMode === "connecting" && !Theme.reduceMotion
            }

            Repeater {
              model: 3

              Rectangle {
                required property int index

                width: 6
                height: 6
                radius: 3
                // Distance behind the beat, wrapped: 0 is lit, then 0.55, then 0.25 (board 16i).
                readonly property real lag: ((dots.beat - index) % 3 + 3) % 3
                color: Theme.withAlpha(Theme.accentFill, lag < 1 ? 1 - 0.45 * lag : lag < 2 ? 0.55 - 0.3 * (lag - 1) : 0.25 + 0.75 * (lag - 2))
              }
            }
          }
        }

        // ---- 16j request ----
        PillState {
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

          Rectangle {
            id: decline

            x: accept.x - 8 - width
            y: (parent.height - height) / 2
            width: 64
            height: Theme.nearbyAnswerHeight
            radius: height / 2
            color: declineArea.containsMouse ? Theme.withAlpha(Theme.inkPrimary, 0.06) : "transparent"
            border.width: 1
            border.color: Theme.withAlpha(Theme.separator, 0.7)
            scale: declineArea.pressed ? Theme.pressScale : 1

            Behavior on scale {
              Morph {
                duration: Theme.morphState
              }
            }

            Text {
              anchors.centerIn: parent
              text: "Decline"
              color: Theme.inkPrimary
              font.family: Theme.uiFont
              font.pixelSize: 11
              font.weight: Theme.weightSemi
            }

            MouseArea {
              id: declineArea

              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (root.offer)
                Nearby.decline(root.offer.id)
            }
          }

          Rectangle {
            id: accept

            x: parent.width - 16 - width
            y: (parent.height - height) / 2
            width: 66
            height: Theme.nearbyAnswerHeight
            radius: height / 2
            color: acceptArea.containsMouse ? Qt.lighter(Theme.accentFill, 1.06) : Theme.accentFill
            scale: acceptArea.pressed ? Theme.pressScale : 1

            Behavior on scale {
              Morph {
                duration: Theme.morphState
              }
            }

            Text {
              anchors.centerIn: parent
              text: "Accept"
              color: Theme.inkOnAccent
              font.family: Theme.uiFont
              font.pixelSize: 11
              font.weight: Theme.weightSemi
            }

            MouseArea {
              id: acceptArea

              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (root.offer)
                Nearby.accept(root.offer.id)
            }
          }
        }

        // ---- 16k receiving ----
        PillState {
          name: "receiving"

          StrokeIcon {
            x: 20
            y: (parent.height - size) / 2
            size: 18
            strokeWidth: 1.75
            path: IconPaths.smartphone
            color: Theme.inkPrimary
          }

          Rectangle {
            x: 52
            y: (parent.height - height) / 2
            width: 140
            height: 8
            radius: 4
            color: Theme.surfaceSubtle

            Rectangle {
              width: parent.width * Theme.clamp01(root.activeProgress)
              height: parent.height
              radius: parent.radius
              color: Theme.accentFill

              Behavior on width {
                enabled: !Theme.reduceMotion

                NumberAnimation {
                  duration: 250
                  easing.type: Easing.OutCubic
                }
              }
            }
          }

          Text {
            x: 202
            y: (parent.height - height) / 2
            text: Math.round(Theme.clamp01(root.activeProgress) * 100) + "%"
            color: Theme.inkPrimary
            font.family: Theme.uiFont
            font.pixelSize: 12
            font.weight: Theme.weightSemi
            font.features: {
              "tnum": 1
            }
          }

          StrokeIcon {
            x: 246
            y: (parent.height - size) / 2
            size: 12
            strokeWidth: 1.6
            path: IconPaths.x
            color: cancelArea.containsMouse ? Theme.inkPrimary : Theme.inkSecondary

            MouseArea {
              id: cancelArea

              anchors.fill: parent
              anchors.margins: -8
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (root.activeTransfer)
                Nearby.cancel(root.activeTransfer.id)
            }
          }
        }

        // ---- 16l saved ----
        PillState {
          name: "saved"

          StrokeIcon {
            x: 20
            y: (parent.height - size) / 2
            size: 18
            strokeWidth: 2
            path: IconPaths.check
            color: Theme.accentFill
          }

          Text {
            x: 52
            y: (parent.height - height) / 2
            width: openLabel.x - x - 12
            elide: Text.ElideMiddle
            text: root.savedName !== "" ? root.savedName : "Saved"
            color: Theme.inkPrimary
            font.family: Theme.uiFont
            font.pixelSize: Theme.nearbyRowNameSize
            font.weight: Theme.weightMedium
          }

          Text {
            id: openLabel

            x: parent.width - 20 - width
            y: (parent.height - height) / 2
            text: "Open"
            color: Theme.accentFill
            font.family: Theme.uiFont
            font.pixelSize: 12
            font.weight: Theme.weightSemi
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
  }
}
