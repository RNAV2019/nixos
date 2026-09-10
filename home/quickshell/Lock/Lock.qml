import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Hyprland
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.Commons
import qs.Services

Scope {
  id: root

  property string password: ""
  property string status: ""
  property bool statusIsError: false
  property bool busy: false
  property int attempts: 0
  readonly property bool secure: lockContext.secure

  // quickshell forks its PAM worker without exec (quickshell-mirror/quickshell
  // #964). The child of a threaded process can inherit a mutex held by a
  // thread that no longer exists in it and deadlock in futex before PAM
  // produces anything: no prompt, no completion, no error, while submit() has
  // already disabled the input. quickshell works once or twice and then, on
  // the wrong roll, freezes the screen for good.
  //
  // The child is still killable, so the watchdog aborts the wedged
  // conversation, forks a fresh one, and resubmits the held password when the
  // new prompt arrives. Each kick re-rolls the fork race; three losses in a
  // row give up visibly and re-enable the input so the user can retry by hand.
  property string pendingPassword: ""
  property int pamKicks: 0

  // The ground is the blurred wallpaper and the veil over it, which move
  // together. The two content tiers ride their own clocks either side of it.
  property real ground: 0
  property real clockAlpha: 0
  property real loginAlpha: 0

  readonly property string userName: {
    var name = Quickshell.env("USER") || Quickshell.env("LOGNAME") || "";
    if (name.length > 0)
      return name;
    // Neither is set under some session managers; the home directory is named
    // after the account either way.
    var home = Quickshell.env("HOME") || "";
    return home.substring(home.lastIndexOf("/") + 1);
  }
  readonly property string userInitial: userName.length > 0 ? userName.charAt(0).toUpperCase() : ""

  function lock() {
    if (lockContext.locked)
      return;
    root.password = "";
    root.status = "";
    root.statusIsError = false;
    root.attempts = 0;
    root.ground = 0;
    root.clockAlpha = 0;
    root.loginAlpha = 0;
    revealOut.stop();
    revealIn.stop();
    lockContext.locked = true;
    passwordPam.start();
    // Covers the boot lock too: a worker wedged before its prompt never asks
    // for a password, so nothing else would notice.
    root.pamKicks = 0;
    root.pendingPassword = "";
    pamWatchdog.restart();
  }

  function unlock() {
    pamWatchdog.stop();
    root.pendingPassword = "";
    passwordPam.abort();
    root.password = "";
    root.status = "";
    root.statusIsError = false;
    root.busy = false;
    // The bar comes back on the first frame of the fade, not after it. The
    // surface is see-through from here, so the pill spends the whole ramp
    // emerging through the lifting veil.
    Bus.sessionReady = true;
    revealIn.stop();
    revealOut.restart();
  }

  ParallelAnimation {
    id: revealIn

    NumberAnimation {
      target: root
      property: "ground"
      to: 1
      duration: Theme.lockIn
      easing.type: Easing.OutQuad
    }

    SequentialAnimation {
      PauseAnimation {
        duration: Theme.lockInClock
      }
      NumberAnimation {
        target: root
        property: "clockAlpha"
        to: 1
        duration: Theme.lockInContent
        easing.type: Easing.OutCubic
      }
    }

    SequentialAnimation {
      PauseAnimation {
        duration: Theme.lockInLogin
      }
      NumberAnimation {
        target: root
        property: "loginAlpha"
        to: 1
        duration: Theme.lockInContent
        easing.type: Easing.OutCubic
      }
    }
  }

  SequentialAnimation {
    id: revealOut

    ParallelAnimation {
      NumberAnimation {
        target: root
        property: "ground"
        to: 0
        duration: Theme.lockOut
        easing.type: Easing.OutCubic
      }

      NumberAnimation {
        target: root
        property: "loginAlpha"
        to: 0
        duration: Theme.lockOutContent
        easing.type: Easing.OutCubic
      }

      SequentialAnimation {
        PauseAnimation {
          duration: Theme.lockOutClock
        }
        NumberAnimation {
          target: root
          property: "clockAlpha"
          to: 0
          duration: Theme.lockOutContent
          easing.type: Easing.OutCubic
        }
      }
    }

    // Hold the session locked until the last fade frame has been presented.
    PauseAnimation {
      duration: 50
    }

    ScriptAction {
      script: lockContext.locked = false
    }
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
    root.pamKicks = 0;
    pamWatchdog.restart();
    // A give-up abort or a silent start failure leaves no conversation to
    // answer this password; fork one.
    if (!passwordPam.active)
      passwordPam.start();
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

    onPamMessage: {
      // The watchdog's replacement conversation races its own prompt; send
      // the held password once the new one asks for it.
      if (root.pendingPassword.length > 0 && passwordPam.responseRequired) {
        passwordPam.respond(root.pendingPassword);
        root.pendingPassword = "";
      }
    }

    onCompleted: function (result) {
      pamWatchdog.stop();
      root.pendingPassword = "";
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
      pamWatchdog.stop();
      root.pendingPassword = "";
      root.busy = false;
      root.statusIsError = true;
      root.status = "Authentication unavailable";
    }
  }

  Timer {
    id: pamWatchdog

    interval: 4000

    onTriggered: {
      if (root.pamKicks >= 3) {
        // Three lost fork rolls. Kill the last worker, surface the failure,
        // and leave the input to the user; the next submit forks fresh.
        passwordPam.abort();
        root.pendingPassword = "";
        root.busy = false;
        root.statusIsError = true;
        root.status = "Authentication unavailable";
        return;
      }
      root.pamKicks += 1;
      passwordPam.abort();
      passwordPam.start();
      // Only a submitted password rides the replacement conversation; a kick
      // that lands while the user is still typing would otherwise submit the
      // half-typed field the moment the fresh prompt arrives.
      root.pendingPassword = root.busy ? root.password : "";
      restart();
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

      // The surface is see-through, so what fades in is the lock over the live
      // desktop rather than a copy of the wallpaper with the bar cut out of
      // it. This is the whole reason the island pill can fade rather than
      // snap: it is never hidden, it is covered.
      color: "transparent"

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.BlankCursor
        acceptedButtons: Qt.NoButton
      }

      // Reveal once the compositor has created the surface. There is one of
      // these per screen and they share the one set of properties, so a second
      // screen joins the ramp already in progress rather than restarting it.
      Component.onCompleted: {
        if (!revealIn.running && root.ground < 1)
          revealIn.restart();
      }

      // The blur and the veil composite as one texture before they fade, so
      // the ramp cross-fades a finished frosted screen over the desktop rather
      // than fading each layer onto the other's half-drawn output.
      Item {
        id: ground

        anchors.fill: parent
        opacity: root.ground
        layer.enabled: true

        // Overscan and clip MultiEffect's transparent edge samples.
        Item {
          anchors.fill: parent
          clip: true

          Image {
            id: blurSource

            anchors.fill: parent
            anchors.margins: -Theme.lockBlurMax * 2
            source: Wallpapers.url
            fillMode: Image.PreserveAspectCrop
            cache: false
            asynchronous: false
            // Expose this layer as MultiEffect's texture source.
            layer.enabled: true
          }

          MultiEffect {
            anchors.fill: blurSource
            source: blurSource
            visible: blurSource.status === Image.Ready
            blurEnabled: true
            // The radius holds still and the finished layer is what fades. A
            // full-screen gaussian re-run every frame does not fit the 60 Hz
            // budget, and across 350 ms the two are not told apart.
            blur: 1
            blurMax: Theme.lockBlurMax
            blurMultiplier: 1
            brightness: -0.02
            contrast: -0.1084
            saturation: 0.1696
          }
        }

        Rectangle {
          anchors.fill: parent
          color: Theme.base
          opacity: Theme.lockVeilOpacity
        }
      }

      // Board 13's layout is in board units; scale the canvas into Qt's.
      Item {
        id: canvas

        // Qt rounds devicePixelRatio, so use Hyprland's fractional scale.
        readonly property real outputScale: {
          var monitor = surface.screen ? Hyprland.monitorFor(surface.screen) : null;
          if (monitor && monitor.scale > 0)
            return monitor.scale;
          return surface.screen ? surface.screen.devicePixelRatio : 1;
        }

        // The board draws 1080 units tall, so one unit is this many device
        // pixels and the whole block keeps its proportions on any panel.
        readonly property real ui: height / 1080

        function u(v) {
          return Math.round(v * ui);
        }

        width: surface.width * outputScale
        height: surface.height * outputScale
        transformOrigin: Item.TopLeft
        scale: 1 / outputScale

        Text {
          id: date

          anchors.horizontalCenter: parent.horizontalCenter
          y: canvas.u(Theme.lockDateTop)
          opacity: root.clockAlpha

          text: Qt.formatDate(clock.date, "dddd, d MMMM")
          color: Theme.subtle
          font.family: Theme.uiFont
          font.weight: Theme.weightRegular
          font.pixelSize: canvas.u(Theme.lockDateSize)
          // Avoid RGB subpixel fringes from native text rendering.
          renderType: Text.QtRendering
        }

        Text {
          id: time

          anchors.horizontalCenter: parent.horizontalCenter
          y: canvas.u(Theme.lockClockTop)
          opacity: root.clockAlpha

          text: Qt.formatDateTime(clock.date, "HH:mm")
          color: Theme.text
          font.family: Theme.displayFont
          font.weight: Theme.weightSemi
          font.pixelSize: canvas.u(Theme.lockClockSize)
          renderType: Text.QtRendering
        }

        Item {
          id: login

          anchors.horizontalCenter: parent.horizontalCenter
          y: canvas.u(Theme.lockAvatarTop)
          width: canvas.u(Theme.lockFieldWidth)
          height: canvas.u(Theme.lockFieldTop + Theme.lockFieldHeight - Theme.lockAvatarTop)
          opacity: root.loginAlpha

          Rectangle {
            id: avatar

            anchors.horizontalCenter: parent.horizontalCenter
            width: canvas.u(Theme.lockAvatarSize)
            height: width
            radius: width / 2

            color: Theme.withAlpha(Theme.surface, Theme.lockAvatarFill)
            border.width: Math.max(1, Theme.lockStrokeWidth * canvas.ui)
            border.color: Theme.withAlpha(Theme.iris, Theme.lockAvatarStroke)

            Text {
              anchors.centerIn: parent
              text: root.userInitial
              color: Theme.iris
              font.family: Theme.uiFont
              font.weight: Theme.weightSemi
              font.pixelSize: canvas.u(Theme.lockAvatarInitial)
              renderType: Text.QtRendering
            }
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: canvas.u(Theme.lockUserTop - Theme.lockAvatarTop)

            text: root.userName
            color: Theme.text
            font.family: Theme.uiFont
            font.weight: Theme.weightMedium
            font.pixelSize: canvas.u(Theme.lockUserSize)
            renderType: Text.QtRendering
          }

          Rectangle {
            id: field

            anchors.horizontalCenter: parent.horizontalCenter
            y: canvas.u(Theme.lockFieldTop - Theme.lockAvatarTop)
            width: canvas.u(Theme.lockFieldWidth)
            height: canvas.u(Theme.lockFieldHeight)
            radius: canvas.u(Theme.lockFieldRadius)

            color: Theme.withAlpha(Theme.surface, Theme.lockFieldFill)
            border.width: Math.max(1, Theme.lockStrokeWidth * canvas.ui)
            // The board's border is already the accent, so busy brightens it
            // rather than recolouring it, and only a refusal changes the hue.
            border.color: {
              if (failFlash.running)
                return Theme.love;
              if (root.busy)
                return Theme.iris;
              return Theme.withAlpha(Theme.iris, Theme.lockFieldStroke);
            }

            Behavior on border.color {
              ColorAnimation {
                duration: Theme.animFast
              }
            }

            TextInput {
              id: input

              anchors.fill: parent

              focus: true
              enabled: !root.busy
              // The dots are drawn as fixed geometry beside this, so the field
              // itself renders nothing.
              echoMode: TextInput.NoEcho
              color: "transparent"
              cursorVisible: false
              cursorDelegate: Item {}

              text: root.password
              onTextChanged: root.password = text
              onAccepted: root.submit()
            }

            // The placeholder, or whatever PAM last said. The field keeps the
            // board's width either way: an error set in the placeholder's type
            // fits the room the placeholder had.
            Text {
              anchors.left: parent.left
              anchors.leftMargin: canvas.u(Theme.lockTextInset)
              anchors.right: parent.right
              anchors.rightMargin: canvas.u(Theme.lockTextInset)
              anchors.verticalCenter: parent.verticalCenter
              visible: input.text.length === 0

              text: root.statusIsError ? root.status : "Enter password"
              color: root.statusIsError ? Theme.love : Theme.muted
              elide: Text.ElideRight
              font.family: Theme.uiFont
              font.weight: Theme.weightRegular
              font.pixelSize: canvas.u(Theme.lockFieldTextSize)
              font.italic: root.statusIsError
              renderType: Text.QtRendering
            }

            // Dots then caret, left-aligned, so the caret is always at the
            // insertion point and leads the placeholder while the field is
            // empty - which is where the board draws it.
            //
            // Each slot carries its own trailing gap and the row has no
            // spacing of its own, because a row that spaced its children would
            // hold 63 gaps open for the 63 dots that are not there.
            Row {
              anchors.left: parent.left
              anchors.leftMargin: canvas.u(Theme.lockCaretInset)
              anchors.verticalCenter: parent.verticalCenter
              spacing: 0

              Repeater {
                model: 64

                Item {
                  id: slot

                  readonly property bool filled: index < input.text.length

                  width: filled ? canvas.u(Theme.lockDotSize + Theme.lockDotGap) : 0
                  // Every child of the row is the caret's height, so the row
                  // lines them up without anchors, which a positioner ignores.
                  height: canvas.u(Theme.lockCaretHeight)

                  Behavior on width {
                    NumberAnimation {
                      duration: Theme.animFast
                      easing.type: Easing.OutQuad
                    }
                  }

                  Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: canvas.u(Theme.lockDotSize)
                    height: width
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

              Rectangle {
                id: caret

                width: Math.max(1, canvas.u(Theme.lockCaretWidth))
                height: canvas.u(Theme.lockCaretHeight)
                radius: width / 2
                color: Theme.iris
                // Hide rather than stop the blink: a stopped animation leaves
                // the opacity wherever the last frame put it.
                visible: !root.busy

                SequentialAnimation on opacity {
                  loops: Animation.Infinite
                  running: true
                  PropertyAction {
                    value: 1
                  }
                  PauseAnimation {
                    duration: 530
                  }
                  PropertyAction {
                    value: 0
                  }
                  PauseAnimation {
                    duration: 530
                  }
                }
              }
            }
          }
        }

        // Kept from the surface this replaces; the board does not draw it.
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: canvas.u(Theme.lockNowPlayingBottom)
          opacity: root.loginAlpha

          color: Theme.subtle
          font.family: Theme.uiFont
          font.weight: Theme.weightMedium
          font.pixelSize: canvas.u(Theme.lockNowPlayingSize)
          renderType: Text.QtRendering
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
      }

      SystemClock {
        id: clock
        precision: SystemClock.Minutes
      }
    }
  }
}
