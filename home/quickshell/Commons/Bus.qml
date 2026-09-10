pragma Singleton

import QtQuick
import Quickshell

Singleton {
  id: root

  property bool sessionReady: false

  signal lockRequested

  // Raised when something asks to record but nothing has been chosen yet. The
  // picker answers this; the recorder itself never opens a surface.
  signal recorderRequested

  // Opening and closing an island surface, by key rather than by name.
  //
  // There used to be a toggled/closed pair per surface and a screen property
  // per surface, which meant seven near-identical signal declarations here,
  // seven IpcHandlers in shell.qml, and seven copies of the same three-line
  // registration handler out in the surfaces. Keying them turns all of that
  // into one of each. The keys are "launcher", "control", "wallpaper",
  // "recorder", "calendar", "session", "profiles", "osd" and "notify".
  signal surfaceToggled(string key)
  signal surfaceClosed(string key)

  function toggleSurface(key) {
    surfaceToggled(key);
  }

  function closeSurface(key) {
    surfaceClosed(key);
  }

  // Which output each surface currently owns, keyed the same way. Absent means
  // the surface is not on screen anywhere.
  //
  // Reassigned wholesale rather than mutated, because a binding cannot see a
  // property written into a JavaScript object in place - islandHeld below
  // would go stale the first time a surface opened.
  property var owners: ({})

  // Transient surfaces do not claim the island through owners because they
  // dismiss themselves. The bar still needs their output markers to stand the
  // pill down while the compositor blurs the desktop behind them.
  property string osdScreen: ""
  property string notifyScreen: ""

  function setOwner(key, screenName) {
    var next = {};
    for (var k in owners)
      next[k] = owners[k];
    if (screenName === "")
      delete next[key];
    else
      next[key] = screenName;
    owners = next;
  }

  function ownerOf(key) {
    return owners[key] !== undefined ? owners[key] : "";
  }

  // The two that arrive unasked. Everything else is up until the user
  // dismisses it, which is the distinction islandHeld and islandReplaced are
  // actually about.
  readonly property var transientKeys: ["osd", "notify"]

  function isTransient(key) {
    return transientKeys.indexOf(key) !== -1;
  }

  // True while a surface the user has to dismiss is holding the island. The
  // two that arrive unasked wait on this rather than shoving a panel off the
  // screen the moment a volume key is pressed or a notification lands.
  readonly property bool islandHeld: {
    for (var k in owners) {
      if (!root.isTransient(k))
        return true;
    }
    return false;
  }

  // True while any surface at all is standing in for the island on this
  // output. No two of them are ever open at once: the ones the user opens
  // close each other, and the two that arrive unasked hold themselves back
  // while any of those is up.
  function islandTaken(name) {
    if (name === "")
      return false;
    for (var k in owners) {
      if (owners[k] === name)
        return true;
    }
    return false;
  }

  // Of those, the ones that are here until the user dismisses them, as against
  // the OSD's second and a half. The island drops a pin for these and not for
  // the others.
  function islandReplaced(name) {
    if (name === "")
      return false;
    for (var k in owners) {
      if (owners[k] === name && !root.isTransient(k))
        return true;
    }
    return false;
  }

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

  // Raised by a surface letting the island go with nothing growing in its
  // place, carrying the output it let it go on. A still held for that surface
  // is owed to a taker that is now leaving, and the taker shrinking back to
  // the pill uncovers it: the panel before last comes back for a moment on
  // the way down. Whoever is holding one drops it instead.
  signal islandDropped(string screen)

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

  // Bumped once per claim, just before the claim goes out. A surface that is
  // holding a still records the serial it armed that still for, which is how
  // it tells the handover the still belongs to from a later one. See the
  // stale-still drop in Ui/IslandOrigin.qml.
  property int claimSerial: 0

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
}
