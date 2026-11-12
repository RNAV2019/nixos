import QtQuick
import QtQuick.Shapes

// One character of the lock's big clock while a new minute rolls in (see the roll in
// LockView.qml's clockBox): an element of a layer's one path, hung from the top of its own ink at
// its pen position, as the line at rest hangs from its own. The characters of a layer share a
// path so that where two of them overlap they cut each other exactly as they do in the line at
// rest, which is one path too; separate shapes would join there, and the hand-back to the line
// would show it.
//
// `part` says which of the slot's characters this is:
//   "line"     the one the new line shows there: a character that stays, sliding to its new
//              place, or a changed one rising into its place from a row below;
//   "waiting"  a changed character that has not begun to leave yet: it stands in the line
//              until its turn in the ripple comes;
//   "leaving"  a changed character on its way up and out of the row, in a layer of its own.
//
// A file of its own, not an inline component of LockView.qml: a running shell that reloads its
// configuration does not take an inline component added to a file it has already loaded
// ("RollGlyph is not a type"), and the lock must never be what a reload fails on.
PathText {
  id: root

  // The clock's box (LockView.qml's clockBox), which holds the roll, and the slot's index in it.
  required property Item box
  required property int index
  required property string part

  readonly property var slot: index < box.rollSlots.length ? box.rollSlots[index] : null
  readonly property bool changed: !!slot && slot.changed
  readonly property real slide: box.rollSlide
  readonly property real rise: changed ? box.riseOf(slot.order) : 0
  readonly property bool shown: !!slot && !!place && (part === "line" || (changed && (part === "leaving") === (rise > 0)))

  // Where the slot starts now and how wide it is (LockView.qml rollLayout): a changing
  // character turns over in the middle of it, whatever its width.
  readonly property var place: slot && index < box.rollLayout.length ? box.rollLayout[index] : null

  font: box.rollFace
  text: !shown || !slot ? "" : part === "line" ? slot.to : slot.from
  x: {
    if (!shown || !slot || !place)
      return 0;
    if (part !== "line")
      return place.pen + (place.advance - slot.fromAdvance) / 2;
    return changed ? place.pen + (place.advance - slot.toAdvance) / 2 : place.pen;
  }
  // Each character hangs from its own ink's top, so it is lowered by its line's top less its
  // own to sit on that line's baseline; one that stays moves onto the new baseline, which can
  // differ from the old by a fraction of a pixel.
  y: {
    if (!shown || !slot)
      return 0;
    if (part !== "line")
      return box.rollFromBase + slot.fromTop - box.rollTravel * rise;
    if (changed)
      return box.rollToBase + slot.toTop + box.rollTravel * (1 - rise);
    return box.rollFromBase * (1 - slide) + box.rollToBase * slide + slot.fromTop;
  }
}
