import QtQuick
import qs.Commons

// Four accent bars that stand in for the playing track. They rest at the
// heights the design fixes and only move while audio is actually playing, so a
// paused player is visibly paused rather than merely quiet.
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

        // The animation drives its own property rather than the height, so
        // pausing hands the height back to its binding and the bars settle
        // into the shape the design fixes.
        property real level: modelData

        anchors.verticalCenter: parent.verticalCenter
        width: root.barWidth
        height: root.playing ? level : modelData
        radius: width / 2
        color: Theme.accent

        // Staggered periods, so the four bars never beat in unison.
        SequentialAnimation on level {
          running: root.playing
          loops: Animation.Infinite

          NumberAnimation {
            to: 3
            duration: 260 + bar.index * 70
            easing.type: Easing.InOutSine
          }

          NumberAnimation {
            to: root.implicitHeight
            duration: 300 + bar.index * 55
            easing.type: Easing.InOutSine
          }
        }
      }
    }
  }
}
