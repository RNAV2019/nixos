pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// The themes the picker offers, the wallpaper each one would come up on, and how to switch.
//
// Switching is `theme-switch <id>`, the same command the rest of the desktop uses: it moves
// the theme link, brings back that theme's wallpaper and tells every running program. The
// shell itself follows through Theme.name, which watches the file the switch writes.
Singleton {
  id: root

  readonly property string home: Quickshell.env("HOME")

  // { id, label, palette }, in the order the picker shows them.
  readonly property var entries: Theme.themeIds.map(function (id) {
    return {
      id: id,
      label: Theme.palettes[id].label,
      palette: Theme.palettes[id]
    };
  })

  readonly property int index: Theme.themeIds.indexOf(Theme.name)

  // The resolved wallpaper each theme would come up on, keyed by id: its last-used link if
  // that resolves, otherwise the first file in its folder, as theme-switch picks it. An id
  // is absent until the first read comes back.
  property var previews: ({})

  function preview(id) {
    return previews[id] !== undefined ? previews[id] : "";
  }

  // A refresh asked for while one is still running is queued rather than dropped: the switch
  // exiting and the wallpaper it moved both ask for one, within a frame of each other.
  property bool scanQueued: false

  function refresh() {
    if (scan.running)
      scanQueued = true;
    else
      scan.running = true;
  }

  function apply(id) {
    if (Theme.themeIds.indexOf(id) < 0 || id === Theme.name)
      return;
    switcher.command = ["theme-switch", id];
    switcher.running = true;
  }

  // Nothing to handle on failure: the name file is the record, and it only changes when
  // the switch went through.
  Process {
    id: switcher

    stderr: StdioCollector {
      onStreamFinished: {
        if (text.trim() !== "")
          console.warn("theme-switch:", text.trim());
      }
    }

    onExited: root.refresh()
  }

  Process {
    id: scan

    command: ["sh", "-c", 'for id in "$@"; do w="$(readlink -e "$HOME/.local/share/wallpaper/$id")"; if [ -z "$w" ]; then for f in "$HOME/Pictures/backgrounds/$id"/*; do [ -f "$f" ] && { w="$(readlink -f "$f")"; break; }; done; fi; printf "%s\t%s\n" "$id" "$w"; done', "sh"].concat(Theme.themeIds)

    onExited: {
      if (root.scanQueued) {
        root.scanQueued = false;
        Qt.callLater(function () {
          scan.running = true;
        });
      }
    }

    stdout: StdioCollector {
      onStreamFinished: {
        var found = {};
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
          var parts = lines[i].split("\t");
          if (parts.length < 2 || parts[0] === "")
            continue;
          found[parts[0]] = parts[1].trim();
        }
        root.previews = found;
      }
    }
  }

  // Choosing a wallpaper rewrites the active theme's link, and a switch moves `current`;
  // either way the previews are read again.
  Connections {
    target: Wallpapers

    function onCurrentChanged() {
      root.refresh();
    }
  }

  Component.onCompleted: root.refresh()
}
