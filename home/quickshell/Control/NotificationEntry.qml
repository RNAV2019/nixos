import QtQuick
import qs.Commons
import qs.Services
import qs.Ui

// One notification inside an expanded group: a summary over a line of body, its age on the
// right, and a cross that takes its place while the pointer is over the row. Swipe it aside to
// dismiss. The row is the list's delegate, so the card inside it is what moves and fades, and
// the row's own opacity stays the list's to animate.
Item {
  id: root

  // The row's key in the history, which still names it after the list has shifted.
  required property string key
  required property string summary
  required property string body
  // When it arrived, in ms; the age is read against `clockDate`, which moves on the minute.
  required property real arrived
  property date clockDate: new Date()

  signal dismissed

  readonly property bool hovered: hover.hovered

  height: Theme.controlNotifEntryHeight

  Item {
    id: face

    width: parent.width
    height: parent.height
    opacity: swipe.fade
    transform: Translate {
      x: swipe.offset
    }

    // Where the row meets the one above, or the header.
    Rectangle {
      x: 14
      width: parent.width - 28
      height: 1
      color: Theme.withAlpha(Theme.separator, 0.5)
    }

    Text {
      x: Theme.controlNotifTextLeft
      y: 9
      width: Math.max(0, stamp.x - x - 8)
      text: root.summary
      color: Theme.inkPrimary
      elide: Text.ElideRight
      font.family: Theme.uiFont
      font.pixelSize: Theme.controlNotifRowTitleSize
      font.weight: Theme.weightSemi
    }

    Text {
      x: Theme.controlNotifTextLeft
      y: 27
      width: parent.width - x - 16
      // One line, whatever the sender wrote.
      text: root.body.replace(/\s*\n\s*/g, " ")
      textFormat: Text.StyledText
      color: Theme.inkSecondary
      elide: Text.ElideRight
      font.family: Theme.uiFont
      font.pixelSize: Theme.controlNotifBodySize
    }

    Text {
      id: stamp

      x: parent.width - 16 - width
      y: 10
      text: NotificationStore.ago(root.arrived, root.clockDate)
      color: Theme.inkTertiary
      opacity: root.hovered ? 0 : 1
      font.family: Theme.uiFont
      font.pixelSize: Theme.sectionSize

      Behavior on opacity {
        Morph {
          duration: Theme.duration(Theme.morphContent)
        }
      }
    }

    IconButton {
      x: parent.width - 16 - width
      y: 10
      text: Icons.close
      font.family: Theme.iconFont
      font.pixelSize: 14
      baseColor: Theme.inkTertiary
      hoverColor: Theme.inkPrimary
      hitSlop: 8
      opacity: root.hovered ? 1 : 0
      enabled: root.hovered
      accessibleName: "Dismiss notification"

      Behavior on opacity {
        Morph {
          duration: Theme.duration(Theme.morphContent)
        }
      }

      onClicked: root.dismissed()
    }
  }

  // Hover without taking the press, so the swipe and the cross both still get it.
  HoverHandler {
    id: hover
  }

  SwipeDismiss {
    id: swipe

    anchors.fill: parent
    span: root.width
    onGone: root.dismissed()
  }
}
