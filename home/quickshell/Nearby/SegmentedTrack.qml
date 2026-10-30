import QtQuick
import qs.Commons
import qs.Ui

// A segmented control (the Nearby header, board 16a; the share picker's source): a track with a
// chosen plate that slides between segments on the workspace-slot spring. The track's `pending`
// holds the plate in a soft pulse while a backend comes up (the AWDL radio, 10-30 s); a segment
// may set `muted` for one that cannot be chosen now, which reads dim and takes no input.
Rectangle {
  id: root

  // One per segment: { icon, label, filled?, muted? }.
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

  readonly property real segmentWidth: (width - Theme.nearbyChosenInset * 2) / Math.max(1, segments.length)

  Rectangle {
    id: plate

    x: Theme.nearbyChosenInset + root.currentIndex * root.segmentWidth
    y: Theme.nearbyChosenInset
    width: root.segmentWidth
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
    x: Theme.nearbyChosenInset
    y: 0
    width: root.segmentWidth * root.segments.length
    height: root.height

    Repeater {
      model: root.segments

      Item {
        id: segment

        required property var modelData
        required property int index

        width: root.segmentWidth
        height: root.height

        readonly property bool isChosen: index === root.currentIndex
        readonly property bool muted: modelData.muted === true

        Row {
          anchors.centerIn: parent
          spacing: Theme.nearbySegmentGap

          StrokeIcon {
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.nearbySegmentGlyph
            strokeWidth: 1.75
            path: segment.modelData.icon
            filled: segment.modelData.filled === true
            color: segment.isChosen ? Theme.inkOnAccent : segment.muted ? Theme.inkTertiary : Theme.inkSecondary

            Behavior on color {
              Tint {}
            }
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: segment.modelData.label
            color: segment.isChosen ? Theme.inkOnAccent : segment.muted ? Theme.inkTertiary : Theme.inkSecondary
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
        Accessible.name: segment.modelData.label
        Accessible.focusable: true
        Accessible.focused: segment.activeFocus
        Accessible.onPressAction: root.chosen(segment.index)

        Keys.onPressed: function (event) {
          if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (!segment.muted)
              root.chosen(segment.index);
            event.accepted = true;
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: if (!segment.muted)
            root.chosen(segment.index)
        }
      }
    }
  }
}
