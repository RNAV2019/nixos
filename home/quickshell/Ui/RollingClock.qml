import QtQuick
import qs.Commons

// The pill's clock, drawn one Text per character so that a digit which
// changes on the minute can roll to its next value the way the source
// recording's does. Measured at 60 fps at 1:37, where 21:48 rolls to 21:49:
// the outgoing glyph rises by about half its own height and fades out on the
// content clock, while the incoming one rises into place from the same
// distance below and fades in behind it on the fast one. The two are seen
// overlapping mid-roll and no frame shows a clipped glyph, so this is a
// cross-fade and not a clipped reel; it is also why the pair's total ink
// dips in the middle, the two fades never summing to one.
//
// The slots keep each character's own advance - Inter's figures are
// proportional - so every glyph sits exactly where a single Text of the same
// string would have drawn it, and the characters that did not change never
// move. The colon never changes, and so never rolls.
Item {
  id: root

  property string text
  property font font
  property color color

  // About half a glyph's height of travel, measured off the roll at 1:37:
  // 10 px against a 15 px cap height at the recording's own clock size.
  readonly property real rollTravel: font.pixelSize * Theme.clockRollTravel

  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  Row {
    id: row

    Repeater {
      model: root.text.length

      Item {
        id: slot

        required property int index

        readonly property string glyph: root.text.charAt(index)

        // The glyph this slot has settled on. It is what the outgoing copy
        // shows when the next change arrives, and comparing against it is
        // what keeps a digit that did not change perfectly still.
        property string shown
        property bool armed: false

        width: incoming.implicitWidth
        height: incoming.implicitHeight

        onGlyphChanged: {
          if (!armed || glyph === shown)
            return;

          // A change while one roll is still under way: the glyph that was
          // arriving is the one that now leaves, and it snaps to rest first
          // so the next roll always starts from a settled glyph.
          if (roll.running) {
            roll.stop();
            incoming.y = 0;
            incoming.opacity = 1;
          }

          outgoing.text = incoming.text;
          outgoing.y = 0;
          outgoing.opacity = 1;
          incoming.y = root.rollTravel;
          incoming.opacity = 0;
          shown = glyph;
          roll.restart();
        }

        Component.onCompleted: {
          shown = glyph;
          armed = true;
        }

        Text {
          id: outgoing

          color: root.color
          font: root.font
          opacity: 0
          visible: opacity > 0
        }

        Text {
          id: incoming

          text: slot.glyph
          color: root.color
          font: root.font
        }

        // The travel rides the content clock, which settles in about five
        // frames - what the recording shows - and the outgoing ink fades on
        // the same clock. The incoming ink trails on the fast one, which is
        // what dips the pair's total ink mid-roll.
        ParallelAnimation {
          id: roll

          NumberAnimation {
            target: incoming

            duration: Theme.morphContent
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.morphCurve
            from: root.rollTravel
            property: "y"
            to: 0
          }

          NumberAnimation {
            target: outgoing

            duration: Theme.morphContent
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.morphCurve
            from: 0
            property: "y"
            to: -root.rollTravel
          }

          NumberAnimation {
            target: outgoing

            duration: Theme.morphContent
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.morphCurve
            from: 1
            property: "opacity"
            to: 0
          }

          NumberAnimation {
            target: incoming

            duration: Theme.animFast
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.morphCurve
            from: 0
            property: "opacity"
            to: 1
          }
        }
      }
    }
  }
}