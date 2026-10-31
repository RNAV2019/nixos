import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Ui
import "../Commons/Duration.js" as Duration

// The rebuild pill (Penpot "T / Rebuild pill"): the Sharing pill's progress state with a label
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

    openWidth: Theme.rebuildPillWidth
    openHeight: Theme.rebuildPillHeight
    openRadius: Theme.rebuildPillRadius

    readonly property bool building: Rebuild.phase === "building"
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
      width: Theme.rebuildPillWidth
      height: Theme.rebuildPillHeight

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
        shown: win.building

        StrokeIcon {
          x: Theme.dictationGlyphLeft
          y: (parent.height - size) / 2
          size: Theme.dictationGlyphSize
          strokeWidth: 1.75
          path: IconPaths.snowflake
          color: Theme.inkPrimary
        }

        Label {
          text: "Rebuilding"
        }

        // The total is not known yet while it evaluates: a segment slides across instead.
        Rectangle {
          id: track

          x: Theme.rebuildTrackLeft
          y: (parent.height - height) / 2
          width: Theme.rebuildTrackWidth
          height: Theme.rebuildTrackHeight
          radius: height / 2
          color: Theme.surfaceSubtle
          clip: true

          readonly property bool known: Rebuild.total > 0

          Rectangle {
            width: track.known ? track.width * Rebuild.fraction : 0
            height: parent.height
            radius: parent.radius
            color: Theme.accentFill

            Behavior on width {
              enabled: !Theme.reduceMotion

              Morph {
                duration: Theme.duration(Theme.morphProgress)
              }
            }
          }

          Rectangle {
            id: sweep

            readonly property real span: track.width * Theme.rebuildSweepShare

            visible: !track.known && !Theme.reduceMotion
            width: span
            height: parent.height
            radius: parent.radius
            color: Theme.accentFill

            NumberAnimation on x {
              from: -sweep.span
              to: track.width
              duration: Theme.rebuildSweep
              loops: Animation.Infinite
              running: sweep.visible && win.open
            }
          }
        }

        Value {
          text: track.known ? Math.round(Rebuild.fraction * 100) + "%" : "…"
          color: Theme.inkPrimary
        }
      }

      // ---- Done ----
      PillState {
        shown: win.finished

        StrokeIcon {
          x: Theme.dictationGlyphLeft
          y: (parent.height - size) / 2
          size: Theme.dictationGlyphSize
          strokeWidth: 1.75
          path: IconPaths.check
          color: Theme.accentFill
        }

        Label {
          text: "Switched"
        }

        Value {
          text: Duration.elapsed(Rebuild.endedAt - Rebuild.startedAt)
          color: Theme.inkSecondary
        }
      }

      // ---- Failed ----
      PillState {
        shown: win.failed

        StrokeIcon {
          x: Theme.dictationGlyphLeft
          y: (parent.height - size) / 2
          size: Theme.dictationGlyphSize
          strokeWidth: 1.75
          path: IconPaths.circleX
          color: Theme.love
        }

        Label {
          text: "Rebuild failed"
        }

        // How far it got, when it knew how far there was to go.
        Value {
          text: Rebuild.total > 0 ? Rebuild.done + "/" + Rebuild.total : ""
          color: Theme.love
        }
      }

      // The attention: the pill's own outline, in love, as the login pill's refusal is.
      Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        border.width: 1
        border.color: Theme.withAlpha(Theme.love, Theme.lockErrorOutline)
        opacity: win.failed ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          Morph {
            duration: Theme.duration(Theme.lockStateFade)
          }
        }
      }
    }
  }

  // One state's contents; the three cross-fade, so a new run replaces a failure where it stands.
  component PillState: Item {
    property bool shown: false

    anchors.fill: parent
    opacity: shown ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
      Morph {
        duration: Theme.morphContent * 2
      }
    }
  }

  component Label: Text {
    x: Theme.rebuildLabelLeft
    y: (parent.height - height) / 2
    color: Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: Theme.nearbyRowNameSize
    font.weight: Theme.weightMedium
  }

  // The reading at the right, its edge on the same inset as the Sharing pill's.
  component Value: Text {
    x: Theme.rebuildPillWidth - Theme.rebuildValueRight - width
    y: (parent.height - height) / 2
    font.family: Theme.uiFont
    font.pixelSize: Theme.osdValueSize
    font.weight: Theme.weightSemi
    font.features: {
      "tnum": 1
    }
  }
}
