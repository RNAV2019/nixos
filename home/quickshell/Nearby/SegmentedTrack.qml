import QtQuick
import qs.Commons
import qs.Ui

// The header's segmented control (board 16a): a track with a chosen plate that slides between
// cells on the workspace-slot spring. A cell may set `pending`, which holds the plate in a soft
// pulse while a backend comes up (the AWDL radio, 10-30 s).
//
// By default the cells share the track equally, as the Send / Receive and Android / Apple
// controls do. `fit` sizes each to its label with 12 px either side, which is how the three
// labels of the platform control are made to fit; `compact` is the 22 px source switch of the
// wallpaper picker, with no track under it.
Rectangle {
  id: root

  // One per cell: { icon?, label, filled? }.
  required property var segments
  property int currentIndex: 0
  property bool pending: false
  property bool fit: false
  property bool compact: false

  signal chosen(int index)

  readonly property real pad: compact ? 0 : Theme.nearbyChosenInset

  implicitWidth: fit || compact ? cells.implicitWidth + pad * 2 : Theme.nearbyTrackWidth
  implicitHeight: compact ? Theme.nearbySourceHeight : Theme.nearbyTrackHeight
  radius: compact ? height / 2 : Theme.nearbyTrackRadius
  color: compact ? "transparent" : Theme.withAlpha(Theme.surfaceSubtle, 0.9)
  border.width: compact ? 0 : 1
  border.color: Theme.withAlpha(Theme.separator, 0.7)

  // Where the chosen cell is, written by that cell.
  property real plateX: 0
  property real plateWidth: 0
  // The plate takes its place at once when the control appears, and glides after that.
  property bool settled: false

  Component.onCompleted: Qt.callLater(function () {
    root.settled = true;
  })

  Rectangle {
    id: plate

    x: root.plateX
    y: root.compact ? 0 : Theme.nearbyChosenInset
    width: root.plateWidth
    height: root.compact ? root.height : Theme.nearbyChosenHeight
    radius: root.compact ? height / 2 : Theme.nearbyChosenRadius
    color: Theme.accentFill

    Behavior on x {
      enabled: root.settled

      MicroSpring {}
    }

    Behavior on width {
      enabled: root.settled

      MicroSpring {}
    }

    // The soft pulse while a mode switch is in flight; not a bounce, so plain opacity.
    SequentialAnimation on opacity {
      running: root.pending && !Theme.reduceMotion
      loops: Animation.Infinite

      NumberAnimation {
        to: 0.72
        duration: Theme.duration(Theme.morphAmbient)
        easing.type: Easing.InOutQuad
      }

      NumberAnimation {
        to: 1
        duration: Theme.duration(Theme.morphAmbient)
        easing.type: Easing.InOutQuad
      }
    }
  }

  Row {
    id: cells

    x: root.pad
    y: 0
    height: root.height
    spacing: root.compact ? Theme.nearbySourceGap : 0

    Repeater {
      model: root.segments

      Item {
        id: half

        required property var modelData
        required property int index

        width: root.compact ? Theme.nearbySourceCell : root.fit ? label.implicitWidth + Theme.nearbyFitPad * 2 : (root.width - root.pad * 2) / root.segments.length
        height: root.height

        readonly property bool isChosen: index === root.currentIndex

        Binding {
          target: root
          property: "plateX"
          value: root.pad + half.x
          when: half.isChosen
        }

        Binding {
          target: root
          property: "plateWidth"
          value: half.width
          when: half.isChosen
        }

        Row {
          anchors.centerIn: parent
          spacing: Theme.nearbySegmentGap

          StrokeIcon {
            visible: half.modelData.icon !== undefined
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.nearbySegmentGlyph
            strokeWidth: 1.75
            path: half.modelData.icon !== undefined ? half.modelData.icon : ""
            filled: half.modelData.filled === true
            color: half.isChosen ? Theme.inkOnAccent : Theme.inkSecondary

            Behavior on color {
              Tint {}
            }
          }

          Text {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            text: half.modelData.label
            color: half.isChosen ? Theme.inkOnAccent : Theme.inkSecondary
            font.family: Theme.uiFont
            font.pixelSize: Theme.nearbySegmentSize
            font.weight: Theme.weightSemi

            Behavior on color {
              Tint {}
            }
          }
        }

        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: half.modelData.label
        Accessible.focusable: true
        Accessible.focused: half.activeFocus
        Accessible.onPressAction: root.chosen(half.index)

        Keys.onPressed: function (event) {
          if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.chosen(half.index);
            event.accepted = true;
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.chosen(half.index)
        }
      }
    }
  }
}
