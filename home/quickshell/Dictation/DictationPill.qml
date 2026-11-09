import QtQuick
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

      openWidth: win.live ? Theme.dictationLiveWidth : Theme.islandPillWidth
      openHeight: win.live ? Theme.dictationTextTop + transcriptBox.height + Theme.dictationTextBottom : Theme.islandPillHeight
      openRadius: win.live ? Theme.dictationRadius : Theme.islandPillRadius

      // ---- the row ----
      //
      // Two rows of the island pill, crossing over when Handy hands the mic over to its model:
      // the mic and level bars, and the spinner with what is being done. The row is as wide as
      // the open card, so the × stays at its corner as the card grows to it.
      Item {
        id: row

        width: parent.width
        height: Theme.islandPillHeight

        // The time since the mic came up, as Handy's own overlay counts it.
        property real now: Date.now()

        readonly property string elapsed: {
          var s = Dictation.readyAt > 0 ? Math.max(0, Math.floor((row.now - Dictation.readyAt) / 1000)) : 0;
          return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + s % 60;
        }

        Timer {
          interval: 250
          repeat: true
          running: win.open && Dictation.phase === "listening"
          triggeredOnStart: true
          onTriggered: row.now = Date.now()
        }

        PillState {
          anchors.fill: parent
          shown: !win.working
          open: win.open && Dictation.active

          IslandPill {
            anchors.fill: parent
            layout: "glyphWaveformReadingAction"
            reading: Dictation.ready ? row.elapsed : ""
            readingColor: Theme.inkSecondary
            tabularReading: true
            onCancelled: Dictation.cancel()

            StrokeIcon {
              anchors.centerIn: parent
              size: Theme.islandPillGlyphSize
              strokeWidth: 1.75
              path: IconPaths.microphone
              color: Dictation.ready ? Theme.microphoneMark : Theme.inkTertiary

              Behavior on color {
                Tint {}
              }
            }

            // Level bars: the lowest bucket in the middle, higher ones outward on both sides.
            // Flat dots, dim, until the mic delivers samples.
            waveform: Row {
              anchors.fill: parent
              spacing: Theme.dictationBarGap

              Repeater {
                model: Theme.dictationBuckets * 2 - 1

                Rectangle {
                  required property int index

                  readonly property real level: Dictation.levels[Math.abs(index - (Theme.dictationBuckets - 1))] || 0

                  anchors.verticalCenter: parent.verticalCenter
                  width: Theme.dictationBarWidth
                  height: barSpring.value
                  radius: width / 2
                  color: Dictation.ready ? Theme.accent : Theme.inkTertiary

                  Behavior on color {
                    Tint {}
                  }

                  // Levels land about 30 times a second; the spring carries them across the
                  // frames between and retargets on each, keeping its speed.
                  MorphSpring {
                    id: barSpring

                    target: Dictation.ready ? Theme.dictationBarMin + Math.pow(Theme.clamp01(level), 0.7) * (Theme.islandPillWaveformHeight - Theme.dictationBarMin) : Theme.dictationBarMin
                    omega: Theme.levelOmega
                    epsilon: 0.1
                    label: "dict.bar" + index

                    // A bar keeps its speed across a new level only as far as it can without
                    // passing it: one already past the new target stops, and one heading for it
                    // at more than omega x distance is held to that (Motion.seedVelocity's clamp).
                    onTargetChanged: {
                      var x = value - target;
                      if (x * velocity > 0)
                        velocity = 0;
                      else if (Math.abs(velocity) > omega * Math.abs(x))
                        velocity = -omega * x;
                    }
                  }
                }
              }
            }
          }
        }

        PillState {
          anchors.fill: parent
          shown: win.working
          open: win.open && Dictation.active

          IslandPill {
            anchors.fill: parent
            layout: "glyphLabelAction"
            label: Dictation.workKind === "polishing" ? "Polishing…" : "Transcribing…"
            onCancelled: Dictation.cancel()

            Spinner {
              anchors.centerIn: parent
            }
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

        x: (parent.width - Theme.dictationLiveWidth) / 2 + Theme.dictationTextInset
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

          // A line more than the box holds moves the text up by one; eased, so the eye follows
          // the words rather than finding them a line higher. Only while the text is up, so a
          // new dictation starts in place.
          Behavior on y {
            enabled: win.live && transcriptBox.opacity > 0

            NumberAnimation {
              duration: Theme.duration(Theme.dictationLineSlide)
              easing.type: Easing.OutCubic
            }
          }
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
