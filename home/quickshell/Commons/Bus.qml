pragma Singleton

import QtQuick
import Quickshell

Singleton {
  id: root

  property bool sessionReady: false
  property bool locking: false

  signal surfacesClosingForLock

  readonly property var islandKeys: ["launcher", "control", "wallpaper", "theme", "recorder", "calendar", "session", "profiles"]

  // Map helpers for the copy-modify-reassign pattern below: a binding cannot see an in-place
  // property write, so every change builds a fresh object and reassigns the property.
  function writeMap(map, key, value) {
    var next = {};
    for (var k in map)
      next[k] = map[k];
    if (value === "" || value === null || value === undefined)
      delete next[key];
    else
      next[key] = value;
    return next;
  }

  function lookup(map, key, fallback) {
    return map[key] !== undefined ? map[key] : fallback;
  }

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

  // Opening and closing an island surface, by key: "launcher", "control", "wallpaper",
  // "theme", "recorder", "calendar", "session", "profiles", "osd", "notify".
  signal surfaceToggled(string key)
  signal surfaceClosed(string key)

  function toggleSurface(key) {
    surfaceToggled(key);
  }

  function closeSurface(key) {
    surfaceClosed(key);
  }

  // Which output each surface owns; absent means not on screen. Reassigned wholesale
  // rather than mutated, since a binding cannot see an in-place property write.
  property var owners: ({})

  // Transient surfaces dismiss themselves, so they never claim the island through owners.
  // Keyed by output, so a second monitor does not hide its island for another's OSD.
  property var transientScreens: ({})

  function setTransientScreen(key, screenName) {
    transientScreens = writeMap(transientScreens, key, screenName);
  }

  function transientScreen(key) {
    return lookup(transientScreens, key, "");
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
    owners = writeMap(owners, key, screenName);
  }

  function ownerOf(key) {
    return lookup(owners, key, "");
  }

  // The two that arrive unasked, as against everything else, which is up until dismissed.
  readonly property var transientKeys: ["osd", "notify"]

  function isTransient(key) {
    return transientKeys.indexOf(key) !== -1;
  }

  // True while a user-dismissed surface holds the island. The unasked two wait on this
  // rather than shoving an opened panel off the screen.
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

  // Emitted by a surface about to take the island, just before it grows, carrying the
  // output. The holder cuts away rather than shrinks, avoiding two headers/clocks at once.
  signal islandClaimed(string screen)

  // Raised by a surface letting the island go with nothing growing in its place. Whoever
  // holds a still drops it, or the panel before last would return on the way down.
  signal islandDropped(string screen)

  // Per-output handoff transactions. A singleton mailbox is safe only on one monitor; maps
  // keep simultaneous claims and fractional geometry isolated.
  property var islandClaims: ({})
  property var islandHandoffs: ({})

  function claimIsland(screen, width, height, radius, duration) {
    claimSerial++;
    islandClaims = writeMap(islandClaims, screen, {
        serial: claimSerial,
        width: width,
        height: height,
        radius: radius,
        duration: duration
      });
    islandClaimed(screen);
  }

  function claimFor(screen) {
    return lookup(islandClaims, screen, null);
  }

  function clearClaim(screen, serial) {
    var claim = claimFor(screen);
    if (!claim || (serial !== undefined && claim.serial !== serial))
      return;
    islandClaims = writeMap(islandClaims, screen, "");
  }

  function publishHandoff(screen, width, height, radius) {
    islandHandoffs = writeMap(islandHandoffs, screen, {
        width: width,
        height: height,
        radius: radius
      });
  }

  function consumeHandoff(screen) {
    var handoff = lookup(islandHandoffs, screen, null);
    if (!handoff)
      return null;
    islandHandoffs = writeMap(islandHandoffs, screen, "");
    return handoff;
  }

  // Bumped once per claim. A surface holding a still records the serial it armed for, to
  // tell that handover from a later one; see Ui/IslandOrigin.qml.
  property int claimSerial: 0

  // The open island card, or null while every island is a pill. A surface taking its place
  // starts at the island's actual shape, so the card is published rather than measurements.
  property var islandCards: ({})

  function setIslandCard(screen, card) {
    if (screen === "")
      return;
    islandCards = writeMap(islandCards, screen, card);
  }

  function islandCardFor(screen) {
    return lookup(islandCards, screen, null);
  }
}
