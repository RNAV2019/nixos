import Quickshell
import Quickshell.Io
import qs.Bar
import qs.Commons
import qs.Lock
import qs.Notifications
import qs.Osd
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
