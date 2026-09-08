import QtQuick
import Quickshell
import qs.Bar.Widgets
import qs.Commons
import qs.Services
import qs.Ui

// The centred surface, and the only one that changes shape.
//
// It has three resting states. Idle it is a clock and nothing else. With a
// player running it grows an equaliser to the left of the clock. Hovered, or
// pinned by a click, it opens into a card carrying the track, a larger clock
// with the date, and the two readings worth watching all day.
FrostedSurface {
  id: root

  signal clockActivated
  signal statusActivated

  // A pin survives the pointer leaving, so the card can be read at leisure.
  property bool pinned: false

  readonly property bool expanded: hover.containsMouse || pinned

  readonly property int collapsedWidth: Media.active ? Theme.islandPlayingWidth : Theme.islandIdleWidth

  implicitWidth: expanded ? Theme.islandExpandedWidth : collapsedWidth
  implicitHeight: expanded ? Theme.islandExpandedHeight : Theme.barHeight
  surfaceRadius: expanded ? Theme.islandExpandedRadius : Theme.islandRadius

  Behavior on implicitWidth {
    Morph {}
  }

  Behavior on implicitHeight {
    Morph {}
  }

  Behavior on surfaceRadius {
    Morph {}
  }

  SystemClock {
    id: clock

    precision: SystemClock.Minutes
  }

  // Clicking empty island space pins it; the controls below sit on top of this
  // and act without unpinning.
  MouseArea {
    id: hover

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.pinned = !root.pinned
  }

  // Collapsed: an equaliser only when there is something to show, then the
  // clock, together centred in the pill.
  Row {
    id: collapsed

    anchors.centerIn: parent
    spacing: 7.5
    opacity: root.expanded ? 0 : 1
    visible: opacity > 0

    Behavior on opacity {
      Morph {
        duration: Theme.morphToggle
      }
    }

    Equaliser {
      anchors.verticalCenter: parent.verticalCenter
      playing: Media.playing
      visible: Media.active
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Qt.formatDateTime(clock.date, "HH:mm")
      color: Theme.text
      font.family: Theme.uiFont
      font.pixelSize: Theme.islandClockSize
      font.weight: Font.DemiBold
    }
  }

  // Expanded: laid out on the card's own fixed geometry rather than by flow,
  // because the design places the clock on the card's centre line while the
  // track sits hard left and the readings hard right.
  Item {
    id: card

    anchors.centerIn: parent
    width: Theme.islandExpandedWidth
    height: Theme.islandExpandedHeight
    opacity: root.expanded ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
      Morph {
        duration: Theme.morphToggle
      }
    }

    Item {
      id: media

      x: 16
      y: 0
      // Stops short of the clock, so a long title elides rather than crowding
      // the card's centre line.
      width: 200
      height: parent.height
      visible: Media.active

      AlbumArt {
        x: 0
        y: 18
      }

      Equaliser {
        x: 60
        y: (parent.height - height) / 2
        playing: Media.playing
      }

      Text {
        x: 84
        y: 26
        width: 116
        elide: Text.ElideRight
        text: Media.title
        color: Theme.text
        font.family: Theme.uiFont
        font.pixelSize: Theme.islandTitleSize
        font.weight: Font.DemiBold
      }

      Text {
        x: 84
        y: 45
        width: 116
        elide: Text.ElideRight
        text: Media.artist
        color: Theme.subtle
        font.family: Theme.uiFont
        font.pixelSize: Theme.islandCaptionSize
      }

      // Left and right buttons skip, so the card is a transport as well as a
      // readout.
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.ForwardButton | Qt.BackButton
        onClicked: function (event) {
          if (event.button === Qt.ForwardButton)
            Media.next();
          else if (event.button === Qt.BackButton)
            Media.previous();
          else
            Media.toggle();
        }
      }
    }

    Item {
      id: time

      // Centred on the card, not on the space left over beside the track, so
      // the clock stays put as titles change length.
      x: (parent.width - width) / 2
      y: 0
      width: 120
      height: parent.height

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 21
        text: Qt.formatDateTime(clock.date, "HH:mm")
        color: Theme.text
        font.family: Theme.uiFont
        font.pixelSize: Theme.islandDisplaySize
        font.weight: Font.DemiBold
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 49
        text: Qt.formatDateTime(clock.date, "ddd, d MMM")
        color: Theme.subtle
        font.family: Theme.uiFont
        font.pixelSize: Theme.islandCaptionSize
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clockActivated()
      }
    }

    Rectangle {
      id: status

      x: 432
      y: 24
      width: Theme.islandStatusWidth
      height: 36
      radius: height / 2
      color: Theme.withAlpha(Theme.accent, 0.14)
      border.width: 1
      border.color: Theme.withAlpha(Theme.accent, 0.28)

      WifiGlyph {
        x: 10
        anchors.verticalCenter: parent.verticalCenter
      }

      BatteryGauge {
        x: 33
        anchors.verticalCenter: parent.verticalCenter
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.statusActivated()
      }
    }
  }
}
