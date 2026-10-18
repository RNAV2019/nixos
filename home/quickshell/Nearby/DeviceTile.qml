import QtQuick
import qs.Commons
import qs.Ui

// One device under "Nearby" (boards 16a, 16e, 16f): a 56 px disc with the device glyph. A tap
// sends; while sending a progress ring grows around the disc with an × badge to cancel;
// done fills the disc with accent and draws a check. Tiles sit dimmed until files are ready.
Item {
  id: root

  // The peer row from the daemon ({ id, name, protocol, kind, via, rssi }), or null for an
  // empty slot.
  property var peer: null
  // The latest outbound transfer for this peer, if any.
  property var transfer: null
  // Files are staged, so a tap sends.
  property bool filesReady: false

  signal tapped
  signal cancelTapped

  readonly property int nameLine: 14

  implicitWidth: Theme.nearbyDeviceSlot
  implicitHeight: Theme.nearbyDeviceSize + Theme.nearbyDeviceNameGap + nameLine + (hasSub ? Theme.nearbyDeviceSubGap + Theme.nearbyDeviceSubHeight : 0)

  readonly property bool dimmed: !filesReady
  // Once the staged files are cleared the tile drops back to its device glyph: a finished
  // check belongs to the send that is still staged, not to the device forever.
  readonly property string state: filesReady && transfer && transfer.state ? transfer.state : ""
  readonly property bool sending: state === "connecting" || state === "waiting_consent" || state === "in_progress"
  readonly property bool sent: state === "finished"
  readonly property bool failed: state === "failed" || state === "rejected" || state === "cancelled"
  // The sub line belongs to a tile that is actually talking to its device.
  readonly property bool hasSub: filesReady && transfer !== null
  readonly property real progress: {
    if (sent)
      return 1;
    if (!transfer || !transfer.total_bytes || transfer.total_bytes <= 0)
      return 0;
    return Theme.clamp01((transfer.bytes || 0) / transfer.total_bytes);
  }

  // The ring eases to each reading rather than snapping; events arrive at most every 250 ms.
  property real shownProgress: 0

  onProgressChanged: {
    progressEase.to = progress;
    progressEase.restart();
  }

  NumberAnimation on shownProgress {
    id: progressEase

    duration: Theme.reduceMotion ? 1 : 250
    easing.type: Easing.OutCubic
  }

  Component.onCompleted: {
    shownProgress = progress;
    appear = 1;
  }

  readonly property string subLabel: {
    if (sent)
      return "Sent";
    if (state === "failed")
      return "Failed";
    if (state === "rejected")
      return "Declined";
    if (state === "cancelled")
      return "Cancelled";
    // Quick Share shows the same PIN on both screens while the phone decides.
    if ((state === "connecting" || state === "waiting_consent") && transfer && transfer.pin)
      return "PIN " + transfer.pin;
    // AirDrop: the other person is looking at Accept / Decline.
    if (state === "waiting_consent")
      return "Waiting…";
    if (state === "connecting")
      return "Connecting…";
    return Math.round(root.progress * 100) + "%";
  }

  readonly property string icon: {
    var kind = peer && peer.kind ? peer.kind : "unknown";
    if (kind === "tablet")
      return IconPaths.tablet;
    if (kind === "laptop")
      return IconPaths.laptop;
    return IconPaths.smartphone;
  }

  readonly property string name: peer && peer.name ? peer.name : "Unknown"

  opacity: (dimmed ? Theme.nearbyDeviceDim : 1) * appear

  // A device that turns up mid-scan fades and grows in rather than popping into the row.
  property real appear: 0
  scale: 0.9 + 0.1 * appear

  Behavior on appear {
    Morph {}
  }

  Behavior on opacity {
    Morph {
      duration: Theme.morphState
    }
  }

  // The disc, with the progress ring riding just outside it.
  Item {
    id: discBlock

    x: (root.width - Theme.nearbyDeviceSize) / 2
    y: 0
    width: Theme.nearbyDeviceSize
    height: Theme.nearbyDeviceSize

    // Progress ring: track plus an arc from twelve o'clock, both 2.5 px. Sized one notch
    // over the disc so the pair reads as one object.
    Canvas {
      id: ring

      visible: root.sending && !root.sent
      x: (parent.width - Theme.nearbyRingSize) / 2
      y: (parent.height - Theme.nearbyRingSize) / 2
      width: Theme.nearbyRingSize
      height: Theme.nearbyRingSize

      onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        var mid = width / 2;
        var radius = mid - Theme.nearbyRingWidth / 2;
        ctx.lineWidth = Theme.nearbyRingWidth;
        ctx.lineCap = "round";

        ctx.beginPath();
        ctx.arc(mid, mid, radius, 0, 2 * Math.PI);
        ctx.strokeStyle = Theme.withAlpha(Theme.separator, 0.9);
        ctx.stroke();

        if (root.shownProgress > 0) {
          var start = -Math.PI / 2;
          ctx.beginPath();
          ctx.arc(mid, mid, radius, start, start + 2 * Math.PI * root.shownProgress);
          ctx.strokeStyle = Theme.accentFill;
          ctx.stroke();
        }
      }

      Connections {
        target: root

        function onShownProgressChanged() {
          ring.requestPaint();
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: root.sent ? Theme.accentFill : root.sending ? Theme.withAlpha(Theme.accentFill, 0.14) : Theme.withAlpha(Theme.surfaceSubtle, 0.85)
      border.width: root.sent ? 0 : 1
      border.color: Theme.withAlpha(Theme.separator, 0.55)

      Behavior on color {
        Tint {}
      }
    }

    // Done: the glyph is replaced by a check that draws in.
    StrokeIcon {
      anchors.centerIn: parent
      visible: root.sent
      size: Theme.nearbyCheckSize
      strokeWidth: 2.2
      path: IconPaths.check
      color: Theme.inkOnAccent
      opacity: root.sent ? 1 : 0
      scale: root.sent ? 1 : 0.6

      Behavior on opacity {
        Morph {
          duration: Theme.morphState
        }
      }

      Behavior on scale {
        Morph {
          duration: Theme.morphState
        }
      }
    }

    StrokeIcon {
      anchors.centerIn: parent
      visible: !root.sent
      size: Theme.nearbyDeviceGlyph
      strokeWidth: 1.75
      path: root.icon
      color: Theme.accentFill
    }
  }

  // The × badge sits on the disc's top-right corner, punched out by a surface-coloured ring.
  Rectangle {
    id: cancelBadge

    visible: root.sending
    x: discBlock.x + Theme.nearbyDeviceSize - Theme.nearbyCancelSize + 6
    y: discBlock.y - 4
    width: Theme.nearbyCancelSize
    height: Theme.nearbyCancelSize
    radius: width / 2
    color: Theme.surfaceRaised
    border.width: Theme.nearbyCancelStroke
    border.color: Theme.surface
    scale: cancelArea.pressed ? Theme.pressScale : 1

    Behavior on scale {
      Morph {
        duration: Theme.morphState
      }
    }

    StrokeIcon {
      anchors.centerIn: parent
      size: Theme.nearbyCancelGlyph
      strokeWidth: 2
      path: IconPaths.x
      color: Theme.inkPrimary
    }

    MouseArea {
      id: cancelArea

      anchors.fill: parent
      anchors.margins: -4
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.cancelTapped()
    }

    Accessible.role: Accessible.Button
    Accessible.name: "Cancel send to " + root.name
    Accessible.onPressAction: root.cancelTapped()
  }

  Text {
    x: 0
    y: Theme.nearbyDeviceSize + Theme.nearbyDeviceNameGap
    width: root.width
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
    text: root.name
    color: Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: Theme.nearbyDeviceNameSize
    font.weight: root.sending || root.sent ? Theme.weightSemi : Theme.weightRegular
  }

  Text {
    visible: root.hasSub
    x: 0
    y: Theme.nearbyDeviceSize + Theme.nearbyDeviceNameGap + root.nameLine + Theme.nearbyDeviceSubGap
    width: root.width
    horizontalAlignment: Text.AlignHCenter
    text: root.subLabel
    color: root.failed ? Theme.dangerFill : Theme.accentFill
    font.family: Theme.uiFont
    font.pixelSize: Theme.nearbyDeviceSubSize
    font.weight: Theme.weightMedium

    Behavior on color {
      Tint {}
    }
  }

  activeFocusOnTab: root.filesReady && root.peer !== null && !root.sending
  Accessible.role: Accessible.Button
  Accessible.name: root.name + (root.hasSub ? ", " + root.subLabel : "")
  Accessible.focusable: root.activeFocusOnTab
  Accessible.focused: root.activeFocus
  Accessible.onPressAction: root.tapped()

  Keys.onPressed: function (event) {
    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.tapped();
      event.accepted = true;
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.filesReady && !root.sending ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: {
      if (!root.sending && root.filesReady)
        root.tapped();
    }
  }
}
