import QtQuick
import qs.Commons
import qs.Ui

// The receive body's head (boards 16c, 16d): three rings breathing outward around a filled
// core, the name other devices see, and the chips - the visibility countdown (click to end
// the window) and, in Apple mode, the gold note that Wi-Fi is down for the radio.
Item {
  id: root

  property string deviceName: ""
  property string remainingLabel: ""
  property bool receivable: false
  property bool wifiPaused: false

  signal timerClicked

  implicitWidth: Theme.nearbyWidth
  implicitHeight: Theme.nearbyRadarOuter + Theme.nearbyRadarNameGap + 17 + Theme.nearbyChipGap + Theme.nearbyChipHeight

  // One 2.4 s breath, three rings on 0.8 s beats. Each ring starts its loop on its own
  // beat and then stays there; off entirely under REDUCE_MOTION.
  component Ring: Rectangle {
    id: ringRoot

    property int beat: 0
    property real fillAlpha: 0
    property real strokeAlpha: 0

    color: Theme.withAlpha(Theme.accentFill, fillAlpha)
    border.width: 1
    border.color: Theme.withAlpha(Theme.accentFill, strokeAlpha)

    Timer {
      interval: ringRoot.beat * (Theme.nearbyRadarLoop / 3)
      running: !Theme.reduceMotion
      onTriggered: breath.start()
    }

    SequentialAnimation {
      id: breath

      loops: Animation.Infinite

      ParallelAnimation {
        NumberAnimation {
          target: ringRoot
          property: "scale"
          to: 1.12
          duration: Theme.nearbyRadarLoop / 2
          easing.type: Easing.InOutSine
        }

        NumberAnimation {
          target: ringRoot
          property: "opacity"
          to: 0.35
          duration: Theme.nearbyRadarLoop / 2
          easing.type: Easing.InOutSine
        }
      }

      ParallelAnimation {
        NumberAnimation {
          target: ringRoot
          property: "scale"
          to: 1
          duration: Theme.nearbyRadarLoop / 2
          easing.type: Easing.InOutSine
        }

        NumberAnimation {
          target: ringRoot
          property: "opacity"
          to: 1
          duration: Theme.nearbyRadarLoop / 2
          easing.type: Easing.InOutSine
        }
      }
    }
  }

  Item {
    id: rings

    x: (root.width - Theme.nearbyRadarOuter) / 2
    y: 0
    width: Theme.nearbyRadarOuter
    height: Theme.nearbyRadarOuter

    Ring {
      anchors.centerIn: parent
      width: Theme.nearbyRadarOuter
      height: Theme.nearbyRadarOuter
      radius: width / 2
      beat: 0
      fillAlpha: 0.025
      strokeAlpha: 0.07
    }

    Ring {
      anchors.centerIn: parent
      width: Theme.nearbyRadarMid
      height: Theme.nearbyRadarMid
      radius: width / 2
      beat: 1
      fillAlpha: 0.05
      strokeAlpha: 0.14
    }

    Ring {
      anchors.centerIn: parent
      width: Theme.nearbyRadarInner
      height: Theme.nearbyRadarInner
      radius: width / 2
      beat: 2
      fillAlpha: 0.1
      strokeAlpha: 0.28
    }

    Rectangle {
      anchors.centerIn: parent
      width: Theme.nearbyRadarCore
      height: Theme.nearbyRadarCore
      radius: width / 2
      color: Theme.accentFill

      StrokeIcon {
        anchors.centerIn: parent
        size: Theme.nearbyRadarGlyph
        strokeWidth: 1.8
        path: IconPaths.laptop
        color: Theme.inkOnAccent
      }
    }
  }

  Text {
    x: 0
    y: Theme.nearbyRadarOuter + Theme.nearbyRadarNameGap
    width: root.width
    horizontalAlignment: Text.AlignHCenter
    text: root.deviceName
    color: Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: Theme.nearbyNameSize
    font.weight: Theme.weightSemi
  }

  Row {
    x: (root.width - width) / 2
    y: Theme.nearbyRadarOuter + Theme.nearbyRadarNameGap + 17 + Theme.nearbyChipGap
    height: Theme.nearbyChipHeight
    spacing: Theme.nearbyChipPairGap

    // The countdown, or "On" while the window runs until told otherwise; clicking ends it.
    Rectangle {
      width: timerRow.implicitWidth + 24
      height: Theme.nearbyChipHeight
      radius: Theme.nearbyChipRadius
      color: Theme.withAlpha(Theme.accentFill, 0.12)
      scale: timerArea.pressed ? Theme.pressScale : 1

      Behavior on scale {
        Morph {
          duration: Theme.morphState
        }
      }

      Row {
        id: timerRow

        anchors.centerIn: parent
        spacing: Theme.nearbyChipInnerGap

        StrokeIcon {
          anchors.verticalCenter: parent.verticalCenter
          size: Theme.nearbyChipGlyph
          strokeWidth: 2
          path: IconPaths.timer
          color: Theme.accentFill
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.receivable ? (root.remainingLabel !== "" ? root.remainingLabel : "On") : "Off"
          color: Theme.accentFill
          font.family: Theme.uiFont
          font.pixelSize: Theme.nearbyChipSize
          font.weight: Theme.weightSemi
        }
      }

      MouseArea {
        id: timerArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.timerClicked()
      }

      Accessible.role: Accessible.Button
      Accessible.name: "End visibility"
      Accessible.onPressAction: root.timerClicked()
    }

    // Apple's exclusive radio: Wi-Fi is down while the window or a send runs.
    Rectangle {
      visible: root.wifiPaused
      width: wifiRow.implicitWidth + 24
      height: Theme.nearbyChipHeight
      radius: Theme.nearbyChipRadius
      color: Theme.withAlpha(Theme.gold, 0.12)

      Row {
        id: wifiRow

        anchors.centerIn: parent
        spacing: Theme.nearbyChipInnerGap

        StrokeIcon {
          anchors.verticalCenter: parent.verticalCenter
          size: Theme.nearbyChipGlyph
          strokeWidth: 2
          path: IconPaths.wifiOff
          color: Theme.gold
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "Wi-Fi paused"
          color: Theme.gold
          font.family: Theme.uiFont
          font.pixelSize: Theme.nearbyChipSize
          font.weight: Theme.weightSemi
        }
      }
    }
  }
}
