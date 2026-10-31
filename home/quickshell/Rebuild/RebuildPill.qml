import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Ui
import "../Commons/Duration.js" as Duration

// The rebuild pill (Penpot "T / Rebuild pill"): an IslandPill row (Ui/IslandPill.qml) with a label
// before the track. The island grows out of its pill when a `rebuild` starts (Services/Rebuild.qml),
// shows "Rebuilding" and n of m derivations as a fraction, then "Switched" and how long it took,
// and after a short dwell melts back; a failed one says so and stays, outlined in love, until it
// is clicked away or the next rebuild starts. Hovering holds the finished states. It cannot be
// cancelled from here: the rebuild runs in a terminal. Ranked with the Sharing pill's progress,
// under everything that wants an answer, and waits behind a user-opened panel.
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

    readonly property bool building: Rebuild.running
    readonly property bool finished: Rebuild.phase === "done"
    readonly property bool failed: Rebuild.phase === "failed"

    // Counted down on screen only, and held by the pointer; the failure never times out.
    Timer {
      running: win.open && win.finished && !hover.hovered
      interval: Theme.sharingConfirmDwell
      onTriggered: Rebuild.dismiss()
    }

    // Laid out at its final size and centred, so the growing shape reveals it. A click sends it
    // away, which is also how a failure is acknowledged.
    Item {
      id: stage

      x: (win.surface.width - width) / 2
      y: (win.surface.height - height) / 2
      width: Theme.islandPillWidth
      height: Theme.islandPillHeight

      HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
      }

      TapHandler {
        enabled: win.open
        onTapped: Rebuild.dismiss()
      }

      // ---- Building ----
      PillState {
        anchors.fill: parent
        shown: win.building

        // The total is not known yet while it evaluates: a segment slides across instead.
        IslandPill {
          anchors.fill: parent
          layout: "glyphLabelTrackReading"
          label: "Rebuilding"
          reading: Rebuild.total > 0 ? Math.round(Rebuild.fraction * 100) + "%" : "…"
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
