pragma Singleton

import QtQuick
import Quickshell

Singleton {
  id: root

  property bool sessionReady: false

  signal togglePanel(string name)
  signal closePanels

  signal lockRequested
  signal sessionToggled

  signal launcherToggled
  signal launcherClosed

  // The launcher is the island wearing another shape, so only one of the two
  // may be on screen at a time. The launcher publishes the output it owns and
  // that output's bar stands its island down until it is handed back.
  property string launcherScreen: ""
}
