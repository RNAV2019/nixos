import Quickshell
import Quickshell.Io
import qs.Bar
import qs.Calendar
import qs.Commons
import qs.Control
import qs.Launcher
import qs.Lock
import qs.Notifications
import qs.Osd
import qs.Power
import qs.Recorder
import qs.Services
import qs.Session
import qs.Theme
import qs.Wallpaper

ShellRoot {
  Bar {}
  CalendarPanel {}
  ControlCenter {}
  Launcher {}
  Notifications {}
  Osd {}
  Profiles {}
  RecorderPicker {}
  SessionMenu {}
  WallpaperPicker {}
  ThemePicker {}
  Lock {
    id: lockScreen
  }
  LockPreview {}

  // The six island surfaces with the same toggle/close pair; the still and session targets
  // stay handwritten below, since they differ.
  Variants {
    model: Bus.islandKeys.filter(k => k !== "theme" && k !== "session")

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
}
