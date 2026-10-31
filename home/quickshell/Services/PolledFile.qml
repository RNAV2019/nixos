import QtQuick
import Quickshell.Io

// A file read again every `interval`, for the ones the kernel changes behind the
// filesystem's back (procfs, and sysfs when the firmware or driver moves the value), which
// no watch can follow.
FileView {
  id: root

  property int interval: 2000

  property Timer poll: Timer {
    interval: root.interval
    running: root.path !== ""
    repeat: true
    onTriggered: root.reload()
  }
}
