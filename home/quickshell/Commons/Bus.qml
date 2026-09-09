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

  signal controlToggled
  signal controlClosed

  signal wallpaperToggled
  signal wallpaperClosed

  // Emitted by whichever surface is about to take the island, just before it
  // starts to grow. The two that can be holding it give it up on this rather
  // than on each other's close signals, and they give it up in the same frame:
  // a surface that shrank back to the pill on its own curve would spend the
  // whole of that curve as a second panel behind the one already growing over
  // it, which is two headers and two clocks at once.
  signal islandClaimed

  // The island card that is currently standing open, or null while every
  // island is a pill.
  //
  // A surface that takes the island's place has to start at the shape the
  // island is actually wearing, and once the card is open that is not the
  // pill. The card itself is published rather than its measurements, so the
  // surface reads them at the instant it opens and picks the shape up part
  // way if the card is still growing.
  property var islandCard: null

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

  // The control centre takes the island's place on the same terms, so the bar
  // watches both and stands its island down for whichever holds an output.
  property string controlScreen: ""

  // And the wallpaper picker, on the same terms as those two.
  property string wallpaperScreen: ""

  // The power menu, which is the island too.
  property string sessionScreen: ""

  // The OSD takes the island's place too, for the second and a half it is up.
  property string osdScreen: ""

  // And the toast, which is the island for as long as it is being read.
  property string notifyScreen: ""

  // True while a surface the user has to dismiss is holding the island. The two
  // that arrive unasked - the OSD and the toast - wait on this rather than
  // shoving a panel off the screen the moment a volume key is pressed or a
  // notification lands.
  readonly property bool islandHeld: launcherScreen !== "" || controlScreen !== "" || wallpaperScreen !== "" || sessionScreen !== ""

  // True while any surface is standing in for the island. No two of them are
  // ever open at once: the ones the user opens close each other, and the two
  // that arrive unasked hold themselves back while any of those is up.
  function islandTaken(name) {
    return name !== "" && (launcherScreen === name || controlScreen === name || wallpaperScreen === name || sessionScreen === name || osdScreen === name || notifyScreen === name);
  }

  // Of those, the ones that are here until the user dismisses them, as against
  // the OSD's second and a half.
  function islandReplaced(name) {
    return name !== "" && (launcherScreen === name || controlScreen === name || wallpaperScreen === name || sessionScreen === name);
  }
}
