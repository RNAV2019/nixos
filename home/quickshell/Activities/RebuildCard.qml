import QtQuick
import qs.Commons
import qs.Services
import qs.Ui
import "../Commons/Duration.js" as Duration

// The hover card of the rebuild satellite (Penpot "Ariadne / Activity card / Rebuild"): while it
// runs, the phase, a track that fills with the derivations built (or a segment that slides while
// it is still evaluating), the derivation building now and Show log; once it is over, what
// changed and Show diff, or the error and Show log.
Item {
  id: root

  readonly property string phase: Rebuild.phase
  readonly property bool failed: phase === "failed"
  readonly property bool finished: phase === "done"
  readonly property bool evaluating: phase === "evaluating"

  // The last height it had, so closing after a dismissal does not collapse the card early.
  property real settled: 200
  readonly property real wanted: failed ? 190 : finished ? 172 : 200
  onWantedChanged: if (phase !== "")
    settled = wanted

  implicitWidth: Theme.activityCardWidth
  implicitHeight: settled

  readonly property color tint: failed ? Theme.urgent : Theme.accent
  readonly property real inner: width - 2 * Theme.activityCardPad

  function clock(ms) {
    return Duration.clock(ms);
  }

  CardHeader {
    icon: root.failed ? IconPaths.circleX : root.finished ? IconPaths.packageCheck : IconPaths.snowflake
    tint: root.tint
    reserve: root.finished || root.failed ? 0 : 56
    title: root.failed ? "Rebuild failed" : root.finished ? Rebuild.doneTitle : Rebuild.phaseTitles[root.phase] || ""
    caption: {
      if (root.failed)
        return (Rebuild.phaseTitles[Rebuild.stage] || "Starting") + " · " + root.clock(Rebuild.elapsed);
      if (root.finished)
        return (Rebuild.generation > 0 ? "Generation " + Rebuild.generation + " · " : "") + root.clock(Rebuild.elapsed);
      return root.evaluating ? "evaluating flake" : Rebuild.mode + " · " + Rebuild.host;
    }
  }

  // ---- running ----

  Text {
    visible: !root.finished && !root.failed
    x: root.width - Theme.activityCardPad - width
    y: 34 - height / 2
    text: root.clock(Rebuild.elapsed)
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: 13
    font.weight: Theme.weightSemi
    font.features: {
      "tnum": 1
    }
  }

  ProgressTrack {
    id: track

    visible: !root.finished && !root.failed
    x: Theme.activityCardPad
    y: 70
    width: root.inner
    fraction: root.evaluating ? 0 : Rebuild.fraction
    tint: Theme.accent
    clip: true

    // Evaluation has no length to show: a segment slides along the track.
    Rectangle {
      id: segment

      visible: root.evaluating
      y: 0
      width: 92
      height: parent.height
      radius: height / 2
      color: Theme.accent

      SequentialAnimation on x {
        loops: Animation.Infinite
        running: root.evaluating && root.visible && !Theme.reduceMotion
        NumberAnimation {
          from: -92
          to: track.width
          duration: 1200
          easing.type: Easing.InOutSine
        }
      }
    }
  }

  Text {
    visible: !root.finished && !root.failed
    x: Theme.activityCardPad
    y: 96 - height / 2
    text: root.evaluating ? "Evaluating configuration" : root.phase === "activating" ? "Switching to the new generation" : Rebuild.done + " / " + Rebuild.total + " " + Rebuild.unit
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: Theme.activityDetailSize
  }

  Text {
    visible: root.phase === "building" && Rebuild.total > 0
    x: root.width - Theme.activityCardPad - width
    y: 96 - height / 2
    text: Math.round(Rebuild.fraction * 100) + "%"
    color: Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: Theme.activityDetailSize
    font.weight: Theme.weightSemi
    font.features: {
      "tnum": 1
    }
  }

  Rectangle {
    visible: !root.finished && !root.failed
    x: Theme.activityCardPad
    y: 110
    width: root.inner
    height: 32
    radius: 12
    color: Theme.surfaceSubtle

    Text {
      x: 12
      y: (parent.height - height) / 2
      width: parent.width - 24
      elide: Text.ElideRight
      text: root.evaluating ? Rebuild.host : root.phase === "activating" ? Rebuild.detail : Rebuild.current
      color: Theme.inkPrimary
      font.family: Theme.monoFont
      font.pixelSize: 11
    }
  }

  ActivityButton {
    visible: !root.finished && !root.failed
    x: root.width - Theme.activityCardPad - width
    y: 154
    width: 96
    kind: "secondary"
    icon: IconPaths.scrollText
    text: "Show log"
    onClicked: Rebuild.showLog()
  }

  // ---- finished ----

  Text {
    visible: root.finished
    x: Theme.activityCardPad
    y: 76 - height / 2
    text: Rebuild.changed === 0 ? "No packages changed" : Rebuild.changed + (Rebuild.changed === 1 ? " package changed" : " packages changed")
    color: Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: 13
    font.weight: Theme.weightSemi
  }

  Text {
    visible: root.finished
    x: Theme.activityCardPad
    y: 94 - height / 2
    width: root.inner
    elide: Text.ElideRight
    text: Rebuild.summary
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: Theme.activityDetailSize
  }

  // ---- failed ----

  Text {
    visible: root.failed
    x: Theme.activityCardPad
    y: 74 - height / 2
    text: "Error"
    color: Theme.inkTertiary
    font.family: Theme.uiFont
    font.pixelSize: Theme.sectionSize
    font.weight: Theme.weightMedium
  }

  Rectangle {
    visible: root.failed
    x: Theme.activityCardPad
    y: 88
    width: root.inner
    height: 44
    radius: Theme.activityWellRadius
    color: Theme.surfaceSubtle

    Text {
      x: 12
      y: (parent.height - height) / 2
      width: parent.width - 24
      elide: Text.ElideRight
      text: Rebuild.error
      color: Theme.urgent
      font.family: Theme.monoFont
      font.pixelSize: Theme.activityDetailSize
    }
  }

  Row {
    visible: root.finished || root.failed
    x: root.width - Theme.activityCardPad - width
    y: root.failed ? 144 : 126
    spacing: Theme.activityButtonGap

    ActivityButton {
      kind: "secondary"
      width: 76
      text: "Dismiss"
      onClicked: {
        Rebuild.dismiss();
        Activities.closeCard();
      }
    }

    ActivityButton {
      visible: root.failed || Rebuild.diffFile !== ""
      kind: root.failed ? "danger" : "primary"
      width: root.failed ? 94 : 102
      icon: root.failed ? IconPaths.scrollText : IconPaths.fileDiff
      text: root.failed ? "Show log" : "Show diff"
      onClicked: root.failed ? Rebuild.showLog() : Rebuild.showDiff()
    }
  }
}
