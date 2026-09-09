pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The wallpapers on disk, which one is up, and how to change it.
//
// The desktop keeps its answer in two places and they have to move together: a
// symlink at ~/.local/share/wallpaper/current, which is what the shell and the
// session start-up read, and awww, which is what actually paints the root
// surface. Applying writes the link first and then tells the daemon, so a
// session restarted before the daemon was told still comes up on the right
// wallpaper.
//
// Every wallpaper is known by two paths. The one in ~/Pictures/backgrounds is
// what the footer shows and what the link is pointed at; it is itself a symlink
// that home-manager writes, and it survives a rebuild. The one it resolves to
// in the store is what identifies the picture: two paths in the pictures folder
// are the same wallpaper only if they resolve to the same file, and the link
// might have been pointed at either form by something else. Matching is done on
// the resolved path for that reason, and the resolved path is also what the
// shell's own surfaces sample - see url.
Singleton {
  id: root

  readonly property string home: Quickshell.env("HOME")

  readonly property string directory: home + "/Pictures/backgrounds"
  readonly property string link: home + "/.local/share/wallpaper/current"

  // Every wallpaper found, name-sorted, as { path, real, name }.
  property var entries: []

  // The wallpaper currently up, resolved. Empty until the first read comes
  // back, which is why the url below falls back to the link: a surface built in
  // that first moment still has something to sample.
  property string current: ""

  // What the shell's frosted surfaces sample. Keyed on the resolved file rather
  // than on the link, because an Image keyed on the link would never reload: the
  // URL is the same name whatever it points at, so Qt would keep serving the
  // picture it already had.
  readonly property string url: "file://" + (current !== "" ? current : link)

  readonly property int index: {
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].real === root.current)
        return i;
    }
    return -1;
  }

  readonly property string name: index >= 0 ? entries[index].name : ""

  // What the footer draws to the left of the file name. The home directory is
  // written back as a tilde, as a path in a shell surface should be.
  readonly property string directoryLabel: "~" + directory.substring(home.length) + "/"

  function refresh() {
    if (!scan.running)
      scan.running = true;
    if (!resolve.running)
      resolve.running = true;
  }

  // Set the wallpaper, from one of the entries above. The link is written
  // first; see the note at the top.
  function apply(entry) {
    if (!entry || entry.real === root.current)
      return;
    root.current = entry.real;
    relink.target = entry.path;
    relink.command = ["sh", "-c", 'ln -sfn "$1" "$2.new" && mv -T "$2.new" "$2"', "sh", entry.path, root.link];
    relink.running = true;
  }

  // Written to a second name and renamed over the old one, as cherry does it,
  // because rename is the only way to replace a symlink without there being a
  // moment where it does not exist. Anything reading the link in that moment -
  // a session coming up, another shell - would find nothing at all.
  Process {
    id: relink

    property string target: ""

    onExited: function (code) {
      if (code !== 0) {
        // The link is the record. If it did not move, nothing else should, and
        // the state here goes back to whatever is actually on disk.
        root.refresh();
        return;
      }
      paint.command = root.paintCommand(relink.target);
      paint.running = true;
    }
  }

  // cherry's own call, which is what put these wallpapers up before this panel
  // existed: the new picture grows out of the middle of the screen over nine
  // tenths of a second. Switching wallpaper should look the same however it was
  // asked for, so the arguments are copied rather than chosen.
  function paintCommand(target) {
    return ["awww", "img", target, "--transition-type", "grow", "--transition-pos", "center", "--transition-duration", "0.9", "--transition-fps", "120"];
  }

  // If the daemon is not up there is nothing to tell, and the link is already
  // written, so the next session start reads the right file. Failing quietly is
  // the whole handling.
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

  // Each line is the pictures-folder path and the file it resolves to. A glob
  // in one shell rather than find, because both halves are wanted per file and
  // find can only print one of them.
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

        // Sorted here rather than by the shell, so the order does not depend on
        // the locale the session happens to be running under.
        found.sort(function (a, b) {
          return a.name.localeCompare(b.name);
        });

        root.entries = found;
      }
    }
  }

  Component.onCompleted: root.refresh()
}
