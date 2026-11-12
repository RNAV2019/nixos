import QtQuick
import qs.Commons
import qs.Ui

// A computed answer in the launcher's list, as a card: how the question was read on a quiet
// line, the answer large under it. It has no icon; the size says what it is.
Item {
  id: root

  property string answer: ""
  property string reading: ""
  property bool current: false

  signal activated(int modifiers)

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: root.answer
  Accessible.description: root.reading
  Accessible.focusable: true
  Accessible.focused: root.activeFocus
  Accessible.onPressAction: root.activated(Qt.NoModifier)

  // The card at rest. Selected, the list's highlight is its fill and this one steps aside, so
  // the two never add up.
  Rectangle {
    anchors.fill: parent
    radius: Theme.launcherRowRadius
    color: Theme.lift(Theme.liftTile)
    opacity: root.current ? 0 : 1

    Behavior on opacity {
      Morph {
        duration: Theme.duration(Theme.morphState)
      }
    }
  }

  Text {
    x: Theme.launcherAnswerPad
    y: Theme.launcherAnswerReadTop
    width: parent.width - Theme.launcherAnswerPad * 2
    text: root.reading
    textFormat: Text.PlainText
    color: Theme.inkTertiary
    elide: Text.ElideRight
    font.family: Theme.uiFont
    font.pixelSize: Theme.launcherDescSize
  }

  // Sits on one baseline whatever its size: a long answer is set smaller to fit, and only then
  // cut short.
  Text {
    x: Theme.launcherAnswerPad
    width: parent.width - Theme.launcherAnswerPad * 2
    anchors.baseline: parent.top
    anchors.baselineOffset: Theme.launcherAnswerBaseline
    text: root.answer
    textFormat: Text.PlainText
    color: Theme.inkPrimary
    elide: Text.ElideRight
    fontSizeMode: Text.HorizontalFit
    minimumPixelSize: Theme.launcherAnswerMinSize
    font.family: Theme.uiFont
    font.pixelSize: Theme.launcherAnswerSize
    font.weight: Theme.weightSemi
  }

  // A click still copies, but hover never moves the selection: the cursor is hidden.
  MouseArea {
    anchors.fill: parent
    onPressed: root.forceActiveFocus()
    onClicked: function (mouse) {
      root.activated(mouse.modifiers);
    }
  }

  Keys.onPressed: function (event) {
    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.activated(event.modifiers);
      event.accepted = true;
    }
  }
}
