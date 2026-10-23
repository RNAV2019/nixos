import QtQuick
import qs.Commons
import qs.Services

// The launcher's chat with Claude (Services/ClaudeChat.qml), drawn in the list's place. The
// search field is its input: Return sends, and the keys below steer the transcript, since
// the launcher hides the cursor. A quiet meta line, then the turns on the field's text
// column: the user's with an accent marker in the gutter, Claude's with a muted glyph.
Item {
  id: root

  // Written by the launcher: the most this view may grow to on this screen.
  property real maxHeight: Theme.launcherViewMaxHeight

  readonly property string placeholder: ClaudeChat.streaming ? "Esc to stop" : ClaudeChat.turns.count > 0 ? "Ask a follow-up…" : ClaudeChat.hint

  // The gutter and text column, in the view's own coordinates: the list's icon and text
  // columns, so the transcript lines up with the field above it.
  readonly property real gutterX: Theme.launcherIconLeft - Theme.launcherInset
  readonly property real textX: Theme.launcherTextLeft - Theme.launcherInset
  readonly property real textWidth: width - textX - Theme.launcherInset

  implicitHeight: Theme.launcherChatMetaHeight + (ClaudeChat.turns.count > 0 ? Theme.launcherChatTurnGap / 2 + transcript.height : 0)

  // Off while the reader has paged up; back on at the bottom, or on sending.
  property bool follow: true

  function scrollTo(y) {
    var max = Math.max(0, flick.contentHeight - flick.height);
    flick.contentY = Math.max(0, Math.min(max, y));
    root.follow = flick.contentY >= max - 1;
  }

  function keyPressed(event) {
    var ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
    switch (event.key) {
    case Qt.Key_Escape:
      if (!ClaudeChat.streaming)
        return;
      ClaudeChat.stop();
      break;
    case Qt.Key_C:
      if (!ctrl)
        return;
      var reply = ClaudeChat.lastReply();
      if (reply.length > 0) {
        Clipboard.copy(reply);
        copied.restart();
      }
      break;
    case Qt.Key_N:
      if (!ctrl)
        return;
      ClaudeChat.newChat();
      root.follow = true;
      break;
    case Qt.Key_Tab:
      ClaudeChat.cycleModel();
      break;
    case Qt.Key_PageUp:
      root.scrollTo(flick.contentY - flick.height * Theme.launcherChatPageStep);
      break;
    case Qt.Key_PageDown:
      root.scrollTo(flick.contentY + flick.height * Theme.launcherChatPageStep);
      break;
    case Qt.Key_Up:
      root.scrollTo(flick.contentY - Theme.launcherRowHeight);
      break;
    case Qt.Key_Down:
      root.scrollTo(flick.contentY + Theme.launcherRowHeight);
      break;
    case Qt.Key_Home:
      if (!ctrl)
        return;
      root.scrollTo(0);
      break;
    case Qt.Key_End:
      if (!ctrl)
        return;
      root.scrollTo(flick.contentHeight);
      break;
    default:
      return;
    }
    event.accepted = true;
  }

  function submit(text) {
    if (!ClaudeChat.send(text))
      return false;
    root.follow = true;
    return true;
  }

  Timer {
    id: copied

    interval: 1400
  }

  // ---- meta line ----

  Text {
    x: root.textX
    y: (Theme.launcherChatMetaHeight - height) / 2
    text: {
      var m = ClaudeChat.model;
      return "Claude " + m.charAt(0).toUpperCase() + m.substr(1);
    }
    color: Theme.inkTertiary
    font.family: Theme.uiFont
    font.pixelSize: Theme.launcherChatMetaSize
    font.weight: Theme.weightMedium
  }

  Text {
    x: root.width - width - Theme.launcherInset
    y: (Theme.launcherChatMetaHeight - height) / 2
    text: copied.running ? "Copied" : ClaudeChat.turns.count > 0 ? "⇥ Model   ⌃N New chat   ⌃C Copy" : "⇥ Model"
    color: copied.running ? Theme.accent : Theme.inkTertiary
    font.family: Theme.uiFont
    font.pixelSize: Theme.launcherChatMetaSize
  }

  // ---- transcript ----

  Flickable {
    id: flick

    y: Theme.launcherChatMetaHeight + Theme.launcherChatTurnGap / 2
    width: root.width
    height: Math.max(0, root.height - y)
    contentWidth: width
    contentHeight: transcript.height
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    // Following, the newest line stays in view as the reply grows.
    onContentHeightChanged: {
      if (root.follow)
        flick.contentY = Math.max(0, flick.contentHeight - flick.height);
    }
    onHeightChanged: {
      if (root.follow)
        flick.contentY = Math.max(0, flick.contentHeight - flick.height);
    }

    Column {
      id: transcript

      width: flick.width
      spacing: Theme.launcherChatTurnGap
      bottomPadding: Theme.launcherChatTurnGap / 2

      Repeater {
        model: ClaudeChat.turns

        delegate: ChatTurn {
          required property int index
          required property string role
          required property string text
          required property string error
          required property string detail

          width: transcript.width
          gutterX: root.gutterX
          textX: root.textX
          textWidth: root.textWidth
          user: role === "user"
          body: text
          errorKind: error
          errorDetail: detail
          // Only the turn being answered waits on the dots.
          waiting: ClaudeChat.waiting && index === ClaudeChat.turns.count - 1
        }
      }
    }
  }

  // Where the reader is in a transcript taller than the view.
  Rectangle {
    x: root.width - width
    y: flick.y + flick.visibleArea.yPosition * flick.height
    width: Theme.launcherMarkerWidth
    height: Math.max(Theme.launcherMarkerHeight, flick.visibleArea.heightRatio * flick.height)
    radius: width / 2
    color: Theme.withAlpha(Theme.text, Theme.fillSelected)
    visible: flick.contentHeight > flick.height + 1
  }
}
