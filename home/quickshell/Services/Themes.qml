pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// The themes the picker offers, each one's wallpaper preview, and how to switch.
// Switching runs `theme-switch <id>`; the shell follows through Theme.name.
Singleton {
  id: root

  readonly property string home: Paths.home

  // { id, label, palette }, in the order the picker shows them.
  readonly property var entries: Theme.themeIds.map(function (id) {
    return {
      id: id,
      label: Theme.palettes[id].label,
      palette: Theme.palettes[id]
    };
  })

  readonly property int index: Theme.themeIds.indexOf(Theme.name)

  // Resolved wallpaper per theme id: last-used link if it resolves, else first file in its
  // folder, as theme-switch picks it. An id is absent until the first read comes back.
  property var previews: ({})

  function preview(id) {
    return previews[id] !== undefined ? previews[id] : "";
  }

  function refresh() {
    scan.run();
  }

  function apply(id) {
    if (Theme.themeIds.indexOf(id) < 0 || id === Theme.name)
      return;
    switcher.command = ["theme-switch", id];
    switcher.running = true;
  }

  // Nothing to handle on failure: the name file only changes when the switch went through.
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

  QueuedProcess {
    id: scan

    command: ["sh", "-c", 'for id in "$@"; do w="$(readlink -e "' + Paths.wallpaperDir + '/$id")"; if [ -z "$w" ]; then for f in "' + Paths.backgroundsDir + '/$id"/*; do [ -f "$f" ] && { w="$(readlink -f "$f")"; break; }; done; fi; printf "%s\t%s\n" "$id" "$w"; done', "sh"].concat(Theme.themeIds)

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

  // A wallpaper choice or a switch moves `current`, so previews are read again.
  Connections {
    target: Wallpapers

    function onCurrentChanged() {
      root.refresh();
    }
  }

  Component.onCompleted: root.refresh()
}
