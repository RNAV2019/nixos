import QtQuick
import qs.Commons
import qs.Ui

// The header's two-half segmented control (board 16a): a track with a chosen plate that
// slides between halves on the workspace-slot spring. A half may set `pending`, which
// holds the plate in a soft pulse while a backend comes up (the AWDL radio, 10-30 s).
Rectangle {
  id: root

  // One per half: { icon, label, filled? }.
  required property var segments
  property int currentIndex: 0
  property bool pending: false

  signal chosen(int index)

  implicitWidth: Theme.nearbyTrackWidth
  implicitHeight: Theme.nearbyTrackHeight
  radius: Theme.nearbyTrackRadius
  color: Theme.withAlpha(Theme.surfaceSubtle, 0.9)
  border.width: 1
  border.color: Theme.withAlpha(Theme.separator, 0.7)

  readonly property real halfWidth: (width - Theme.nearbyChosenInset * 2) / 2

  Rectangle {
    id: plate

    x: Theme.nearbyChosenInset + root.currentIndex * root.halfWidth
    y: Theme.nearbyChosenInset
    width: root.halfWidth
    height: Theme.nearbyChosenHeight
    radius: Theme.nearbyChosenRadius
    color: Theme.accentFill

    Behavior on x {
      MicroSpring {}
    }

    // The soft pulse while a mode switch is in flight; not a bounce, so plain opacity.
    SequentialAnimation on opacity {
      running: root.pending && !Theme.reduceMotion
      loops: Animation.Infinite

      NumberAnimation {
        to: 0.72
        duration: 420
        easing.type: Easing.InOutQuad
      }

      NumberAnimation {
        to: 1
        duration: 420
        easing.type: Easing.InOutQuad
      }
    }
  }

  Row {
    x: Theme.nearbyChosenInset
    y: 0
    width: root.halfWidth * 2
    height: root.height

    Repeater {
      model: root.segments

      Item {
        id: half

        required property var modelData
        required property int index

        width: root.halfWidth
        height: root.height

        readonly property bool isChosen: index === root.currentIndex

        Row {
          anchors.centerIn: parent
          spacing: Theme.nearbySegmentGap

          StrokeIcon {
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.nearbySegmentGlyph
            strokeWidth: 1.75
            path: half.modelData.icon
            filled: half.modelData.filled === true
            color: half.isChosen ? Theme.inkOnAccent : Theme.inkSecondary

            Behavior on color {
              Tint {}
            }
          }

          Text {
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
