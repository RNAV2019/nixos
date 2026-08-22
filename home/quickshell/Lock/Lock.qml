import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Hyprland
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.Commons

// Fingerprint and password are two separate PAM conversations running side by
// side so pam_fprintd cannot block password entry.
Scope {
  id: root

  property string password: ""
  property string status: ""
  property bool statusIsError: false
  property bool busy: false
  property int attempts: 0
  readonly property bool secure: lockContext.secure

  readonly property int dotSize: 20
  readonly property int dotGap: dotSize * 0.3

  // Overscan by twice the blur radius to avoid transparent edge samples.
  readonly property int blurMax: 48
  readonly property int blurPad: blurMax * 2

  // The lock content is composited once and faded as a single texture.
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
    fingerprintPam.start();
  }

  function unlock() {
    passwordPam.abort();
    fingerprintPam.abort();
    root.password = "";
    root.status = "";
    root.statusIsError = false;
    root.busy = false;
    Bus.sessionReady = true;
    // The surface has to stay up while it fades, so the session lock is only
    // actually released once the ramp has finished.
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
    // The context is waiting on the password prompt it raised on start.
    if (passwordPam.responseRequired)
      passwordPam.respond(root.password);
  }

  Connections {
    target: Bus

    function onLockRequested() {
      root.lock();
    }
  }

  // Lock until this compositor instance has completed its first secure lock.
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
    command: ["hyprctl", "dispatch", "submap", "reset"]
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
      // The conversation ends with the attempt, so start a fresh one.
      passwordPam.start();
    }

    onError: function (err) {
      root.busy = false;
      root.statusIsError = true;
      root.status = "Authentication unavailable";
    }
  }

  PamContext {
    id: fingerprintPam

    configDirectory: "/etc/pam.d"
    config: "quickshell-fingerprint"

    onCompleted: function (result) {
      if (result === PamResult.Success) {
        root.unlock();
        return;
      }
      // pam_fprintd gives up after a few bad reads. Restart it so the reader
      // keeps working for as long as the screen is locked.
      fingerprintRetry.restart();
    }

    // Ignore informational prompts and idle timeouts from pam_fprintd.
    onPamMessage: {
      if (fingerprintPam.messageIsError)
        root.fail(fingerprintPam.message);
    }

    onError: function (err) {
      fingerprintRetry.restart();
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

  Timer {
    id: fingerprintRetry
    interval: 1000
    onTriggered: {
      if (lockContext.locked)
        fingerprintPam.start();
    }
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

      // Keep a sharp copy beneath the lock for the cross-fade.
      Image {
        id: wallpaper
        anchors.fill: parent
        source: "file://" + Quickshell.env("HOME") + "/.local/share/wallpaper/current"
        fillMode: Image.PreserveAspectCrop
        cache: false
        asynchronous: false
      }

      // Composite the finished lock once instead of animating an expensive blur.
      Item {
        id: content

        anchors.fill: parent
        opacity: root.reveal
        layer.enabled: true

        // Begin only after the compositor creates the lock surface.
        Component.onCompleted: root.reveal = 1

        // MultiEffect samples transparent pixels outside its source. Overscan and
        // clipping prevent an unblurred frame around the screen.
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
            // MultiEffect consumes this layer instead of drawing a second image.
            layer.enabled: true
          }

          // Brightness is multiplied by the black overlay below because
          // MultiEffect's brightness control is additive.
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

          width: surface.width * outputScale
          height: surface.height * outputScale
          transformOrigin: Item.TopLeft
          scale: 1 / outputScale

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -250
            text: Qt.formatDate(clock.date, "dddd, MMMM, dd")
            color: Theme.text
            font.family: Theme.displayFont
            renderType: Text.QtRendering
            font.bold: true
            font.pixelSize: 34
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -135
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Theme.text
            font.family: Theme.displayFont
            renderType: Text.QtRendering
            font.bold: true
            font.pixelSize: 204
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 50
            color: Theme.subtle
            font.family: Theme.displayFont
            renderType: Text.QtRendering
            font.bold: true
            font.pixelSize: 24
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

          // Avoid a field-width binding loop when status text expands it.
          TextMetrics {
            id: statusMetrics
            font: statusText.font
            text: root.statusIsError ? root.status : ""
          }

          Rectangle {
            id: field

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 80

            // Grow to fit long PAM errors while preserving the measured padding.
            width: Math.max(417, statusMetrics.width + 99)
            height: 104
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
              anchors.margins: 20
              verticalAlignment: TextInput.AlignVCenter
              horizontalAlignment: TextInput.AlignHCenter

              focus: true
              enabled: !root.busy
              // Password dots are drawn below with fixed geometry.
              echoMode: TextInput.NoEcho
              // TextInput restores its caret on focus unless the delegate is empty.
              cursorVisible: false
              cursorDelegate: Item {}
              color: Theme.text
              // Avoid RGB subpixel fringes from native text rendering.
              renderType: Text.QtRendering
              font.family: Theme.displayFont
              font.bold: true
              font.pixelSize: 34

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

            // Fixed slots avoid rebuilding every dot when the password length
            // changes, allowing only the new or removed dot to animate.
            Row {
              id: dots

              anchors.verticalCenter: parent.verticalCenter
              anchors.horizontalCenter: parent.horizontalCenter
              // Compensate for the trailing gap included by each slot.
              anchors.horizontalCenterOffset: root.dotGap / 2
              spacing: 0

              Repeater {
                model: 64

                Item {
                  id: slot

                  readonly property bool filled: index < input.text.length

                  width: filled ? root.dotSize + root.dotGap : 0
                  height: root.dotSize

                  Behavior on width {
                    NumberAnimation {
                      duration: Theme.animFast
                      easing.type: Easing.OutQuad
                    }
                  }

                  Rectangle {
                    width: root.dotSize
                    height: root.dotSize
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
        precision: SystemClock.Seconds
      }
    }
  }
}
