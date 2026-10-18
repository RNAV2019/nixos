pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Whether anything is using the camera or the microphone, for the island's privacy marks.
Singleton {
  id: root

  // A stream linked to a capture device. PipeWire's link groups are live, so the mark goes up
  // as the link is made, not on a poll; a sink's monitor feeding a screen recorder is not a
  // microphone and does not count. A group's state reads -1 unless the link is bound, so the
  // link existing is the test.
  readonly property bool microphone: root.capturing(PwNodeType.AudioSource)

  // Browsers open /dev/video* themselves rather than going through PipeWire, so the camera
  // also counts any process holding a video device. PipeWire itself holds one only while
  // something streams from it.
  readonly property bool camera: devicesOpen || root.capturing(PwNodeType.VideoSource)

  property bool devicesOpen: false

  function capturing(sourceType) {
    var groups = Pipewire.linkGroups.values;
    for (var i = 0; i < groups.length; i++) {
      var g = groups[i];
      if (g.source && g.target && g.source.type === sourceType && g.target.isStream)
        return true;
    }
    return false;
  }

  Process {
    id: scan

    command: ["sh", "-c", "find /proc/[0-9]*/fd -lname '/dev/video*' -print -quit 2>/dev/null"]
    stdout: StdioCollector {
      onStreamFinished: root.devicesOpen = text.trim() !== ""
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!scan.running)
      scan.running = true
  }
}
