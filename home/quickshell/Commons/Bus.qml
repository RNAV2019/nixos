pragma Singleton

import QtQuick
import Quickshell

Singleton {
  id: root

  property bool sessionReady: false

  signal lockRequested

  // Raised when something asks to record but nothing has been chosen yet.
  signal recorderRequested

  // Opening and closing an island surface, by key rather than by name: "launcher",
  // "control", "wallpaper", "recorder", "calendar", "session", "profiles", "osd", "notify".
  signal surfaceToggled(string key)
  signal surfaceClosed(string key)

  function toggleSurface(key) {
    surfaceToggled(key);
  }

  function closeSurface(key) {
    surfaceClosed(key);
  }

  // Which output each surface currently owns. Absent means it is not on screen anywhere.
  // Reassigned wholesale rather than mutated, because a binding cannot see a property
  // written into a JavaScript object in place.
  property var owners: ({})

  // Transient surfaces dismiss themselves, so they never claim the island through owners.
  // The bar still needs their markers to stand the pill down.
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

  // The two that arrive unasked, as against everything else, which is up until dismissed.
  readonly property var transientKeys: ["osd", "notify"]

  function isTransient(key) {
    return transientKeys.indexOf(key) !== -1;
  }

  // True while a surface the user has to dismiss is holding the island. The unasked two
  // wait on this rather than shoving an opened panel off the screen.
  readonly property bool islandHeld: {
    for (var k in owners) {
      if (!root.isTransient(k))
        return true;
    }
    return false;
  }

  // True while any surface at all is standing in for the island on this output.
  function islandTaken(name) {
    if (name === "")
      return false;
    for (var k in owners) {
      if (owners[k] === name)
        return true;
    }
    return false;
  }

  // Of those, the ones that stay until dismissed. The island drops a pin for these only.
  function islandReplaced(name) {
    if (name === "")
      return false;
    for (var k in owners) {
      if (owners[k] === name && !root.isTransient(k))
        return true;
    }
    return false;
  }

  // Emitted by whichever surface is about to take the island, just before it starts to
  // grow, carrying the output. On that output the holder cuts itself away, since something
  // is growing in its place; on any other it takes its own close. Cutting rather than
  // shrinking is what avoids two headers and two clocks at once.
  signal islandClaimed(string screen)

  // Raised by a surface letting the island go with nothing growing in its place. Whoever
  // is holding a still for it drops it, or the panel before last would come back on the
  // way down.
  signal islandDropped(string screen)

  // The live shape of a surface that has just given the island up, published by the one
  // letting go and consumed by the one taking over, through Ui/IslandOrigin.qml. The taker
  // starts from the shape the holder is actually wearing, so a launcher-to-control-centre
  // switch reads as one surface changing shape. Every claim drains the mailbox in the same
  // call stack, so it can never outlive its handover.
  property string handoffScreen: ""
  property real handoffWidth: 0
  property real handoffHeight: 0

  // The open shape and morph duration of the surface claiming the island, written just
  // before the claim and consumed by the holder's hold() inside it, so the holder's still
  // rides the taker's morph in lockstep. Cleared by the taker after the claim.
  property int takeWidth: 0
  property int takeHeight: 0
  property int takeRadius: 0
  property int takeDuration: 0

  // Bumped once per claim. A surface holding a still records the serial it armed it for,
  // which is how it tells that handover from a later one; see Ui/IslandOrigin.qml.
  property int claimSerial: 0

  // The island card that is currently standing open, or null while every island is a pill.
  // A surface taking the island's place starts at the shape the island is actually wearing.
  // The card itself is published rather than its measurements, so the shape can be picked
  // up part way if the card is still growing.
  property var islandCard: null
}
