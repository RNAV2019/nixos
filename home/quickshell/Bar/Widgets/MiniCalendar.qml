import QtQuick
import qs.Commons
import qs.Ui

// The week the expanded card shows while nothing is playing. The edge ramp is carried by the
// columns, not a gradient mask: a nested MultiEffect mask comes back empty and kills the strip.
Item {
  id: root

  // Driven by the card's own clock, so the strip rolls over at midnight without a timer.
  property date today: new Date()

  readonly property int days: Theme.islandCalDays
  readonly property int pitch: Theme.islandCalPitch

  // Odd, so there is a middle column for today to sit in.
  readonly property int middle: (days - 1) / 2

  implicitWidth: days * pitch
  implicitHeight: Theme.islandCalPlateHeight

  function dayAt(offset) {
    var d = new Date(root.today);
    d.setDate(d.getDate() + offset - root.middle);
    return d;
  }

  // The edge ramp: full strength except within one pitch of either end.
  function fadeAt(x) {
    var edge = Math.min(x, root.width - x);
    return Math.max(0, Math.min(1, edge / root.pitch));
  }

  // Wider than the pitch, so the three-letter label has room; drawn under its column.
  Rectangle {
    x: (root.width - width) / 2
    y: 0
    width: Theme.islandCalPlateWidth
    height: Theme.islandCalPlateHeight
    radius: Theme.islandCalPlateRadius
    color: Theme.withAlpha(Theme.text, Theme.islandCalPlateAlpha)
  }

  Repeater {
    model: root.days

    Item {
      id: column

      required property int index

      readonly property date day: root.dayAt(index)
      readonly property bool isToday: index === root.middle
      readonly property bool weekend: day.getDay() === 0 || day.getDay() === 6

      x: index * root.pitch
      y: 0
      width: root.pitch
      height: root.height
      opacity: root.fadeAt(x + width / 2)

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.islandCalLabelMid - height / 2
        text: {
          var name = Qt.formatDate(column.day, "ddd").toUpperCase();
          return column.isToday ? name : name.charAt(0);
        }
        color: {
          if (column.isToday)
            return Theme.text;
          if (column.weekend)
            return Theme.withAlpha(Theme.love, Theme.islandCalWeekendLabelAlpha);
          return Theme.muted;
        }
        font.family: Theme.uiFont
        font.pixelSize: Theme.islandCalLabelSize
        font.weight: column.isToday ? Font.Bold : Font.Medium

        Behavior on color {
          Tint {}
        }
      }

      Text {
        id: dayText

        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.islandCalDayMid - height / 2
        text: column.day.getDate()
        color: {
          if (column.isToday)
            return Theme.accent;
          if (column.weekend)
            return Theme.withAlpha(Theme.love, Theme.islandCalWeekendDayAlpha);
          return Theme.subtle;
        }
        font.family: Theme.uiFont
        // At rest the numeral is a native glyph run at its own size, scale 1. A change of size
        // starts the scale at the old look and eases it to 1, so no text is re-laid out per frame.
        readonly property real size: column.isToday ? Theme.islandCalTodaySize : Theme.islandCalDaySize
        property real lastSize: size

        font.pixelSize: size

        onSizeChanged: {
          sizeEase.stop();
          scale = lastSize * scale / size;
          lastSize = size;
          sizeEase.restart();
        }
        font.weight: column.isToday ? Font.DemiBold : Font.Medium

        Behavior on color {
          Tint {}
        }

        Morph {
          id: sizeEase

          target: dayText
          property: "scale"
          to: 1
          duration: Theme.duration(Theme.morphState)
        }
      }
    }
  }
}
