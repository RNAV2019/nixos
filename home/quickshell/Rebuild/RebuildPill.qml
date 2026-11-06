import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Ui
import "../Commons/Duration.js" as Duration

// The rebuild pill (Penpot "T / Rebuild pill"): an IslandPill row (Ui/IslandPill.qml) with a label
// before the track. The island grows out of its pill when a `rebuild` starts (Services/Rebuild.qml),
// shows what it is doing (Evaluating, Building, Activating) and how far through the whole rebuild
// it is, then "Switched" and how long it took, and after a short dwell melts back; a failed one
// says so, outlined in love, with how far it got, for longer. The pointer passes through it: the
// rebuild runs in a terminal, which is where to act on it. Ranked with the Sharing pill's
// progress, under everything that wants an answer, and waits behind a user-opened panel.
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

      x: win.surface.snap((parent.width - width) / 2)
      y: (parent.height - height) / 2
      width: Theme.islandPillWidth
      height: Theme.islandPillHeight

      // ---- Building ----
      PillState {
        anchors.fill: parent
        shown: win.building

        // The step it is on, and how far through the whole rebuild (Services/Rebuild.qml says how
        // that is measured). Rounded down, so 100% is only the moment it ends.
        IslandPill {
          anchors.fill: parent
          layout: "glyphLabelTrackReading"
          label: Rebuild.step === "building" ? "Building" : Rebuild.step === "activating" ? "Activating" : "Evaluating"
          reading: Math.floor(Rebuild.progress * 100) + "%"
          tabularReading: true
          value: Rebuild.progress
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

        // How far it got.
        IslandPill {
          anchors.fill: parent
          layout: "glyphLabelReading"
          alert: win.failed
          label: "Rebuild failed"
          reading: Math.floor(Rebuild.progress * 100) + "%"
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
