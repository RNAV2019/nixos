import QtQuick
import qs.Commons

// One live activity, declared by whatever owns the state behind it (a timer, a rebuild, a
// phone) and registered with Services/Activities.qml for as long as `active` holds. It is
// plain declarative state: bind the properties to the owner's and the satellite beside the
// pill, its hover card and its row in the overflow list all follow.
//
//   Activity {
//     kind: "usb"
//     active: drive.mounted
//     icon: IconPaths.hardDrive
//     ring: drive.usedShare
//     title: drive.label
//     value: drive.freeText
//     card: Component { UsbCard { drive: drive } }
//   }
//
// Several at once come from an Instantiator whose delegate is an Activity; the delegate's own
// removal unregisters it.
QtObject {
  id: root

  // What it is ("timer", "pomodoro", "phone"); a label for tests and for sounds to key on.
  property string kind: ""

  // Unique among the registered ones, for hover and card bookkeeping; the registry gives one
  // ("timer:3") to an activity that did not set its own.
  property string key: ""

  // Registered while true. Flip it for an activity that comes and goes with its owner.
  property bool active: true

  // The satellite nearest the pill whenever there is one (the phone).
  property bool pinned: false

  // Needs the user (Claude waiting, a failed rebuild, an event starting): takes the visible
  // satellite over a quieter one and pulses its halo until its card has been opened.
  property bool attention: false

  // ---- the satellite ----

  // An icon from Commons/IconPaths.qml; drawn centred, `iconSize` high.
  property string icon: ""
  property real iconSize: Theme.satelliteGlyphSize
  property color iconColor: Theme.inkPrimary

  // Replaces the icon when set: a short reading in the circle ("6:12"), and an optional smaller
  // caption under it ("min").
  property string text: ""
  property color textColor: Theme.inkPrimary
  property string caption: ""
  property real textSize: Theme.satelliteTextSize

  // The ring: -1 for none, else the fraction 0..1 the arc covers, clockwise from 12 o'clock.
  // A depleting ring is the owner's to invert (remaining / total).
  property real ring: -1
  property color ringColor: Theme.accent
  // A spinning quarter arc instead of a fraction, for work of unknown length.
  property bool indeterminate: false

  // The circle's ground; an attention state wears a role colour here, with its ink in `iconColor`.
  property color ground: Theme.surface
  property color haloColor: Theme.accent

  // ---- the list row and the generic card ----

  property string title: ""
  property string subtitle: ""
  // The short right-hand reading in the overflow list ("6:12", "78%").
  property string value: ""
  // The chip's role colour (the notification avatar vocabulary: this at 0.22, the glyph in it).
  property color chipColor: Theme.accent

  // ---- the hover card ----

  // The card's contents, laid out at their own final size: an Item with implicitWidth and
  // implicitHeight. Without one, a generic card draws `title` and `subtitle` under the chip.
  property Component card: null

  // When it joined the registry, for ordering (oldest nearest the pill). The owner may set it
  // to a start time it knows better than the registry does.
  property real since: 0

  // One object for the satellite to latch: it keeps drawing the last look while it fades out
  // after the activity itself has gone.
  readonly property var look: ({
      kind: kind,
      icon: icon,
      iconSize: iconSize,
      iconColor: iconColor,
      text: text,
      textColor: textColor,
      caption: caption,
      textSize: textSize,
      ring: ring,
      ringColor: ringColor,
      indeterminate: indeterminate,
      ground: ground,
      filled: !Qt.colorEqual(ground, Theme.surface),
      haloColor: haloColor,
      attention: attention,
      acknowledged: acknowledged
    })

  // The card has been opened since this needed attention; the halo rests until it needs it again.
  property bool acknowledged: false
  onAttentionChanged: acknowledged = false

  // Reads of `active` and registration are separate so an activity declared inactive costs nothing.
  Component.onCompleted: if (active)
    Activities.register(root)

  onActiveChanged: {
    if (active)
      Activities.register(root);
    else
      Activities.remove(root);
  }

  Component.onDestruction: Activities.remove(root)
}
