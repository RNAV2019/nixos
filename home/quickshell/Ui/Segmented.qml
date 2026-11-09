import QtQuick
import qs.Commons

// A segmented control: a track with a chosen plate that slides between cells on the
// workspace-slot spring, its front edge a little ahead of its back one, so it stretches on the way
// and is the cell's size again when it lands. A segment may set `pending`, which holds the plate in a soft pulse
// while a backend comes up (the AWDL radio, 10-30 s), and `enabled: false` to dim and skip it.
//
// By default the cells share the track equally, as the Send / Receive control and the display
// alignment rows do. `fit` sizes each to its label with 12 px either side, which is how the
// three labels of the platform control are made to fit; `compact` is the 22 px row of
// short labels (the frame rates, the file picker's source) with no track under it.
//
// One tab stop: Left and Right move a keyboard cursor over the enabled segments, Space and
// Enter choose the one under it.
Item {
  id: root

  // A content-morph anchor (Ui/MorphScan.js): what it is, and what pairs it across panels.
  property string morphRole: "segmented"
  property string morphKey: ""
  property var morphSlot: undefined

  // One per segment: { label?, icon?, filled?, name?, enabled? }. `name` is what a screen
  // reader says when there is no label.
  required property var segments
  // -1 when none of the segments is the current one.
  property int currentIndex: 0
  property bool pending: false
  property bool fit: false
  property bool compact: false
  property string accessibleName: ""

  signal chosen(int index)

  readonly property real pad: compact ? 0 : Theme.nearbyChosenInset
  readonly property real cellHeight: compact ? Theme.segmentCompactHeight : Theme.nearbyChosenHeight

  // Where the chosen cell is, written by that cell.
  property real plateX: 0
  property real plateWidth: 0
  // The plate takes its place at once when the control appears, and glides after that.
  property bool settled: false
  // Focus that arrived by a click shows no cursor until a key moves it.
  property bool pointerFocused: false
  // The segment Left and Right have reached.
  property int cursor: Math.max(0, currentIndex)

  implicitWidth: fit || compact ? cells.implicitWidth + pad * 2 : Theme.nearbyTrackWidth
  implicitHeight: compact ? Theme.segmentCompactHeight : Theme.nearbyTrackHeight

  activeFocusOnTab: true
  Accessible.role: Accessible.Grouping
  Accessible.name: root.accessibleName

  function enabledAt(index) {
    return index >= 0 && index < root.segments.length && root.segments[index].enabled !== false;
  }

  function step(direction) {
    for (var i = root.cursor + direction; i >= 0 && i < root.segments.length; i += direction) {
      if (root.enabledAt(i)) {
        root.cursor = i;
        return;
      }
    }
  }

  // The cursor follows the choice, and stays where the keys left it while focus comes and goes.
  onCurrentIndexChanged: root.cursor = Math.max(0, root.currentIndex)

  onActiveFocusChanged: if (!root.activeFocus)
    root.pointerFocused = false

  Component.onCompleted: Qt.callLater(function () {
    root.settled = true;
  })

  Keys.onPressed: function (event) {
    root.pointerFocused = false;
    if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
      root.step(event.key === Qt.Key_Left ? -1 : 1);
      event.accepted = true;
    } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (root.enabledAt(root.cursor))
        root.chosen(root.cursor);
      event.accepted = true;
    }
  }

  Rectangle {
    anchors.fill: parent
    visible: !root.compact
    radius: Theme.nearbyTrackRadius
    color: Theme.lift(Theme.liftTile)
    border.width: 1
    border.color: Theme.lift(Theme.liftEdge)
  }

  Rectangle {
    id: plate

    visible: root.currentIndex >= 0
    // Which way it is heading: where its middle is going against where its middle is.
    readonly property bool rightward: root.plateX + root.plateWidth / 2 > (xSpring.value + rSpring.value) / 2

    x: xSpring.value
    y: root.pad
    width: Math.max(0, rSpring.value - xSpring.value)
    height: root.cellHeight
    radius: height / 2
    color: Theme.accentFill

    // The plate's two edges, each a spring: the one in front is Theme.segmentLead quicker than the
    // one behind, which keeps the pace the plate always had, so the plate is longer while it
    // travels and the cell's own width when both have landed. Critically damped, unlike the
    // shell's other springs, so neither edge passes the cell it is going to. The label is the
    // control's own address (its toString), unique per instance: Segmented lives in several
    // places at once and one label is one spring in the motion log.
    MorphSpring {
      id: xSpring

      readonly property string who: root.toString().replace(/^.*\(0x([0-9a-f]+)\).*$/, "$1")

      target: root.plateX
      omega: plate.rightward ? Theme.microOmega : Theme.microOmega * Theme.segmentLead
      damping: 1
      animate: root.settled
      label: "seg." + who + ".x"
    }

    MorphSpring {
      id: rSpring

      target: root.plateX + root.plateWidth
      omega: plate.rightward ? Theme.microOmega * Theme.segmentLead : Theme.microOmega
      damping: 1
      animate: root.settled
      label: "seg." + xSpring.who + ".r"
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
    y: root.pad
    spacing: root.compact ? Theme.segmentCompactGap : 0

    Repeater {
      id: cellRepeater

      model: root.segments

      SegmentCell {
        id: cell

        required property var modelData
        required property int index

        width: root.compact ? Theme.segmentCompactWidth : root.fit ? fitWidth : (root.width - root.pad * 2) / root.segments.length
        height: root.cellHeight
        chosen: index === root.currentIndex
        label: modelData.label !== undefined ? modelData.label : ""
        icon: modelData.icon !== undefined ? modelData.icon : ""
        iconFilled: modelData.filled === true
        enabled: modelData.enabled !== false
        accessibleName: modelData.name !== undefined ? modelData.name : label
        onClicked: root.chosen(index)
        onPressedChanged: if (pressed) {
          root.pointerFocused = true;
          root.forceActiveFocus();
        }

        Binding {
          target: root
          property: "plateX"
          value: root.pad + cell.x
          when: cell.chosen
          // The cell that lets go must not put the old value back over the one that takes it.
          restoreMode: Binding.RestoreNone
        }

        Binding {
          target: root
          property: "plateWidth"
          value: cell.width
          when: cell.chosen
          restoreMode: Binding.RestoreNone
        }
      }
    }
  }

  // The keyboard cursor, drawn over the cell it is on. It fades like ButtonBase's ring, and
  // stays over the cell it was last on while it fades out.
  Rectangle {
    // A focus state, not contents: a content morph leaves it out.
    readonly property bool morphIgnore: true
    readonly property Item under: root.activeFocus && !root.pointerFocused ? cellRepeater.itemAt(root.cursor) : null
    property Item last: null

    onUnderChanged: if (under)
      last = under

    opacity: under !== null ? 1 : 0
    visible: opacity > 0
    x: last ? root.pad + last.x : 0
    y: root.pad
    width: last ? last.width : 0
    height: root.cellHeight
    radius: height / 2
    color: "transparent"
    border.width: 1
    border.color: Theme.focusRing

    Behavior on opacity {
      Morph {
        duration: Theme.focusFade
      }
    }
  }
}
