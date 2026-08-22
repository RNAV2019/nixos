import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

PanelContent {
  id: root

  property int monthOffset: 0

  readonly property date today: clock.date
  readonly property date shown: new Date(today.getFullYear(), today.getMonth() + monthOffset, 1)

  readonly property int daysInMonth: new Date(shown.getFullYear(), shown.getMonth() + 1, 0).getDate()
  // Monday-first, matching the en-GB locale the bar clock uses.
  readonly property int leadingBlanks: (shown.getDay() + 6) % 7

  function isoWeek(date) {
    var d = new Date(date.getFullYear(), date.getMonth(), date.getDate());
    d.setDate(d.getDate() + 4 - ((d.getDay() + 6) % 7 + 1));
    var yearStart = new Date(d.getFullYear(), 0, 1);
    return Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
  }

  readonly property var cells: {
    var out = [];
    for (var i = 0; i < leadingBlanks; i++)
      out.push(0);
    for (var d = 1; d <= daysInMonth; d++)
      out.push(d);
    while (out.length % 7 !== 0)
      out.push(0);
    return out;
  }

  readonly property var weekNumbers: {
    var out = [];
    for (var row = 0; row * 7 < cells.length; row++) {
      // Any real day identifies the row's ISO week.
      var day = 1;
      for (var i = 0; i < 7; i++) {
        if (cells[row * 7 + i] > 0) {
          day = cells[row * 7 + i];
          break;
        }
      }
      out.push(isoWeek(new Date(shown.getFullYear(), shown.getMonth(), day)));
    }
    return out;
  }

  function isToday(day) {
    return monthOffset === 0 && day === today.getDate();
  }

  onActiveChanged: {
    if (!active)
      monthOffset = 0;
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  preferredWidth: Theme.panelWidthNarrow

  ColumnLayout {
    id: column
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: Theme.spacingMd

    RowLayout {
      Layout.fillWidth: true

      Text {
        text: "‹"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLarge

        MouseArea {
          anchors.fill: parent
          anchors.margins: -Theme.spacingMd
          cursorShape: Qt.PointingHandCursor
          onClicked: root.monthOffset--
        }
      }

      Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: Qt.formatDate(root.shown, "MMMM yyyy")
        color: Theme.gold
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.bold: true
      }

      Text {
        text: "›"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLarge

        MouseArea {
          anchors.fill: parent
          anchors.margins: -Theme.spacingMd
          cursorShape: Qt.PointingHandCursor
          onClicked: root.monthOffset++
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 0

      Text {
        Layout.preferredWidth: 30
        text: ""
      }

      Repeater {
        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

        Text {
          required property string modelData

          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          text: modelData
          color: Theme.subtle
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeSmall
          font.bold: true
        }
      }
    }

    Repeater {
      model: root.weekNumbers.length

      RowLayout {
        id: weekRow

        required property int index

        Layout.fillWidth: true
        spacing: 0

        Text {
          Layout.preferredWidth: 30
          text: "W" + root.weekNumbers[weekRow.index]
          color: Theme.foam
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeSmall
          font.bold: true
        }

        Repeater {
          model: 7

          Item {
            id: cell

            required property int index

            readonly property int day: root.cells[weekRow.index * 7 + index]

            Layout.fillWidth: true
            implicitHeight: 26

            Rectangle {
              anchors.centerIn: parent
              width: 22
              height: 22
              radius: height / 2
              color: root.isToday(cell.day) ? Theme.accent : "transparent"
              visible: cell.day > 0
            }

            Text {
              anchors.centerIn: parent
              text: cell.day > 0 ? cell.day : ""
              color: root.isToday(cell.day) ? Theme.base : Theme.text
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSize
              font.bold: root.isToday(cell.day)
            }
          }
        }
      }
    }
  }

  // Wheel events page between months.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    onWheel: function (wheel) {
      root.monthOffset += wheel.angleDelta.y > 0 ? -1 : 1;
    }
  }
}
