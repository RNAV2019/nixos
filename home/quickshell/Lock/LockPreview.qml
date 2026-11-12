import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Services

// The lock screen on a rehearsal stage: same LockView and LockReveal, no session lock, driven
// over IPC (`qs ipc call lockpreview preview|password|busy|refuse|fault|unlock|background|time`).
Scope {
  id: root

  property bool active: false
  property string password: ""
  property bool busy: false
  property int refusals: 0
  property int faults: 0
  // A capture to stand on, as the real lock has (a prefix, see Lock.qml snapshotFile); empty
  // stands on the wallpaper, as the boot lock does.
  property string background: ""
  // A time to show instead of the clock's ("HH:mm"); changing it rolls the minute over as the
  // clock does. Empty follows the clock.
  property string time: ""

  LockReveal {
    id: reveal
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win

      required property var modelData

      screen: modelData
      visible: root.active
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "quickshell-lockpreview"
      WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      LockView {
        anchors.fill: parent
        outputScreen: win.modelData
        captured: root.background.length > 0
        backgroundSource: captured ? "file://" + root.background + "-" + win.modelData.name + ".png" : Wallpapers.url
        timeOverride: root.time
        password: root.password
        busy: root.busy
        refusals: root.refusals
        faults: root.faults
        ground: reveal.ground
        flight: reveal.flight
        swell: reveal.swell
        wobble: reveal.wobble
        rise: reveal.rise
        away: reveal.widthAway
        leaving: reveal.leaving
        flying: reveal.flying
        snapping: reveal.snapping
        armed: reveal.armed

        onPresented: reveal.presented()
        onPasswordEdited: function (text) {
          root.password = text;
        }
        // The stage has no PAM: Enter checks for a beat, then lets go as a good password does.
        onAccepted: {
          if (root.busy || root.password.length === 0)
            return;
          root.busy = true;
          root.password = "";
          verdict.restart();
        }
      }
    }
  }

  Timer {
    id: verdict

    interval: 60
    onTriggered: {
      root.busy = false;
      reveal.animateOut();
    }
  }

  onActiveChanged: {
    if (!active) {
      verdict.stop();
      reveal.reset();
      password = "";
      busy = false;
      refusals = 0;
      faults = 0;
    }
  }

  Connections {
    target: reveal

    function onRevealOutFinished() {
      root.active = false;
    }
  }

  Connections {
    target: Bus

    // The rehearsal surface must never remain above the real PAM-backed lock.
    function onSurfacesClosingForLock() {
      root.active = false;
    }
  }

  IpcHandler {
    target: "lockpreview"

    function preview(on: bool): void {
      if (root.active === on)
        return;
      if (on) {
        root.password = "";
        root.busy = false;
        root.refusals = 0;
        root.faults = 0;
        reveal.reset();
        root.active = true;
        reveal.arm();
        return;
      }
      root.active = false;
    }

    // The way out played as the real unlock does it; the stage comes down when it ends.
    function unlock(): void {
      if (!root.active)
        return;
      root.busy = false;
      root.password = "";
      reveal.animateOut();
    }

    function password(text: string): void {
      root.password = text;
    }

    function busy(on: bool): void {
      root.busy = on;
      if (on)
        root.password = "";
    }

    // A refusal: the checking lozenge shakes back to the glyph, in love.
    function refuse(): void {
      root.busy = false;
      root.password = "";
      root.refusals += 1;
    }

    // A check that never came back: the lozenge opens to a gold padlock, without the shake.
    function fault(): void {
      root.busy = false;
      root.password = "";
      root.faults += 1;
    }

    // The time to show, "HH:mm", to rehearse a change of minute; "" follows the clock again.
    function time(text: string): void {
      root.time = text;
    }

    // The capture prefix to stand on (`grim -o OUT PREFIX-OUT.png`), or "" for the wallpaper.
    function background(prefix: string): void {
      root.background = prefix;
    }
  }
}
