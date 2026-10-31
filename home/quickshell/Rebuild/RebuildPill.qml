import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Ui
import "../Commons/Duration.js" as Duration

// The rebuild pill (Penpot "T / Rebuild pill"): an IslandPill row (Ui/IslandPill.qml) with a label
// before the track. The island grows out of its pill when a `rebuild` starts (Services/Rebuild.qml),
// shows "Rebuilding" and how much of what Nix builds and fetches is done, then "Switched" and how
// long it took, and after a short dwell melts back; a failed one says so, outlined in love, for
// longer. The pointer passes through it: the rebuild runs in a terminal, which is where to act on
// it. Ranked with the Sharing pill's progress, under everything that wants an answer, and waits
// behind a user-opened panel.
Variants {
  model: Quickshell.screens

  TransientSurface {
    id: win

    key: "rebuild"
    rank: 0

    wanted: Rebuild.shown && win.focused && !Bus.islandOpenFor(win.screenName)

    openWidth: Theme.islandPillWidth
    openHeight: Theme.islandPillHeight
    openRadius: Theme.islandPillRadius

    cardInput: false

    readonly property bool building: Rebuild.running
    readonly property bool finished: Rebuild.phase === "done"
    readonly property bool failed: Rebuild.phase === "failed"

    // Counted down on screen only.
    Timer {
      running: win.open && (win.finished || win.failed)
      interval: win.failed ? Theme.rebuildFailedDwell : Theme.sharingConfirmDwell
      onTriggered: Rebuild.dismiss()
    }

    // Laid out at its final size and centred, so the growing shape reveals it.
    Item {
      id: stage

      x: (win.surface.width - width) / 2
      y: (win.surface.height - height) / 2
      width: Theme.islandPillWidth
      height: Theme.islandPillHeight

      // ---- Building ----
      PillState {
        anchors.fill: parent
        shown: win.building

        // The total is not known yet while it evaluates: a segment slides across instead.
        IslandPill {
          anchors.fill: parent
          layout: "glyphLabelTrackReading"
          label: "Rebuilding"
          reading: Rebuild.total > 0 ? Math.round(Rebuild.fraction * 100) + "%" : ""
          tabularReading: true
          value: Rebuild.fraction
          indeterminate: Rebuild.total === 0
          running: win.open

          StrokeIcon {
            anchors.centerIn: parent
            size: Theme.islandPillGlyphSize
            strokeWidth: 1.75
            path: IconPaths.snowflake
            color: Theme.inkPrimary
          }
        }
      }

      // ---- Done ----
      PillState {
        anchors.fill: parent
        shown: win.finished

        IslandPill {
          anchors.fill: parent
          layout: "glyphLabelReading"
          label: "Switched"
          reading: Duration.elapsed(Rebuild.endedAt - Rebuild.startedAt)
          readingColor: Theme.inkSecondary
          tabularReading: true

          StrokeIcon {
            anchors.centerIn: parent
            size: Theme.islandPillGlyphSize
            strokeWidth: 1.75
            path: IconPaths.check
            color: Theme.accentFill
          }
        }
      }

      // ---- Failed ----
      PillState {
        anchors.fill: parent
        shown: win.failed

        // How far it got, when it knew how far there was to go.
        IslandPill {
          anchors.fill: parent
          layout: "glyphLabelReading"
          alert: win.failed
          label: "Rebuild failed"
          reading: Rebuild.total > 0 ? Rebuild.done + "/" + Rebuild.total : ""
          readingColor: Theme.love
          tabularReading: true

          StrokeIcon {
            anchors.centerIn: parent
            size: Theme.islandPillGlyphSize
            strokeWidth: 1.75
            path: IconPaths.circleX
            color: Theme.love
          }
        }
      }
    }
  }
}
