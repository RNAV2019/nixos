import QtQuick
import qs.Commons

// What a content morph lets show of this panel's own contents (Ui/MorphLayer.qml), drawn over its
// content box and read by Shaders/roundedclip.frag in the red channel. Each arriving box (an
// anchor, or a loose part) arrives on its group's beat; an anchor whose partner is still flying
// in is held at 0 until it lands; anything not read yet stays hidden. Opaque, so
// a later (inner) anchor overwrites an outer one.
Item {
  id: root

  property MorphLayer host

  anchors.fill: parent

  Rectangle {
    anchors.fill: parent
    // Nothing that was not read shows: what the panel moves after a read waits for the next one.
    color: Qt.rgba(root.host ? 0 : 1, 0, 0, 1)
  }

  Repeater {
    model: root.host ? root.host.maskEntries : []

    // A box dropped from the model is deleted later; hidden now, so it never shows past its time.
    onItemRemoved: function (index, item) {
      item.visible = false;
    }

    Rectangle {
      required property var modelData

      readonly property string where: Math.round(modelData.x) + "," + Math.round(modelData.y) + "," + Math.round(modelData.w) + "," + Math.round(modelData.h)
      // When this box first came up (it may come up late, when the panel's layout settles after the first
      // read): an arrival never starts before it, so a box that moves is not seen to jump.
      property real firstSeen: -1

      Component.onCompleted: {
        var t = root.host.since[where];
        if (t === undefined) {
          t = root.host.clockRunning ? root.host.clock : 0;
          // A box that turns up in the panel's first few frames (its list filling in) was as good
          // as there from the start.
          if (t < 40)
            t = 0;
          root.host.since[where] = t;
        }
        firstSeen = t;
      }

      // In the way of a pair leading the panel, held back; once it has passed, arriving from then. Once
      // in, it stays in.
      property bool started: false
      readonly property bool covered: !modelData.paired && !started && (root.host.aheadOfLead(modelData.x, modelData.w, modelData.rowTop, modelData.rowBottom) || root.host.underCarouselTile(modelData.x, modelData.y, modelData.w, modelData.h))
      property real clearedAt: 0

      onCoveredChanged: if (!covered && !started)
        clearedAt = root.host.clock + root.host.leadStagger(modelData.rowTop)

      readonly property real shown: modelData.paired ? (root.host.landed ? 1 : 0) : firstSeen < 0 || covered ? 0 : root.host.arrivalFrom(modelData.rank, Math.max(firstSeen, clearedAt))

      onShownChanged: if (shown > 0 && !modelData.paired)
        started = true

      x: modelData.x - Theme.morphMaskBleed
      y: modelData.y - Theme.morphMaskBleed
      width: modelData.w + 2 * Theme.morphMaskBleed
      height: modelData.h + 2 * Theme.morphMaskBleed
      color: Qt.rgba(shown, 0, 0, 1)
    }
  }
}
