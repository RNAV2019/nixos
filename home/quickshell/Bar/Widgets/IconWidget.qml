import QtQuick
import qs.Commons

Item {
  id: root

  property string glyph: ""
  property string label: ""
  property color glyphColor: Theme.text
  property bool labelFirst: false
  property int gap: Theme.barLabelGap
  property alias hovered: hover.hovered

  signal activated
  signal secondaryActivated
  signal scrolled(int delta)

  // An open panel covers the bar with its own overlay surface. That overlay
  // hit-tests clicks landing in the bar strip and replays them here, so
  // switching from one panel to another stays a single click.
  function triggerPress(button) {
    if (button === Qt.RightButton)
      root.secondaryActivated();
    else
      root.activated();
  }

  // Own both side paddings; the parent row must keep spacing at zero.
  implicitWidth: row.implicitWidth + Theme.barIconPadding * 2
  implicitHeight: Theme.barHeight

  // Fade only glyph changes; labels such as battery percentage update too often.
  onGlyphChanged: glyphFade.restart()

  Row {
    id: row

    anchors.centerIn: parent
    spacing: root.label.length > 0 ? root.gap : 0
    layoutDirection: root.labelFirst ? Qt.RightToLeft : Qt.LeftToRight

    Text {
      id: glyphText

      anchors.verticalCenter: parent.verticalCenter
      text: root.glyph
      color: root.glyphColor
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize

      NumberAnimation on opacity {
        id: glyphFade
        running: false
        from: 0.35
        to: 1
        duration: Theme.animSlow
        easing.type: Easing.OutCubic
      }

      Behavior on color {
        ColorAnimation {
          duration: Theme.animFast
        }
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.label.length > 0
      text: root.label
      color: root.glyphColor
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
    }
  }

  HoverHandler {
    id: hover
    cursorShape: Qt.PointingHandCursor
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function (event) {
      if (event.button === Qt.RightButton)
        root.secondaryActivated();
      else
        root.activated();
    }
    onWheel: function (wheel) {
      root.scrolled(wheel.angleDelta.y > 0 ? 1 : -1);
    }
  }
}
