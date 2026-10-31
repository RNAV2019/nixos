import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.Commons
import qs.Services
import qs.Ui

// Handy's recording overlay, drawn by the island instead of Handy's own window. SUPER+D (see
// home/dictation.nix) starts a dictation and the island grows into an OSD-sized row: the mic,
// level bars, the time and an × to cancel. Once live text arrives the row opens into a card,
// the row on top and the transcript flowing under it, the newest line always in view. Letting
// go turns the mic into a spinner while Handy finishes; then the text is typed and the pill
// melts back into the clock.
Scope {
  id: root

  Variants {
    model: Quickshell.screens

    // Outranks a toast and a share request: a dictation is short and the user is watching it.
    // The OSD still flashes over it and hands back.
    TransientSurface {
      id: win

      key: "dictation"
      rank: 3

      readonly property bool outputBlocked: Bus.islandOpenFor(win.screenName)

      wanted: Dictation.active && win.focused && !win.outputBlocked

      // What was last shown, held while the shape melts back so the contents fade rather
      // than blink out with the session that ended.
      property string shownPhase: "listening"
      property string shownCommitted: ""
      property string shownTentative: ""

      function latch() {
        if (!Dictation.active)
          return;
        win.shownPhase = Dictation.phase;
        win.shownCommitted = Dictation.committed;
        win.shownTentative = Dictation.tentative;
      }

      onOpening: win.latch()

      Connections {
        target: Dictation

        function onPhaseChanged() {
          win.latch();
        }

        function onCommittedChanged() {
          win.latch();
        }

        function onTentativeChanged() {
          win.latch();
        }
      }

      readonly property bool working: win.shownPhase === "working"
      readonly property bool live: win.shownCommitted !== "" || win.shownTentative !== ""

      openWidth: win.live ? Theme.dictationLiveWidth : Theme.dictationWidth
      openHeight: win.live ? Theme.dictationTextTop + transcriptBox.height + Theme.dictationTextBottom : Theme.dictationHeight
      openRadius: Theme.dictationRadius

      // ---- the row ----
      Item {
        id: row

        width: win.surface.width
        height: Theme.dictationHeight

        // Mic while listening, a spinner while Handy finishes.
        StrokeIcon {
          x: Theme.dictationGlyphLeft
          y: (row.height - size) / 2
          size: Theme.dictationGlyphSize
          strokeWidth: 1.75
          path: IconPaths.microphone
          color: Dictation.ready ? Theme.microphoneMark : Theme.inkTertiary
          opacity: win.working ? 0 : 1
          visible: opacity > 0

          Behavior on opacity {
            Morph {
              duration: Theme.morphContent * 2
            }
          }

          Behavior on color {
            Tint {}
          }
        }

        Shape {
          id: spinner

          x: Theme.dictationGlyphLeft + (Theme.dictationGlyphSize - width) / 2
          y: (row.height - height) / 2
          width: Theme.dictationSpinnerSize
          height: width
          opacity: win.working ? 1 : 0
          visible: opacity > 0
          preferredRendererType: Shape.CurveRenderer

          readonly property real stroke: 2
          readonly property real r: (width - stroke) / 2

          Behavior on opacity {
            Morph {
              duration: Theme.morphContent * 2
            }
          }

          RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            running: spinner.visible && !Theme.reduceMotion
          }

          ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.withAlpha(Theme.inkTertiary, 0.35)
            strokeWidth: spinner.stroke

            PathAngleArc {
              centerX: spinner.width / 2
              centerY: spinner.height / 2
              radiusX: spinner.r
              radiusY: spinner.r
              startAngle: 0
              sweepAngle: 360
            }
          }

          ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.accent
            strokeWidth: spinner.stroke
            capStyle: ShapePath.RoundCap

            PathAngleArc {
              centerX: spinner.width / 2
              centerY: spinner.height / 2
              radiusX: spinner.r
              radiusY: spinner.r
              startAngle: -90
              sweepAngle: 90
            }
          }
        }

        // Level bars, centred on the pill: the lowest bucket in the middle, higher ones
        // outward on both sides. Flat and dim until the mic delivers samples.
        Row {
          id: bars

          x: (row.width - width) / 2
          y: (row.height - height) / 2
          height: Theme.dictationBarMax
          spacing: Theme.dictationBarGap
          opacity: win.working ? 0 : 1
          visible: opacity > 0

          Behavior on opacity {
            Morph {
              duration: Theme.morphContent * 2
            }
          }

          Repeater {
            model: Theme.dictationBuckets * 2 - 1

            Rectangle {
              required property int index

              readonly property real level: Dictation.levels[Math.abs(index - (Theme.dictationBuckets - 1))] || 0

              anchors.verticalCenter: parent.verticalCenter
              width: Theme.dictationBarWidth
              height: Dictation.ready ? Theme.dictationBarMin + Math.pow(Theme.clamp01(level), 0.7) * (Theme.dictationBarMax - Theme.dictationBarMin) : Theme.dictationBarMin
              radius: width / 2
              color: Dictation.ready ? Theme.accent : Theme.inkTertiary

              // Levels land about 30 times a second; this carries them across the frames between.
              Behavior on height {
                enabled: !Theme.reduceMotion

                NumberAnimation {
                  duration: 60
                }
              }
            }
          }
        }

        Text {
          anchors.centerIn: parent
          text: Dictation.workKind === "polishing" ? "Polishing…" : "Transcribing…"
          color: Theme.inkSecondary
          font.family: Theme.uiFont
          font.pixelSize: 12
          font.weight: Theme.weightMedium
          opacity: win.working ? 1 : 0
          visible: opacity > 0

          Behavior on opacity {
            Morph {
              duration: Theme.morphContent * 2
            }
          }
        }

        // The time since the mic came up, as Handy's own overlay counts it.
        Text {
          id: clockText

          property real now: Date.now()

          x: row.width - Theme.dictationTimeRight - width
          y: (row.height - height) / 2
          text: {
            var s = Dictation.readyAt > 0 ? Math.max(0, Math.floor((clockText.now - Dictation.readyAt) / 1000)) : 0;
            return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + s % 60;
          }
          color: Theme.inkSecondary
          font.family: Theme.uiFont
          font.pixelSize: 12
          font.weight: Theme.weightSemi
          font.features: {
            "tnum": 1
          }
          opacity: win.working || !Dictation.ready ? 0 : 1
          visible: opacity > 0

          Behavior on opacity {
            Morph {
              duration: Theme.morphContent * 2
            }
          }

          Timer {
            interval: 250
            repeat: true
            running: win.open && Dictation.phase === "listening"
            triggeredOnStart: true
            onTriggered: clockText.now = Date.now()
          }
        }

        StrokeIcon {
          x: row.width - Theme.dictationCancelRight - size
          y: (row.height - size) / 2
          size: Theme.dictationCancelSize
          strokeWidth: 1.6
          path: IconPaths.x
          color: cancelArea.containsMouse ? Theme.inkPrimary : Theme.inkSecondary

          MouseArea {
            id: cancelArea

            anchors.fill: parent
            anchors.margins: -8
            enabled: win.open && Dictation.active
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Dictation.cancel()
          }
        }
      }

      // ---- the transcript ----
      //
      // Laid out at the open card's width, so its height is settled before the shape grows to
      // it, and centred, so the growing shape uncovers it. Settled words in full ink, the
      // words the model may still rewrite softer.
      Item {
        id: transcriptBox

        readonly property real textWidth: Theme.dictationLiveWidth - 2 * Theme.dictationTextInset

        x: (win.surface.width - Theme.dictationLiveWidth) / 2 + Theme.dictationTextInset
        y: Theme.dictationTextTop
        width: textWidth
        height: Math.min(transcript.implicitHeight, Theme.dictationTextLines * Theme.dictationTextLineHeight)
        clip: true
        opacity: win.live ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          Morph {
            duration: Theme.morphContent * 2
          }
        }

        function escaped(s) {
          return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        }

        // Pinned to the bottom, so once it overflows the oldest lines scroll off the top.
        Text {
          id: transcript

          y: transcriptBox.height - height
          width: transcriptBox.textWidth
          wrapMode: Text.Wrap
          textFormat: Text.StyledText
          lineHeightMode: Text.FixedHeight
          lineHeight: Theme.dictationTextLineHeight
          text: transcriptBox.escaped(win.shownCommitted) + (win.shownCommitted !== "" && win.shownTentative !== "" ? " " : "") + "<font color=\"" + Theme.inkSecondary + "\">" + transcriptBox.escaped(win.shownTentative) + "</font>"
          color: Theme.inkPrimary
          font.family: Theme.uiFont
          font.pixelSize: Theme.dictationTextSize
        }

        // Older lines fade out under the top edge rather than being cut.
        Rectangle {
          width: parent.width
          height: Theme.dictationTextLineHeight
          visible: transcript.implicitHeight > transcriptBox.height + 1
          gradient: Gradient {
            GradientStop {
              position: 0
              color: Theme.surface
            }

            GradientStop {
              position: 1
              color: Theme.withAlpha(Theme.surface, 0)
            }
          }
        }
      }
    }
  }
}
