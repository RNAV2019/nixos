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
}
