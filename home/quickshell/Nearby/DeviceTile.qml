import QtQuick
import qs.Commons
import qs.Services
import qs.Ui

// One device under "Nearby" (boards 16a, 16e, 16f): a tap sends; while sending a progress ring
// grows around the disc with an × badge to cancel; done fills the disc with accent and draws a
// check. Tiles sit dimmed until files are ready. This reads the peer and its transfer; the
// tile itself is Ui/Tile.qml's Device kind.
Tile {
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

  // Once the staged files are cleared the tile drops back to its device glyph: a finished
  // check belongs to the send that is still staged, not to the device forever.
  readonly property string state: filesReady && transfer && transfer.state ? transfer.state : ""

  // The sub line belongs to a tile that is actually talking to its device.
  readonly property bool talking: filesReady && transfer !== null

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
    if (indeterminate)
      return "Sending…";
    return Math.round(progress * 100) + "%";
  }

  // A device that turns up mid-scan fades and grows in rather than popping into the row.
  property real appear: 0

  kind: Tile.Device
  sending: state === "connecting" || state === "waiting_consent" || state === "in_progress"
  sent: state === "finished"
  failed: state === "failed" || state === "rejected" || state === "cancelled"
  // KDE Connect says nothing until its job reports: the ring turns instead of filling.
  indeterminate: sending && Nearby.isIndeterminate(transfer)
  progress: sent ? 1 : Nearby.progressOf(transfer)
  sublabel: talking ? subLabel : ""
  label: peer && peer.name ? peer.name : "Unknown"
  glyph: {
    var type = peer && peer.kind ? peer.kind : "unknown";
    if (type === "tablet")
      return IconPaths.tablet;
    if (type === "laptop")
      return IconPaths.laptop;
    return IconPaths.smartphone;
  }

  enabled: filesReady
  interactive: filesReady && peer !== null && !sending
  accessibleName: label + (talking ? ", " + subLabel : "")
  opacity: appear * (enabled ? 1 : Theme.disabledAlpha)
  scale: (0.9 + 0.1 * appear) * pressedScale

  Component.onCompleted: appear = 1

  Behavior on appear {
    Morph {}
  }

  onClicked: root.tapped()
  onCancelClicked: root.cancelTapped()
}
