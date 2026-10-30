pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons

// The screen-share picker's request. xdg-desktop-portal-hyprland runs pkgs/share-picker, which
// calls `ask` over IPC and then waits on a FIFO; the surface draws the choice and `answer`
// writes it back. An answer is "<flags>/<screen:NAME | window:ID | region>" (flag r = issue a
// restore token), empty to cancel; the script turns it into xdph's own format.
Singleton {
  id: root

  // The question being asked, or null: { fifo, windows, token, appId, appName }.
  property var request: null
  readonly property bool active: request !== null

  // Raised for each question, for the surfaces to take. Whether one did is `shown`, read
  // straight after: a signal's handlers have all run by the time it returns.
  signal asked
  property bool shown: false

  // What the request offers. Screens are the shell's own; windows come from xdph's list.
  readonly property var screenEntries: Quickshell.screens.map(function (screen) {
    var monitor = Hyprland.monitorFor(screen);
    return {
      name: screen.name,
      screen: screen,
      width: monitor && monitor.width > 0 ? monitor.width : Math.round(screen.width * screen.devicePixelRatio),
      height: monitor && monitor.height > 0 ? monitor.height : Math.round(screen.height * screen.devicePixelRatio)
    };
  })

  readonly property var windowEntries: request ? request.windows : []

  // The desktop entry's name for a window class or portal app id, or "" when there is none.
  function appLabel(id) {
    if (!id)
      return "";
    var key = String(id).replace(/\.desktop$/, "");
    var entry = DesktopEntries.byId(key) || DesktopEntries.heuristicLookup(key);
    return entry && entry.name ? String(entry.name) : "";
  }

  // The wayland toplevel for a window entry, which is what a capture is taken from. Hyprland's
  // address is the join: xdph reports it, and Quickshell's Hyprland toplevels carry it.
  function toplevelFor(entry) {
    var list = Hyprland.toplevels.values;
    var address = String(entry.address).replace(/^0x/, "");
    for (var i = 0; i < list.length; i++) {
      if (address !== "" && String(list[i].address).replace(/^0x/, "") === address)
        return list[i].wayland;
    }
    return null;
  }

  // Called over IPC with the FIFO to answer on and the request as one JSON object, { windows,
  // token, app }: qs ipc drops an empty or bare [] argument, so nothing is passed loose. "ok"
  // once a surface is up; anything else sends the script to the stock picker, or to nothing at
  // all when the screen is locked.
  function ask(fifo, requestJson): string {
    if (Bus.locking || !Bus.sessionReady)
      return "locked";

    var parsed = {};
    try {
      parsed = JSON.parse(requestJson);
    } catch (e) {
      console.warn("share picker: request unreadable: " + e);
    }

    // A question still open belongs to a script that has gone: xdph asks one at a time.
    if (root.request)
      root.answer("");

    root.shown = false;
    root.request = {
      fifo: fifo,
      windows: parsed.windows || [],
      token: parsed.token === true,
      appId: parsed.app || "",
      appName: root.appLabel(parsed.app)
    };
    root.asked();

    if (!root.shown) {
      root.request = null;
      return "unseen";
    }
    return "ok";
  }

  function pending(fifo): bool {
    return root.request !== null && root.request.fifo === fifo;
  }

  // The script gave up (its own timeout, or xdph went away): close the surface, say nothing.
  function cancel(fifo) {
    if (!root.pending(fifo))
      return;
    root.request = null;
    Bus.closeSurface("sharepicker");
  }

  function answer(choice) {
    if (!root.request)
      return;
    var fifo = root.request.fifo;
    root.request = null;
    // The script holds the FIFO open itself, so this never waits on it; the limit is for a
    // script killed since.
    writer.exec(["timeout", "3", "sh", "-c", 'printf "%s\\n" "$1" > "$2"', "sh", choice, fifo]);
  }

  Command {
    id: writer

    label: "share picker answer"
  }
}
