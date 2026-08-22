pragma Singleton

import QtQuick
import Quickshell

// Shared state and signals for shell components.
Singleton {
  id: root

  property bool sessionReady: false

  signal togglePanel(string name)
  signal closePanels

  signal lockRequested
  signal sessionToggled
}
