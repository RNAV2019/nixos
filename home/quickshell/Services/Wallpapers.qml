pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// The wallpapers on disk, which one is up, and how to change it.
//
// The link at ~/.local/share/wallpaper/current and awww have to move together; the link
// is written first, so a session restarted before the daemon was told still comes up on
// the right wallpaper. Matching is done on the resolved store path, because the path in
// the pictures folder is itself a symlink home-manager writes.
Singleton {
  id: root

  readonly property string home: Quickshell.env("HOME")

  readonly property string directory: home + "/Pictures/backgrounds"
  readonly property string link: home + "/.local/share/wallpaper/current"

  // Every wallpaper found, name-sorted, as { path, real, name }.
  property var entries: []

  // Empty until the first read comes back, which is why the url below falls back to the link.
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

  // The home directory is written back as a tilde, as a path in a shell surface should be.
  readonly property string directoryLabel: "~" + directory.substring(home.length) + "/"

  function refresh() {
    if (!scan.running)
      scan.running = true;
    if (!resolve.running)
      resolve.running = true;
  }

  // The link is written first; see the note at the top.
  function apply(entry) {
    if (!entry || entry.real === root.current)
      return;
    root.current = entry.real;
    relink.target = entry.path;
    relink.command = ["sh", "-c", 'ln -sfn "$1" "$2.new" && mv -T "$2.new" "$2"', "sh", entry.path, root.link];
    relink.running = true;
  }

  // Renamed over the old one, because rename is the only way to replace a symlink without
  // a moment where it does not exist.
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

  // No daemon means nothing to tell, and the link is already written, so failing quietly
  // is the whole handling.
  Process {
    id: paint
  }

  Process {
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

  // A glob in one shell rather than find, because both the path and the file it resolves
  // to are wanted per line and find can only print one of them.
  Process {
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
