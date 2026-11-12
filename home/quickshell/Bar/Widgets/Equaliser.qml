import QtQuick
import qs.Commons

Item {
  id: root

  property bool playing: false
  // Paused, the bars lie down as four quiet dots, where the shut pill's stand at their rest.
  property bool restsFlat: false

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

        // What the bar draws: the loop below moves it while playing, and a pause eases it back
        // to its resting height from wherever the loop left it rather than dropping it there.
        property real level: modelData
        readonly property real rest: root.restsFlat ? root.barWidth : modelData

        Component.onCompleted: if (root.restsFlat && !root.playing)
          level = rest

        anchors.verticalCenter: parent.verticalCenter
        width: root.barWidth
        height: level
        radius: width / 2
        color: root.restsFlat && !root.playing ? Theme.subtle : Theme.accent

        Behavior on color {
          ColorAnimation {
            duration: Theme.tintFade
          }
        }

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

        NumberAnimation {
          id: settle

          target: bar
          property: "level"
          to: bar.rest
          duration: Theme.duration(Theme.eqSettle)
          easing.type: Easing.OutCubic
        }

        Connections {
          target: root

          function onPlayingChanged() {
            if (root.playing)
              settle.stop();
            else
              settle.restart();
          }
        }
      }
    }
  }
}
