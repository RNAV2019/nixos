import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Hyprland
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.Commons

Scope {
  id: root

  property string password: ""
  property string status: ""
  property bool statusIsError: false
  property bool busy: false
  property int attempts: 0
  readonly property bool secure: lockContext.secure

  // Overscan by twice the blur radius to avoid transparent edge samples.
  readonly property int blurMax: 48
  readonly property int blurPad: blurMax * 2

  property real reveal: 0

  readonly property int revealDuration: 450

  Behavior on reveal {
    NumberAnimation {
      duration: root.revealDuration
      easing.type: Easing.InOutCubic
    }
  }

  function lock() {
    if (lockContext.locked)
      return;
    root.password = "";
    root.status = "";
    root.statusIsError = false;
    root.attempts = 0;
    root.reveal = 0;
    lockContext.locked = true;
    passwordPam.start();
  }

  function unlock() {
    passwordPam.abort();
    root.password = "";
    root.status = "";
    root.statusIsError = false;
    root.busy = false;
    Bus.sessionReady = true;
    // Keep the session locked until its surface finishes fading.
    root.reveal = 0;
    revealOut.restart();
  }

  // Leave time for the final fade frame to be presented before releasing.
  Timer {
    id: revealOut
    interval: root.revealDuration + 50
    onTriggered: lockContext.locked = false
  }

  function fail(reason) {
    root.password = "";
    root.attempts += 1;
    root.statusIsError = true;
    root.status = reason + " (" + root.attempts + ")";
    failTimeout.restart();
    failFlash.restart();
  }

  function submit() {
    if (root.busy || root.password.length === 0)
      return;
    root.busy = true;
    root.status = "";
    root.statusIsError = false;
    // start() leaves PAM waiting for this password response.
    if (passwordPam.responseRequired)
      passwordPam.respond(root.password);
  }

  Connections {
    target: Bus

    function onLockRequested() {
      root.lock();
    }
  }

  // Lock until this compositor instance completes its first secure lock.
  Process {
    id: markerCheck

    running: true
    command: ["sh", "-c", "test -e \"$XDG_RUNTIME_DIR/quickshell-secured-$HYPRLAND_INSTANCE_SIGNATURE\""]

    onExited: function (exitCode, exitStatus) {
      if (exitCode === 0) {
        Bus.sessionReady = true;
        return;
      }
      root.lock();
    }
  }

  Process {
    id: markerWrite
    command: ["sh", "-c", ": > \"$XDG_RUNTIME_DIR/quickshell-secured-$HYPRLAND_INSTANCE_SIGNATURE\""]
  }

  Process {
    id: submapReset
    command: ["hyprctl", "dispatch", "hl.dsp.submap(\"reset\")"]
  }

  PamContext {
    id: passwordPam

    configDirectory: "/etc/pam.d"
    config: "quickshell-password"

    onCompleted: function (result) {
      root.busy = false;
      if (result === PamResult.Success) {
        root.unlock();
        return;
      }
      root.fail(result === PamResult.MaxTries ? "Too many attempts" : "Authentication failed");
      // Each failed attempt ends the PAM conversation.
      passwordPam.start();
    }

    onError: function (err) {
      root.busy = false;
      root.statusIsError = true;
      root.status = "Authentication unavailable";
    }
  }

  Timer {
    id: failTimeout
    interval: 2000
    onTriggered: {
      root.status = "";
      root.statusIsError = false;
    }
  }

  Timer {
    id: failFlash
    interval: 500
  }

  WlSessionLock {
    id: lockContext

    onSecureChanged: {
      if (secure) {
        markerWrite.running = true;
        submapReset.running = true;
      }
    }

    WlSessionLockSurface {
      id: surface

      color: Theme.base

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.BlankCursor
        acceptedButtons: Qt.NoButton
      }

      // Keep an unblurred wallpaper beneath the lock for the cross-fade.
      Image {
        id: wallpaper
        anchors.fill: parent
        source: "file://" + Quickshell.env("HOME") + "/.local/share/wallpaper/current"
        fillMode: Image.PreserveAspectCrop
        cache: false
        asynchronous: false
      }

      // Fade the composited layer instead of the full-screen blur.
      Item {
        id: content

        anchors.fill: parent
        opacity: root.reveal
        layer.enabled: true

        // Reveal only after the compositor creates the lock surface.
        Component.onCompleted: root.reveal = 1

        // Overscan and clip MultiEffect's transparent edge samples.
        Item {
          anchors.fill: parent
          clip: true

          Image {
            id: blurSource

            anchors.fill: parent
            anchors.margins: -root.blurPad
            source: wallpaper.source
            fillMode: Image.PreserveAspectCrop
            cache: false
            asynchronous: false
            // Expose this layer as MultiEffect's texture source.
            layer.enabled: true
          }

          // Use the black overlay for dimming; effect brightness is additive.
          MultiEffect {
            anchors.fill: blurSource
            source: blurSource
            visible: blurSource.status === Image.Ready
            blurEnabled: true
            // Animating this full-screen blur exceeds the 60 Hz frame budget.
            blur: 1
            blurMax: root.blurMax
            blurMultiplier: 1
            brightness: -0.02
            contrast: -0.1084
            saturation: 0.1696
          }
        }

        Rectangle {
          anchors.fill: parent
          color: "black"
          opacity: 1 - 0.8172
        }

        // Layout values are device pixels; scale the canvas into Qt coordinates.
        Item {
          id: canvas

          // Qt rounds devicePixelRatio, so use Hyprland's fractional scale.
          readonly property real outputScale: {
            var monitor = surface.screen ? Hyprland.monitorFor(surface.screen) : null;
            if (monitor && monitor.scale > 0)
              return monitor.scale;
            return surface.screen ? surface.screen.devicePixelRatio : 1;
          }

          // Layout constants were authored against a 2880x1800 panel; scale them
          // by the output height so smaller panels keep the same proportions.
          readonly property real ui: height / 1800

          readonly property int dotSize: Math.round(20 * ui)
          readonly property int dotGap: Math.round(dotSize * 0.3)

          width: surface.width * outputScale
          height: surface.height * outputScale
          transformOrigin: Item.TopLeft
          scale: 1 / outputScale

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -250 * canvas.ui
            text: Qt.formatDate(clock.date, "dddd, MMMM, dd")
            color: Theme.text
            font.family: Theme.displayFont
            renderType: Text.QtRendering
            font.bold: true
            font.pixelSize: Math.round(34 * canvas.ui)
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -135 * canvas.ui
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Theme.text
            font.family: Theme.displayFont
            renderType: Text.QtRendering
            font.bold: true
            font.pixelSize: Math.round(204 * canvas.ui)
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 50 * canvas.ui
            color: Theme.subtle
            font.family: Theme.displayFont
            renderType: Text.QtRendering
            font.bold: true
            font.pixelSize: Math.round(24 * canvas.ui)
            text: {
              for (var i = 0; i < Mpris.players.values.length; i++) {
                var p = Mpris.players.values[i];
                if (p.playbackState === MprisPlaybackState.Stopped)
                  continue;
                var title = p.trackTitle || "";
                var artist = p.trackArtist || "";
                if (title.length === 0)
                  continue;
                return artist.length > 0 ? title + " - " + artist : title;
              }
              return "";
            }
          }

          // Measure errors separately to avoid a field-width binding loop.
          TextMetrics {
            id: statusMetrics
            font: statusText.font
            text: root.statusIsError ? root.status : ""
          }

          Rectangle {
            id: field

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 80 * canvas.ui

            // Preserve the field padding as PAM errors widen it.
            width: Math.max(417 * canvas.ui, statusMetrics.width + 99 * canvas.ui)
            height: Math.round(104 * canvas.ui)
            radius: height / 2

            Behavior on width {
              NumberAnimation {
                duration: Theme.animFast
              }
            }

            color: Theme.withAlpha(Theme.base, 0.8)
            border.width: 2
            border.color: root.busy ? Theme.iris : (failFlash.running ? Theme.lockFail : Theme.love)

            Behavior on border.color {
              ColorAnimation {
                duration: Theme.animFast
              }
            }

            TextInput {
              id: input

              anchors.fill: parent
              anchors.margins: Math.round(20 * canvas.ui)
              verticalAlignment: TextInput.AlignVCenter
              horizontalAlignment: TextInput.AlignHCenter

              focus: true
              enabled: !root.busy
              // Render fixed-geometry password dots separately.
              echoMode: TextInput.NoEcho
              // TextInput restores its caret on focus unless the delegate is empty.
              cursorVisible: false
              cursorDelegate: Item {}
              color: Theme.text
              // Avoid RGB subpixel fringes from native text rendering.
              renderType: Text.QtRendering
              font.family: Theme.displayFont
              font.bold: true
              font.pixelSize: Math.round(34 * canvas.ui)

              text: root.password
              onTextChanged: root.password = text
              onAccepted: root.submit()

              Text {
                id: statusText

                anchors.centerIn: parent
                visible: input.text.length === 0
                text: root.statusIsError ? root.status : "Enter Password  󰈷 "
                color: root.statusIsError ? Theme.lockFail : Theme.text
                font.family: input.font.family
                renderType: Text.QtRendering
                font.bold: input.font.bold
                font.pixelSize: input.font.pixelSize
                font.italic: root.statusIsError
              }
            }

            // Fixed slots rebuild and animate only the changed dot.
            Row {
              id: dots

              anchors.verticalCenter: parent.verticalCenter
              anchors.horizontalCenter: parent.horizontalCenter
              // Center the dots despite each slot's trailing gap.
              anchors.horizontalCenterOffset: canvas.dotGap / 2
              spacing: 0

              Repeater {
                model: 64

                Item {
                  id: slot

                  readonly property bool filled: index < input.text.length

                  width: filled ? canvas.dotSize + canvas.dotGap : 0
                  height: canvas.dotSize

                  Behavior on width {
                    NumberAnimation {
                      duration: Theme.animFast
                      easing.type: Easing.OutQuad
                    }
                  }

                  Rectangle {
                    width: canvas.dotSize
                    height: canvas.dotSize
                    radius: width / 2
                    color: Theme.text

                    scale: slot.filled ? 1 : 0
                    opacity: slot.filled ? 1 : 0

                    Behavior on scale {
                      NumberAnimation {
                        duration: Theme.animFast
                        easing.type: slot.filled ? Easing.OutBack : Easing.InQuad
                      }
                    }

                    Behavior on opacity {
                      NumberAnimation {
                        duration: Theme.animFast
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      SystemClock {
        id: clock
        precision: SystemClock.Minutes
      }
    }
  }
}
