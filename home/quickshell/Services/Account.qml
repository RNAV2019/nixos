pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Who is signed in, for the lock screen: the account name, its GECOS full name and its picture.
Singleton {
  id: root

  readonly property string userName: {
    var name = Quickshell.env("USER") || Quickshell.env("LOGNAME") || "";
    if (name.length > 0)
      return name;
    // Neither is set under some session managers; the home directory is named after the account.
    var home = Quickshell.env("HOME") || "";
    return home.substring(home.lastIndexOf("/") + 1);
  }

  // GECOS full name (users.users.<name>.description), read once; the account name until then.
  property string fullName: ""
  readonly property string displayName: fullName.length > 0 ? fullName : userName

  // The picture, and a counter bumped whenever it changes so an Image can bust its cache.
  readonly property string facePath: Quickshell.env("HOME") + "/.face"
  property int faceRevision: 0

  // Watched rather than read once: the lock preview outlives a picture swap.
  FileView {
    id: faceFile

    path: root.facePath
    watchChanges: true
    printErrors: false

    onFileChanged: {
      faceFile.reload();
      root.faceRevision += 1;
    }
  }

  Process {
    running: root.userName.length > 0
    command: ["getent", "passwd", root.userName]

    stdout: StdioCollector {
      onStreamFinished: root.fullName = (this.text.split(":")[4] || "").split(",")[0].trim()
    }
  }
}
