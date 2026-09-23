import QtQuick
import Quickshell.Io

// The sysfs scaffolding the backlight services shared: discover the device with a shell
// glob (sysfs names vary by driver), read its range, then follow the level.
Item {
  id: root

  // Shell glob naming the device, e.g. "/sys/class/backlight/*". The first entry with a
  // readable `brightness` wins.
  property string glob: ""

  // Whether to watch the level file for changes. Sysfs never emits inotify events, so a
  // polling reader sets this false to skip a watch that cannot fire.
  property bool watch: true

  readonly property string devicePath: probeText

  readonly property int max: _max
  readonly property real value: _max > 0 ? _current / _max : 0
  readonly property bool available: _max > 0 && _currentKnown

  property string probeText: ""
  property int _max: 0
  property int _current: 0
  property bool _currentKnown: false

  Component.onCompleted: findDevice.running = true

  // Nothing found usually means the device has not appeared yet, so ask again slowly
  // until one shows up.
  Timer {
    running: root.glob !== "" && root.devicePath === ""
    interval: 10000
    repeat: true
    onTriggered: if (!findDevice.running)
      findDevice.running = true
  }

  function reload() {
    currentFile.reload();
  }

  Process {
    id: findDevice

    command: ["sh", "-c", 'for d in ' + root.glob + '; do [ -r "$d/brightness" ] && { echo "$d"; exit 0; }; done']

    stdout: StdioCollector {
      onStreamFinished: root.probeText = text.trim()
    }
  }

  FileView {
    id: maxFile

    path: root.devicePath === "" ? "" : root.devicePath + "/max_brightness"
    onLoaded: {
      var m = parseInt(maxFile.text());
      if (isFinite(m) && m > 0) {
        root._max = m;
        currentFile.reload();
      }
    }
  }

  FileView {
    id: currentFile

    path: root.devicePath === "" ? "" : root.devicePath + "/brightness"
    watchChanges: root.watch

    // Sysfs emits write and close notifications on drivers that do; duplicate reloads are safe.
    onFileChanged: currentFile.reload()

    onLoaded: {
      if (root._max <= 0)
        return;
      var current = parseInt(currentFile.text());
      if (!isFinite(current))
        return;
      root._current = current;
      root._currentKnown = true;
    }
  }
}
