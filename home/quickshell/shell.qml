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
  Lock {
    id: lockScreen
  }
  LockPreview {}

  IpcHandler {
    target: "control"

    function toggle(): void {
      Bus.toggleSurface("control");
    }

    function close(): void {
      Bus.closeSurface("control");
    }
  }

  IpcHandler {
    target: "launcher"

    function toggle(): void {
      Bus.toggleSurface("launcher");
    }

    function close(): void {
      Bus.closeSurface("launcher");
    }
  }

  IpcHandler {
    target: "wallpaper"

    function toggle(): void {
      Bus.toggleSurface("wallpaper");
    }

    function close(): void {
      Bus.closeSurface("wallpaper");
    }
  }

  IpcHandler {
    target: "calendar"

    function toggle(): void {
      Bus.toggleSurface("calendar");
    }

    function close(): void {
      Bus.closeSurface("calendar");
    }
  }

  IpcHandler {
    target: "recorder"

    function toggle(): void {
      Bus.toggleSurface("recorder");
    }

    function close(): void {
      Bus.closeSurface("recorder");
    }
  }

  IpcHandler {
    target: "session"

    function toggle(): void {
      Bus.toggleSurface("session");
    }
  }

  IpcHandler {
    target: "profiles"

    function toggle(): void {
      Bus.toggleSurface("profiles");
    }

    function close(): void {
      Bus.closeSurface("profiles");
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
