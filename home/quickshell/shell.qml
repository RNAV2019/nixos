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

  IpcHandler {
    target: "control"

    function toggle(): void {
      Bus.controlToggled();
    }

    function close(): void {
      Bus.controlClosed();
    }
  }

  IpcHandler {
    target: "launcher"

    function toggle(): void {
      Bus.launcherToggled();
    }

    function close(): void {
      Bus.launcherClosed();
    }
  }

  IpcHandler {
    target: "wallpaper"

    function toggle(): void {
      Bus.wallpaperToggled();
    }

    function close(): void {
      Bus.wallpaperClosed();
    }
  }

  IpcHandler {
    target: "calendar"

    function toggle(): void {
      Bus.calendarToggled();
    }

    function close(): void {
      Bus.calendarClosed();
    }
  }

  IpcHandler {
    target: "recorder"

    function toggle(): void {
      Bus.recorderToggled();
    }

    function close(): void {
      Bus.recorderClosed();
    }
  }

  IpcHandler {
    target: "session"

    function toggle(): void {
      Bus.sessionToggled();
    }
  }

  IpcHandler {
    target: "profiles"

    function toggle(): void {
      Bus.profilesToggled();
    }

    function close(): void {
      Bus.profilesClosed();
    }
  }

  // The volume and brightness keys route through these so the OSD flashes on
  // every press, not only on presses that move the value.
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
