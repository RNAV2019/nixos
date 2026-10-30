import QtQuick
import Quickshell
import Quickshell.Io
import qs.Auth
import qs.Bar
import qs.Calendar
import qs.Capture
import qs.Commons
import qs.Control
import qs.Dictation
import qs.Launcher
import qs.Lock
import qs.Nearby
import qs.Notifications
import qs.Osd
import qs.Power
import qs.Recorder
import qs.Services
import qs.Session
import qs.Theme
import qs.Wallpaper

ShellRoot {
  // Singletons start on first use; this one has to be running before the panel opens, to
  // put a remembered monitor back where it was.
  Component.onCompleted: Displays.restoreAll()

  Bar {}
  AuthPrompt {}
  AuthPreview {}
  CalendarPanel {}
  CaptureTray {}
  DictationPill {}
  ControlCenter {}
  Launcher {}
  NearbyPanel {}
  SharingPill {}
  Notifications {}
  Osd {}
  Profiles {}
  RecorderPicker {}
  ScreenToolsPanel {}
  SessionMenu {}
  WallpaperPicker {}
  ThemePicker {}
  Lock {
    id: lockScreen
  }
  LockPreview {}

  // The island surfaces with the same toggle/close pair; the recorder, theme, session, nearby
  // and screen tools targets stay handwritten below, since they differ, and the auth prompt takes
  // no toggle: polkitd opens it, and only an answer closes it.
  Variants {
    model: Bus.islandKeys.filter(k => k !== "theme" && k !== "session" && k !== "recorder" && k !== "nearby" && k !== "screentools" && k !== "auth")

    IpcHandler {
      required property string modelData

      target: modelData

      function toggle(): void {
        Bus.toggleSurface(modelData);
      }

      function close(): void {
        Bus.closeSurface(modelData);
      }
    }
  }

  IpcHandler {
    target: "theme"

    function toggle(): void {
      Bus.toggleSurface("theme");
    }

    function close(): void {
      Bus.closeSurface("theme");
    }

    // theme-switch calls this once the name is written; see Theme.reload().
    function sync(): void {
      Theme.reload();
    }
  }

  IpcHandler {
    target: "session"

    function toggle(): void {
      Bus.toggleSurface("session");
    }
  }

  // The recorder's key is busy-aware: while a recording runs, the same key stops it and
  // only an idle recorder opens the picker. See Recorder.toggle() and the pill's tile.
  IpcHandler {
    target: "recorder"

    function toggle(): void {
      if (Recorder.busy)
        Recorder.stop();
      else
        Bus.toggleSurface("recorder");
    }

    function close(): void {
      Bus.closeSurface("recorder");
    }
  }

  // Nearby also takes files, the same path a drop on the island does: `qs ipc call
  // nearby send <path>` opens the panel in Send mode with the file staged.
  IpcHandler {
    target: "nearby"

    function toggle(): void {
      Bus.toggleSurface("nearby");
    }

    function close(): void {
      Bus.closeSurface("nearby");
    }

    function send(path: string): void {
      Nearby.requestSend([path]);
    }

    // Jump straight to the receive view: `qs ipc call nearby receive`.
    function receive(): void {
      Nearby.requestReceive();
    }
  }

  // The screen tools open on a key; `run` fires one directly (the colour picker has its own
  // shortcut), closing the surface first if it is up.
  IpcHandler {
    target: "screentools"

    function toggle(): void {
      Bus.toggleSurface("screentools");
    }

    function close(): void {
      Bus.closeSurface("screentools");
    }

    function run(tool: string): void {
      ScreenTools.start(tool);
    }
  }

  // Screenshots: each is saved, copied and shown in the tray. See Services/Captures.qml.
  IpcHandler {
    target: "capture"

    function region(): void {
      Captures.begin("region");
    }

    function window(): void {
      Captures.begin("window");
    }

    function output(): void {
      Captures.begin("output");
    }

    function screen(): void {
      Captures.begin("screen");
    }
  }

  // The tray's buttons, for a key to be bound to later.
  IpcHandler {
    target: "captures"

    function annotate(): void {
      Captures.annotate();
    }

    function copy(): void {
      Captures.copy();
    }

    function send(): void {
      Captures.send();
    }

    function open(): void {
      Captures.open();
    }

    function step(): void {
      Captures.step();
    }

    function dismiss(): void {
      Captures.dismiss();
    }

    // `delete` is a reserved word in QML, so the IPC call is `remove`.
    function remove(): void {
      Captures.remove();
    }
  }

  // Route the keys through here so the OSD flashes on every press, not just on changes.
  IpcHandler {
    target: "brightness"

    function up(): void {
      Brightness.step(true);
    }

    function down(): void {
      Brightness.step(false);
    }
  }

  IpcHandler {
    target: "volume"

    function up(): void {
      Volume.step(true);
    }

    function down(): void {
      Volume.step(false);
    }
  }

  IpcHandler {
    target: "lock"

    function lock(): void {
      Bus.lockRequested();
    }

    function secure(): bool {
      return lockScreen.secure;
    }
  }

  IpcHandler {
    target: "clock"

    function refresh(): void {
      Bus.clockRefreshed();
    }
  }
}
