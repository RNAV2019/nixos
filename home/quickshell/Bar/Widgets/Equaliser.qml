import QtQuick
import qs.Commons

Item {
  id: root

  property bool playing: false

  readonly property var restHeights: [7, 12, 15, 9]
  readonly property real barWidth: 2.5
  readonly property real barGap: 1.5

  implicitWidth: restHeights.length * barWidth + (restHeights.length - 1) * barGap
  implicitHeight: 15

  Row {
    anchors.centerIn: parent
    spacing: root.barGap

    Repeater {
      model: root.restHeights

      Rectangle {
        id: bar

        required property int index
        required property real modelData

        // Animating a separate property lets height fall back to its binding on pause.
        property real level: modelData

        anchors.verticalCenter: parent.verticalCenter
        width: root.barWidth
        height: root.playing ? level : modelData
        radius: width / 2
        color: Theme.accent

        SequentialAnimation on level {
          running: root.playing && !Theme.reduceMotion
          loops: Animation.Infinite

          NumberAnimation {
            to: 3
            duration: 320 + bar.index * 60
            easing.type: Easing.InOutSine
          }

          NumberAnimation {
            to: root.implicitHeight
            duration: 400 + bar.index * 50
            easing.type: Easing.InOutSine
          }
        }
      }
    }
  }
}
