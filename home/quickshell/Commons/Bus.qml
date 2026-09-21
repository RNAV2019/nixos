pragma Singleton

import QtQuick
import Quickshell

Singleton {
  id: root

  property bool sessionReady: false
  property bool locking: false

  signal surfacesClosingForLock

  readonly property var islandKeys: ["launcher", "control", "wallpaper", "theme", "recorder", "calendar", "session", "profiles"]

  function prepareForLock() {
    if (locking)
      return;
    locking = true;
    sessionReady = false;
    for (var i = 0; i < islandKeys.length; i++)
      surfaceClosed(islandKeys[i]);
    surfacesClosingForLock();
    owners = {};
    transientScreens = {};
    islandCards = {};
    islandClaims = {};
    islandHandoffs = {};
  }

  function finishUnlock() {
    locking = false;
    sessionReady = true;
  }

  signal lockRequested

  // Raised when something asks to record but nothing has been chosen yet.
  signal recorderRequested

  // Opening and closing an island surface, by key rather than by name: "launcher",
  // "control", "wallpaper", "theme", "recorder", "calendar", "session", "profiles", "osd",
  // "notify".
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

  // Transient surfaces dismiss themselves, so they never claim the island through owners. The
  // markers are keyed by output because a second monitor must not hide its own island when the
  // focused output is showing an OSD.
  property var transientScreens: ({})

  function setTransientScreen(key, screenName) {
    var next = {};
    for (var k in transientScreens)
      next[k] = transientScreens[k];
    if (screenName === "")
      delete next[key];
    else
      next[key] = screenName;
    transientScreens = next;
  }

  function transientScreen(key) {
    return transientScreens[key] !== undefined ? transientScreens[key] : "";
  }

  function transientOnScreen(name) {
    if (name === "")
      return false;
    for (var k in transientScreens) {
      if (transientScreens[k] === name)
        return true;
    }
    return false;
  }

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

  function islandHeldFor(name) {
    if (name === "")
      return false;
    for (var k in owners) {
      if (owners[k] === name && !root.isTransient(k))
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

  // Per-output handoff transactions. A singleton mailbox is safe only on one monitor; maps keep
  // simultaneous claims and fractional geometry isolated from one another.
  property var islandClaims: ({})
  property var islandHandoffs: ({})

  function claimIsland(screen, width, height, radius, duration) {
    claimSerial++;
    var next = {};
    for (var k in islandClaims)
      next[k] = islandClaims[k];
    next[screen] = {
      serial: claimSerial,
      width: width,
      height: height,
      radius: radius,
      duration: duration
    };
    islandClaims = next;
    islandClaimed(screen);
  }

  function claimFor(screen) {
    return islandClaims[screen] !== undefined ? islandClaims[screen] : null;
  }

  function clearClaim(screen, serial) {
    var claim = claimFor(screen);
    if (!claim || (serial !== undefined && claim.serial !== serial))
      return;
    var next = {};
    for (var k in islandClaims)
      next[k] = islandClaims[k];
    delete next[screen];
    islandClaims = next;
  }

  function publishHandoff(screen, width, height, radius) {
    var next = {};
    for (var k in islandHandoffs)
      next[k] = islandHandoffs[k];
    next[screen] = {
      width: width,
      height: height,
      radius: radius
    };
    islandHandoffs = next;
  }

  function consumeHandoff(screen) {
    var handoff = islandHandoffs[screen] !== undefined ? islandHandoffs[screen] : null;
    if (!handoff)
      return null;
    var next = {};
    for (var k in islandHandoffs)
      next[k] = islandHandoffs[k];
    delete next[screen];
    islandHandoffs = next;
    return handoff;
  }

  // Bumped once per claim. A surface holding a still records the serial it armed it for,
  // which is how it tells that handover from a later one; see Ui/IslandOrigin.qml.
  property int claimSerial: 0

  // The island card that is currently standing open, or null while every island is a pill.
  // A surface taking the island's place starts at the shape the island is actually wearing.
  // The card itself is published rather than its measurements, so the shape can be picked
  // up part way if the card is still growing.
  property var islandCards: ({})

  function setIslandCard(screen, card) {
    if (screen === "")
      return;
    var next = {};
    for (var k in islandCards)
      next[k] = islandCards[k];
    if (card)
      next[screen] = card;
    else
      delete next[screen];
    islandCards = next;
  }

  function islandCardFor(screen) {
    return islandCards[screen] !== undefined ? islandCards[screen] : null;
  }
}
