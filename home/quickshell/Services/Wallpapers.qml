pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Wallpapers on disk, which is up, and how to change it. Each theme keeps its own folder
// and last-used link; `current` and awww move together, link first, matched on resolved path.
Singleton {
  id: root

  readonly property string home: Paths.home

  readonly property string directory: Paths.backgroundsDir + "/" + Theme.name
  readonly property string link: Paths.wallpaperDir + "/current"
  // The theme's own record of its last wallpaper, next to `current`.
  readonly property string themeLink: Paths.wallpaperDir + "/" + Theme.name

  // Every wallpaper found, name-sorted, as { path, real, name }.
  property var entries: []

  // Empty until the first read; the url below falls back to the link.
  property string current: ""

  // Keyed on the resolved file: an Image keyed on the link would never reload, since the
  // URL is the same name whatever it points at.
  readonly property string url: "file://" + (current !== "" ? current : link)

  readonly property int index: {
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].real === root.current)
        return i;
    }
    return -1;
  }

  readonly property string name: index >= 0 ? entries[index].name : ""

  // Home is written back as a tilde, as a path in a shell surface should be.
  readonly property string directoryLabel: "~" + directory.substring(home.length) + "/"

  function refresh() {
    scan.run();
    resolve.run();
  }

  // theme-switch has already pointed `current` at the new wallpaper, so both halves are read again.
  Connections {
    target: Theme

    function onNameChanged() {
      root.entries = [];
      root.refresh();
    }
  }

  // The link is written first; see the note at the top.
  function apply(entry) {
    if (!entry || entry.real === root.current)
      return;
    root.current = entry.real;
    relink.target = entry.path;
    relink.command = ["sh", "-c", 'ln -sfn "$1" "$2.new" && mv -T "$2.new" "$2" && ln -sfn "$1" "$3.new" && mv -T "$3.new" "$3"', "sh", entry.path, root.link, root.themeLink];
    relink.running = true;
  }

  // Renamed over the old one, because rename is the only way to replace a symlink
  // without a moment where it does not exist.
  Process {
    id: relink

    property string target: ""

    onExited: function (code) {
      if (code !== 0) {
        // The link is the record: if it did not move, the state goes back to what is on disk.
        root.refresh();
        return;
      }
      paint.command = root.paintCommand(relink.target);
      paint.running = true;
    }
  }

  // Keep the transition explicit so every wallpaper switch behaves the same.
  function paintCommand(target) {
    return ["awww", "img", target, "--transition-type", "grow", "--transition-pos", "center", "--transition-duration", Theme.reduceMotion ? "0" : "0.9", "--transition-fps", "120"];
  }

  // No daemon means nothing to tell and the link is already written, so failing quietly is fine.
  Process {
    id: paint
  }

  QueuedProcess {
    id: resolve

    command: ["readlink", "-f", root.link]

    stdout: StdioCollector {
      onStreamFinished: {
        var line = text.trim();
        if (line !== "")
          root.current = line;
      }
    }
  }

  // A glob in one shell rather than find: both the path and its resolved file are wanted
  // per line, and find can only print one.
  QueuedProcess {
    id: scan

    command: ["sh", "-c", 'for f in "$1"/*; do [ -f "$f" ] || continue; printf "%s\t%s\n" "$f" "$(readlink -f "$f")"; done', "sh", root.directory]

    stdout: StdioCollector {
      onStreamFinished: {
        var found = [];
        var lines = text.split("\n");

        for (var i = 0; i < lines.length; i++) {
          var parts = lines[i].split("\t");
          if (parts.length < 2)
            continue;

          var path = parts[0].trim();
          var real = parts[1].trim();
          if (path === "" || real === "")
            continue;

          var name = path.substring(path.lastIndexOf("/") + 1);
          var dot = name.lastIndexOf(".");
          var ext = dot < 0 ? "" : name.substring(dot + 1).toLowerCase();
          if (["png", "jpg", "jpeg", "webp", "bmp"].indexOf(ext) < 0)
            continue;

          found.push({
            path: path,
            real: real,
            name: name
          });
        }

        // Sorted here rather than by the shell, so the order does not depend on the locale.
        found.sort(function (a, b) {
          return a.name.localeCompare(b.name);
        });

        root.entries = found;
      }
    }
  }

  Component.onCompleted: root.refresh()
}
