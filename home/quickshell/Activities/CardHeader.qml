import QtQuick
import qs.Commons
import qs.Ui

// The head every activity card shares: a round chip in the activity's role colour (the
// notification avatar vocabulary, the colour at 0.22 with the glyph in it), a title and a caption.
// `reserve` keeps the text clear of anything the card puts on the right of the row.
Item {
  id: root

  property string icon: ""
  property color tint: Theme.accent
  // A text chip instead of a glyph ("+2").
  property string chipText: ""
  property real chipAlpha: Theme.notifAvatarAlpha
  property string title: ""
  property string caption: ""
  property real reserve: 0

  x: 0
  y: 0
  width: parent ? parent.width : 0
  height: Theme.activityCardPad + Theme.activityChipSize

  Rectangle {
    x: Theme.activityCardPad
    y: Theme.activityCardPad
    width: Theme.activityChipSize
    height: width
    radius: width / 2
    color: Theme.withAlpha(root.tint, root.chipAlpha)

    StrokeIcon {
      anchors.centerIn: parent
      visible: root.chipText === ""
      size: 18
      strokeWidth: 1.75
      path: root.icon
      color: root.tint
    }

    Text {
      anchors.centerIn: parent
      visible: root.chipText !== ""
      text: root.chipText
      color: root.tint
      font.family: Theme.uiFont
      font.pixelSize: 13
      font.weight: Theme.weightSemi
    }
  }

  Text {
    x: 60
    y: 27 - height / 2
    width: Math.max(0, root.width - x - Theme.activityCardPad - root.reserve)
    elide: Text.ElideRight
    text: root.title
    color: Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: 14
    font.weight: Theme.weightSemi
  }

  Text {
    x: 60
    y: 43 - height / 2
    width: Math.max(0, root.width - x - Theme.activityCardPad - root.reserve)
    elide: Text.ElideRight
    text: root.caption
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: 11
  }
}
