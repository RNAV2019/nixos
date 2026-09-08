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

  // The output the launcher currently owns, if any.
  //
  // The launcher opens at exactly the island's collapsed size, on a layer
  // above it, and only ever grows, so it hides the island by covering it and
  // the bar does not have to take the island away. That matters: the two are
  // separate layer surfaces committed independently, and a bar that hid its
  // island the instant the launcher was asked to open would blank the pill a
  // frame or more before the launcher had one to show in its place.
  //
  // What the bar does owe the launcher is a collapsed island. An island held
  // open by hover or by a pin is wider and taller than the launcher's first
  // frames, so it would show around the edges of a surface meant to cover it.
  property string launcherScreen: ""
}
