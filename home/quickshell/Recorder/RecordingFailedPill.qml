import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Ui

// The recording-failed pill (board "T / Recording pill"): an IslandPill row (Ui/IslandPill.qml)
// that grows out of the island when a recording left nothing behind (Services/Recorder.qml),
// says so, outlined in love, and melts back after the same dwell as a failed rebuild, or when
// the next recording starts. It carries no reading: the reason is wl-screenrec's own words and
// does not fit one, so it is in the log. The pointer passes through it. Ranked with the
// rebuild pill, under everything that wants an answer, and waits behind a user-opened panel.
Variants {
  model: Quickshell.screens

  TransientSurface {
    id: win

    key: "recording"
    rank: 0

    wanted: Recorder.failure !== "" && win.focused && !Bus.islandOpenFor(win.screenName)

    openWidth: Theme.islandPillWidth
    openHeight: Theme.islandPillHeight
    openRadius: Theme.islandPillRadius

    cardInput: false

    // Counted down on screen only.
    Timer {
      running: win.open
      interval: Theme.rebuildFailedDwell
      onTriggered: Recorder.dismissFailure()
    }

    // Laid out at its final size and centred, so the growing shape reveals it.
    Item {
      x: (win.surface.width - width) / 2
      y: (win.surface.height - height) / 2
      width: Theme.islandPillWidth
      height: Theme.islandPillHeight

      IslandPill {
        anchors.fill: parent
        layout: "glyphLabelReading"
        alert: true
        label: "Recording failed"

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
