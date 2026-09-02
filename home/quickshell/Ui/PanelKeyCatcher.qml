import QtQuick

// Keyboard entry point for a panel card.
//
// Keys.priority is BeforeItem so arrow keys reach these handlers instead of
// being consumed by the Flickable inside Ui/ScrollView.qml, which otherwise
// swallows Up/Down for its own scrolling.
Item {
  id: root

  // Panels raise this while an inline editor holds focus, so typing a
  // password does not also drive navigation.
  property bool blocked: false

  signal closeRequested
  signal moveRequested(int dx, int dy)
  signal activateRequested
  signal tabRequested(int direction)
  signal textKey(string text)

  focus: true
  Keys.priority: Keys.BeforeItem

  Keys.onPressed: function (event) {
    // Escape still closes while blocked; it is how the editor is escaped.
    if (event.key === Qt.Key_Escape) {
      root.closeRequested();
      event.accepted = true;
      return;
    }

    if (root.blocked)
      return;

    switch (event.key) {
    case Qt.Key_Left:
    case Qt.Key_H:
      root.moveRequested(-1, 0);
      break;
    case Qt.Key_Right:
    case Qt.Key_L:
      root.moveRequested(1, 0);
      break;
    case Qt.Key_Up:
    case Qt.Key_K:
      root.moveRequested(0, -1);
      break;
    case Qt.Key_Down:
    case Qt.Key_J:
      root.moveRequested(0, 1);
      break;
    case Qt.Key_Return:
    case Qt.Key_Enter:
    case Qt.Key_Space:
      root.activateRequested();
      break;
    case Qt.Key_Tab:
      root.tabRequested(1);
      break;
    case Qt.Key_Backtab:
      root.tabRequested(-1);
      break;
    default:
      if (event.text.length > 0)
        root.textKey(event.text);
      return;
    }

    event.accepted = true;
  }
}
