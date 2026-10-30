import QtQuick
import qs.Commons
import qs.Services
import qs.Ui

// The overflow list behind the "+N" circle (Penpot "Ariadne / Activity card / List"): the
// activities there was no room for, oldest first. A row opens that activity's own card in
// place of the list.
Item {
  id: root

  readonly property var rows: Activities.hidden
  readonly property int shown: Math.min(rows.length, 4)

  implicitWidth: Theme.activityCardWidth
  implicitHeight: 64 + shown * 48 - 4 + Theme.activityCardPad

  CardHeader {
    tint: Theme.inkPrimary
    chipAlpha: 0.12
    chipText: "+" + root.rows.length
    title: root.rows.length + " more " + (root.rows.length === 1 ? "activity" : "activities")
    caption: "Oldest first"
  }

  Repeater {
    model: root.shown

    Rectangle {
      id: row

      required property int index
      readonly property var activity: root.rows[index] !== undefined ? root.rows[index] : null

      x: 8
      y: 64 + index * 48
      width: root.width - 16
      height: 44
      radius: Theme.activityWellRadius
      color: area.containsMouse ? Theme.surfaceRaised : Theme.surfaceSubtle

      Rectangle {
        x: 16
        y: (parent.height - height) / 2
        width: 28
        height: width
        radius: width / 2
        color: Theme.withAlpha(row.activity ? row.activity.chipColor : Theme.accent, Theme.notifAvatarAlpha)

        StrokeIcon {
          anchors.centerIn: parent
          size: 14
          strokeWidth: 1.75
          path: row.activity ? row.activity.icon : ""
          color: row.activity ? row.activity.chipColor : Theme.accent
        }
      }

      Text {
        x: 54
        y: (parent.height - height) / 2
        width: Math.max(0, valueText.x - x - 8)
        elide: Text.ElideRight
        text: row.activity ? row.activity.title : ""
        color: Theme.inkPrimary
        font.family: Theme.uiFont
        font.pixelSize: Theme.activityRowTitleSize
        font.weight: Theme.weightSemi
      }

      Text {
        id: valueText

        x: parent.width - 20 - width
        y: (parent.height - height) / 2
        text: row.activity ? row.activity.value : ""
        color: Theme.inkSecondary
        font.family: Theme.uiFont
        font.pixelSize: 12
        font.weight: Theme.weightSemi
        font.features: {
          "tnum": 1
        }
      }

      MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (row.activity)
          Activities.openCard(row.activity.key)
      }
    }
  }
}
