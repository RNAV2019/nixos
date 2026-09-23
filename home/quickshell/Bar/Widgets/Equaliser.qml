import QtQuick
import qs.Commons

Item {
  id: root

  property bool playing: false

  // The bars' idle heights, one per bar: a descending rhythm that still reads as a wave.
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
          // Visibility too: the shut pill hands the equaliser over with an opacity cross-fade,
          // so a hidden bar must not keep animating underneath.
          running: root.playing && !Theme.reduceMotion && visible
          loops: Animation.Infinite

          NumberAnimation {
            to: 3
            duration: Theme.eqRiseBase + bar.index * Theme.eqRiseStagger
            easing.type: Easing.InOutSine
          }

          NumberAnimation {
            to: root.implicitHeight
            duration: Theme.eqFallBase + bar.index * Theme.eqFallStagger
            easing.type: Easing.InOutSine
          }
        }
      }
    }
  }
}
