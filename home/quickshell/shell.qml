import Quickshell
import Quickshell.Io
import qs.Bar
import qs.Commons
import qs.Lock
import qs.Notifications
import qs.Osd
import qs.Services
import qs.Session

ShellRoot {
  Bar {}
  Notifications {}
  Osd {}
  SessionMenu {}
  Lock {
    id: lockScreen
  }

  IpcHandler {
    target: "panels"

    function toggle(name: string): void {
      Bus.togglePanel(name);
    }

    function close(): void {
      Bus.closePanels();
    }
  }

  IpcHandler {
    target: "session"

    function toggle(): void {
      Bus.sessionToggled();
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
