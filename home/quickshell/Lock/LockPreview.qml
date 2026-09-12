import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// The lock screen on a rehearsal stage: same LockView and LockReveal, no session
// lock, driven over IPC (`qs ipc call lockpreview preview|password|busy|status`).
Scope {
  id: root

  property bool active: false
  property string password: ""
  property string status: ""
  property bool statusIsError: false
  property bool busy: false
  // Sticky, like the real flow: the pill stays up until the preview is taken down.
  property bool inputStarted: false

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
        password: root.password
        status: root.status
        statusIsError: root.statusIsError
        busy: root.busy
        inputStarted: root.inputStarted
        ground: reveal.ground
        clockAlpha: reveal.clockAlpha
        loginAlpha: reveal.loginAlpha

        onPasswordEdited: function (text) {
          root.password = text;
        }
      }
    }
  }

  onActiveChanged: {
    if (!active) {
      reveal.reset();
      password = "";
      status = "";
      statusIsError = false;
      busy = false;
      inputStarted = false;
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
        root.status = "";
        root.statusIsError = false;
        root.busy = false;
        root.inputStarted = false;
        root.active = true;
        reveal.reset();
        reveal.animateIn();
        return;
      }
      root.active = false;
    }

    function password(text: string): void {
      root.inputStarted = true;
      root.password = text;
    }

    function status(text: string, isError: bool): void {
      root.inputStarted = true;
      root.status = text;
      root.statusIsError = isError;
    }

    function busy(on: bool): void {
      root.inputStarted = true;
      root.busy = on;
      if (on)
        root.password = "";
    }
  }
}
