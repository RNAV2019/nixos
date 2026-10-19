pragma Singleton

import QtQuick
import Quickshell
import qs.Services

// Ending the session. Locking is the lock screen's own (Bus.lockRequested); this is the
// rest of the session menu.
Singleton {
  id: root

  function reboot() {
    systemctl.exec(["systemctl", "reboot"]);
  }

  function poweroff() {
    systemctl.exec(["systemctl", "poweroff"]);
  }

  Command {
    id: systemctl

    label: "systemctl"
  }
}
