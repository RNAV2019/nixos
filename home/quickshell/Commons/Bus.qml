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

  signal recorderToggled
  signal recorderClosed

  signal calendarToggled
  signal calendarClosed

  // Raised when something asks to record but nothing has been chosen yet. The
  // picker answers this; the recorder itself never opens a surface.
  signal recorderRequested

  // Emitted by whichever surface is about to take the island, just before it
  // starts to grow, carrying the output it is taking it on. Every island
  // surface gives it up on this rather than on each other's close signals,
  // and they give it up in the same frame: a surface that shrank back to the
  // pill on its own curve would spend the whole of that curve as a second
  // panel behind the one already growing over it, which is two headers and
  // two clocks at once. On the output named, the holder cuts itself away -
  // something is growing in its place - and on any other it takes its own
  // close, because nothing is.
  signal islandClaimed(string screen)

  // The mirror of closePanels, for the bar's dropdown family. The bar emits
  // it when a dropdown is asked for while an island surface is up: the two
  // families stand in for different things at different heights, and neither
  // grows in the other's place, so each owes the other honest mutual
  // exclusion. The island surface answering takes its own animated close -
  // nothing is growing in its place at the bar's centre line, so it owes the
  // pill a proper collapse.
  signal closeIslands

  // The live shape of a surface that has just given the island up to another
  // one in the same frame, published by the surface letting go and consumed
  // by the one taking over, both through the protocol every island surface
  // shares in Ui/IslandOrigin.qml. A launcher-to-control-centre switch then
  // reads as one surface changing shape - the taker starts from the shape the
  // holder is actually wearing, at whatever point its own morph has reached -
  // rather than as one panel vanishing while a second grows out of the pill.
  // Every claim drains the mailbox in the same call stack a shape could have
  // been published in, so it can never outlive the handover it belongs to.
  property string handoffScreen: ""
  property real handoffWidth: 0
  property real handoffHeight: 0
  property real handoffRadius: 0

  // The open shape and morph duration of the surface that is claiming the
  // island, written by it just before the claim and consumed by the holder's
  // hold() inside the claim - the same call stack - so the holder's still can
  // ride the taker's own morph in lockstep and be covered by it from the
  // taker's first presented frame. Cleared by the taker after the claim, on
  // the same discipline as the handoff above.
  property int takeWidth: 0
  property int takeHeight: 0
  property int takeRadius: 0
  property int takeDuration: 0

  // The island card that is currently standing open, or null while every
  // island is a pill.
  //
  // A surface that takes the island's place has to start at the shape the
  // island is actually wearing, and once the card is open that is not the
  // pill. Every surface reads it through Ui/IslandOrigin.qml. The card itself
  // is published rather than its measurements, so the surface reads them at
  // the instant it opens and picks the shape up part way if the card is still
  // growing.
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

  // And the recorder picker, which is the wallpaper picker's twin in every
  // way that matters here.
  property string recorderScreen: ""

  // And the calendar, which the clock on the pill opens.
  property string calendarScreen: ""

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
  readonly property bool islandHeld: launcherScreen !== "" || controlScreen !== "" || wallpaperScreen !== "" || recorderScreen !== "" || calendarScreen !== "" || sessionScreen !== ""

  // True while any surface is standing in for the island. No two of them are
  // ever open at once: the ones the user opens close each other, and the two
  // that arrive unasked hold themselves back while any of those is up.
  function islandTaken(name) {
    return name !== "" && (launcherScreen === name || controlScreen === name || wallpaperScreen === name || recorderScreen === name || calendarScreen === name || sessionScreen === name || osdScreen === name || notifyScreen === name);
  }

  // Of those, the ones that are here until the user dismisses them, as against
  // the OSD's second and a half.
  function islandReplaced(name) {
    return name !== "" && (launcherScreen === name || controlScreen === name || wallpaperScreen === name || recorderScreen === name || calendarScreen === name || sessionScreen === name);
  }
}
