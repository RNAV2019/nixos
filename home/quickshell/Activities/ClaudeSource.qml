import QtQuick
import qs.Commons
import qs.Services

// Claude Code sessions that need the user (Penpot "Ariadne / Satellite / Claude"): one satellite
// while any waits, in the accent with a halo that pulses until its card is opened, and a moment
// ("Claude needs you") when one begins to wait. The data is Services/ClaudeSessions.qml.
QtObject {
  id: root

  readonly property var waiting: ClaudeSessions.list

  property Activity satellite: Activity {
    kind: "claude"
    key: "claude"
    active: root.waiting.length > 0
    attention: true

    icon: IconPaths.claude
    iconSize: 16
    iconColor: Theme.inkOnAccent
    ground: Theme.accent
    haloColor: Theme.accent

    chipColor: Theme.accent
    title: root.waiting.length === 1 ? root.waiting[0].project : root.waiting.length + " sessions waiting"
    subtitle: "Claude Code"
    value: root.waiting.length > 1 ? String(root.waiting.length) : ""
    since: root.waiting.length > 0 ? root.waiting[0].since : 0

    card: Component {
      ClaudeCard {}
    }
  }

  // The satellite's halo pulses again for each session that begins to wait, even while an
  // earlier one has already been looked at.
  property Connections cue: Connections {
    target: ClaudeSessions

    function onNeedsYou(session) {
      root.satellite.acknowledged = ClaudeSessions.watched(session);
      if (ClaudeSessions.watched(session))
        return;
      root.moment(session);
    }
  }

  function moment(session) {
    var finished = session.state === "finished";
    Activities.raiseMoment({
      kind: finished ? "claude-finished" : session.state === "question" ? "claude-question" : "claude-permission",
      key: "claude:" + session.id,
      attention: true,
      icon: IconPaths.claude,
      iconColor: Theme.accent,
      title: session.project,
      subtitle: finished ? "Finished — waiting for input" : session.state === "question" ? session.detail : "Permission: " + session.detail,
      dwell: 10000,
      buttons: [
        {
          text: "Open",
          kind: "primary",
          width: 64,
          action: () => ClaudeSessions.open(session.id)
        }
      ]
    });
  }
}
