import QtQuick
import qs.Commons

// The pill's clock, drawn one Text per character so a digit that changes on the minute
// cross-fades to its next value. Each slot keeps its character's own advance, so the
// glyphs that did not change never move.
Item {
  id: root

  property string text
  property font font
  property color color

  // About half a glyph's height of travel.
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

        // The glyph this slot has settled on; comparing against it keeps an unchanged
        // digit perfectly still.
        property string shown
        property bool armed: false

        width: incoming.implicitWidth
        height: incoming.implicitHeight

        onGlyphChanged: {
          if (!armed || glyph === shown)
            return;

          // A change mid-roll: the arriving glyph snaps to rest first, so the next roll
          // always starts from a settled glyph.
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

        // Travel and the outgoing ink ride the content clock; the incoming ink trails
        // on the fast one, which dips the pair's total ink mid-roll.
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

            duration: Theme.morphState
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