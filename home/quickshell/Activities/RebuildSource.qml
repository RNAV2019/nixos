import QtQuick
import qs.Commons
import qs.Services

// The rebuild in progress (Penpot "Ariadne / Satellite / Rebuild"): a ring that fills with
// the derivations built, running round while it is still evaluating, a check when it is done
// and a red ring when it failed; and the moments for a finished and a failed run. The data is
// Services/Rebuild.qml.
QtObject {
  id: root

  readonly property bool failed: Rebuild.phase === "failed"
  readonly property bool done: Rebuild.phase === "done"

  property Activity satellite: Activity {
    kind: "rebuild"
    key: "rebuild"
    active: Rebuild.shown
    attention: root.failed
    since: Rebuild.startedAt

    icon: root.failed ? IconPaths.x : root.done ? IconPaths.check : IconPaths.snowflake
    iconColor: root.failed ? Theme.urgent : root.done ? Theme.accent : Theme.inkPrimary
    indeterminate: Rebuild.phase === "evaluating"
    ring: Rebuild.phase === "evaluating" ? -1 : root.failed || root.done ? 1 : Rebuild.fraction
    ringColor: root.failed ? Theme.urgent : Theme.accent
    haloColor: Theme.urgent

    chipColor: root.failed ? Theme.urgent : Theme.accent
    title: root.failed ? "Rebuild failed" : root.done ? Rebuild.doneTitle : Rebuild.phaseTitles[Rebuild.phase] || ""
    subtitle: Rebuild.host
    value: Rebuild.phase === "building" && Rebuild.total > 0 ? Rebuild.done + "/" + Rebuild.total : ""

    card: Component {
      RebuildCard {}
    }
  }

  property Connections cues: Connections {
    target: Rebuild

    function onFinished() {
      var n = Rebuild.changed;
      Activities.raiseMoment({
        kind: "rebuild-finished",
        key: "rebuild",
        attention: false,
        icon: IconPaths.packageCheck,
        iconColor: Theme.accent,
        title: Rebuild.doneTitle,
        subtitle: n === 0 ? "No packages changed" : n + (n === 1 ? " package changed" : " packages changed"),
        buttons: Rebuild.diffFile === "" ? [] : [
          {
            text: "Show diff",
            kind: "primary",
            width: 84,
            action: () => Rebuild.showDiff()
          }
        ]
      });
    }

    function onFailed() {
      Activities.raiseMoment({
        kind: "rebuild-failed",
        key: "rebuild",
        attention: true,
        dwell: 0,
        icon: IconPaths.circleX,
        iconColor: Theme.urgent,
        title: "Rebuild failed",
        subtitle: Rebuild.error,
        buttons: [
          {
            text: "Dismiss",
            kind: "ghost",
            width: 70
          },
          {
            text: "Show log",
            kind: "danger",
            width: 80,
            action: () => Rebuild.showLog()
          }
        ]
      });
    }
  }
}
