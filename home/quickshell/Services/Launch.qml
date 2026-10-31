pragma Singleton

import QtQuick
import Quickshell

// Starts what the shell opens for the user (an app from the launcher, a file or folder from a
// toast, a sign-in page) in a systemd scope of its own under app-graphical.slice. Started
// directly, it would sit in the shell's own unit, and stopping, restarting or crashing the shell
// would take every app opened from it down too. A scope rather than `uwsm app`: it costs about
// 20 ms a launch rather than 200, and runs the command with the shell's environment as before.
Singleton {
  id: root

  property int serial: 0

  // `command` wrapped to run in a new scope, named for `name` as the XDG systemd spec has it
  // (app-<launcher>-<id>-<random>.scope), for a Process that wants to watch it.
  function scoped(command, name) {
    var id = String(name || command[0] || "app").replace(/^.*\//, "").replace(/[^A-Za-z0-9:_.]/g, "_");
    var unit = "app-quickshell-" + id + "-" + Date.now().toString(16) + (++root.serial).toString(16) + ".scope";
    return ["systemd-run", "--user", "--scope", "--quiet", "--collect", "--slice=app-graphical.slice", "--unit=" + unit, "--"].concat(command);
  }

  function run(command, name, workingDirectory) {
    var args = {
      command: root.scoped(command, name)
    };
    if (workingDirectory)
      args.workingDirectory = workingDirectory;
    Quickshell.execDetached(args);
  }

  // A desktop entry, as DesktopEntry.execute() would run it (its parsed Exec, in its Path).
  function entry(desktopEntry) {
    root.run(desktopEntry.command, desktopEntry.id, desktopEntry.workingDirectory);
  }

  function open(target) {
    if (target)
      root.run(["xdg-open", target], "xdg-open");
  }
}
