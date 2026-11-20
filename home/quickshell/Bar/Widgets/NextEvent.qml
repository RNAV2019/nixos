import QtQuick
import qs.Commons

// Today's next event, where the week strip stands in the open hover card while nothing plays:
// its title over when it is, set like the track block (title and artist) so the card keeps one
// left-hand voice. Within the hour the time to go leads, in the accent; under way it says until
// when. The room, when the event names one, ends the line and is the first to be elided.
Item {
  id: root

  // { start: Date, end: Date, title, location }, or null.
  property var event: null
  // The card's minute clock, so the line moves on without a timer of its own.
  property date now: new Date()

  readonly property real midline: height / 2

  function hm(d) {
    return Qt.formatDateTime(d, "HH:mm");
  }

  // The line in two inks: what leads (the accent's: "in 25 min", "Now") and the rest. Plain texts,
  // not styled ones: a styled Text takes the hover, and the card would shut under the pointer.
  readonly property var parts: {
    var e = root.event;
    if (!e)
      return ["", ""];
    var room = e.location ? " · " + e.location : "";
    var minutes = Math.ceil((e.start - root.now) / 60000);
    if (minutes <= 0)
      return ["Now", " · until " + root.hm(e.end) + room];
    if (minutes <= Theme.islandEventSoon)
      return ["in " + minutes + " min", " · " + root.hm(e.start) + room];
    return ["", root.hm(e.start) + "–" + root.hm(e.end) + room];
  }

  Text {
    y: root.midline - 8 - height / 2
    width: root.width
    elide: Text.ElideRight
    text: root.event ? root.event.title : ""
    color: Theme.text
    font.family: Theme.uiFont
    font.pixelSize: Theme.islandTitleSize
    font.weight: Theme.weightSemi
  }

  Row {
    y: root.midline + 9.5 - height / 2
    width: root.width

    Text {
      id: leading

      text: root.parts[0]
      color: Theme.accent
      font.family: Theme.uiFont
      font.pixelSize: Theme.islandCaptionSize
      font.weight: Theme.weightSemi
    }

    Text {
      width: Math.max(0, root.width - leading.width)
      elide: Text.ElideRight
      text: root.parts[1]
      color: Theme.subtle
      font.family: Theme.uiFont
      font.pixelSize: Theme.islandCaptionSize
    }
  }
}
