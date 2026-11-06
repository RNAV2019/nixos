pragma Singleton

import QtQuick
import Quickshell

Singleton {
  id: root

  property bool sessionReady: false
  property bool locking: false

  signal surfacesClosingForLock

  // Every surface announces its key when it is made and withdraws it when it goes (Ui/IslandSurface.qml,
  // Ui/TransientSurface.qml), once per output, so a new surface needs no entry here. The lists below
  // are what is alive; nothing listens for a key whose surface has not been made, so nothing needs
  // it earlier.
  property var islandCounts: ({})
  property var transientCounts: ({})

  function registerSurface(key, transient) {
    if (transient)
      transientCounts = writeMap(transientCounts, key, lookup(transientCounts, key, 0) + 1);
    else
      islandCounts = writeMap(islandCounts, key, lookup(islandCounts, key, 0) + 1);
  }

  function unregisterSurface(key, transient) {
    var left = lookup(transient ? transientCounts : islandCounts, key, 0) - 1;
    if (transient)
      transientCounts = writeMap(transientCounts, key, left > 0 ? left : "");
    else
      islandCounts = writeMap(islandCounts, key, left > 0 ? left : "");
  }

  readonly property var islandKeys: Object.keys(islandCounts)

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
    covers = {};
    transientScreens = {};
    transientSurfaces = {};
    islandCards = {};
    islandClaims = {};
    islandHandoffs = {};
    islandHolders = {};
  }

  function finishUnlock() {
    // Ready first: for one assignment both would be false, and what shows for "ready or
    // locking" (the bar, the phone satellite) would drop out and come back.
    sessionReady = true;
    locking = false;
  }

  // What is still coming to rest when a lock is asked for (the phone satellite returning from
  // behind a panel the lock closed), keyed by holder. The lock's snapshot waits for these, up
  // to Theme.lockSettleMax, so the blurred desktop behind the lock shows them in place.
  property var lockHolds: ({})
  readonly property bool lockHeld: Object.keys(lockHolds).length > 0

  function holdLock(key, held) {
    lockHolds = writeMap(lockHolds, key, held ? true : null);
  }

  signal lockRequested

  // Raised when something asks to record but nothing has been chosen yet.
  signal recorderRequested

  // The output whose open control centre is asking, set across that one request; empty for
  // a shortcut or IPC. The picker reads it to know whether backing out returns there.
  property string recorderFrom: ""

  signal clockRefreshed

  // Opening and closing an island surface, by key: any of islandKeys, or a transient key
  // (see transientKeys) for the surfaces that handle it.
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

  // The drawn shape (a FrostedSurface) of the transient last to cover each output, for
  // things that sit beside whatever the island is wearing: the phone satellite rides its
  // right edge. The windows span the output from its top-left, so its x is the screen's.
  property var transientSurfaces: ({})

  function setTransientSurface(screenName, surface) {
    if (screenName !== "")
      transientSurfaces = writeMap(transientSurfaces, screenName, surface);
  }

  function clearTransientSurface(screenName, surface) {
    if (screenName !== "" && lookup(transientSurfaces, screenName, null) === surface)
      transientSurfaces = writeMap(transientSurfaces, screenName, "");
  }

  function transientSurfaceFor(name) {
    return lookup(transientSurfaces, name, null);
  }

  // Where the phone satellite is on each output, written by Bar/PhoneSatellite.qml every frame it
  // moves: { edgeX, midY (the disc's row), shapeY, halfH, capR (the shape it leaves), disc (cx, cy,
  // r), neck (smooth-min k), follow ("pill" or "transient"), windowTop, p, docked, ring, hover }, all
  // in the bar window's coordinates. A transient surface's window draws the bud while it follows
  // that transient (Ui/SatelliteLayer.qml), so it lies over the transient's outline.
  property var satellite: ({})

  function setSatellite(name, geometry) {
    if (name !== "")
      satellite = writeMap(satellite, name, geometry);
  }

  function satelliteFor(name) {
    return lookup(satellite, name, null);
  }

  // Which window draws the satellite on each output, and whether it has a frame on screen. A host
  // claims it when it takes over; the one it took over from keeps drawing while the claim is not
  // ready (Ui/SatelliteLayer.qml), so a hand-over never has a frame with neither.
  property var satelliteHosts: ({})
  property var satelliteReady: ({})

  function claimSatelliteHost(name, id) {
    if (name === "")
      return;
    satelliteReady = writeMap(satelliteReady, name, "");
    satelliteHosts = writeMap(satelliteHosts, name, id);
  }

  function reportSatelliteReady(name, id) {
    if (name !== "" && lookup(satelliteHosts, name, "") === id)
      satelliteReady = writeMap(satelliteReady, name, id);
  }

  function releaseSatelliteHost(name, id) {
    if (lookup(satelliteHosts, name, "") === id) {
      satelliteHosts = writeMap(satelliteHosts, name, "");
      satelliteReady = writeMap(satelliteReady, name, "");
    }
  }

  function satelliteHandoverPending(name) {
    var h = lookup(satelliteHosts, name, "");
    return h !== "" && lookup(satelliteReady, name, "") !== h;
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

  // Which output each island surface is drawn over the pill on, from its first frame on
  // screen until it is back to pill size. Owners are taken at once (other surfaces and
  // services key off them); the bar hides its pill off this instead, so it never goes before
  // something is drawn in its place.
  property var covers: ({})

  function setCover(key, screenName) {
    covers = writeMap(covers, key, screenName);
  }

  function islandCovered(name) {
    if (name === "")
      return false;
    for (var k in covers) {
      if (covers[k] === name)
        return true;
    }
    return false;
  }

  function ownerOf(key) {
    return lookup(owners, key, "");
  }

  // The two that arrive unasked, as against everything else, which is up until dismissed.
  // "sharing" is the Quick Share consent pill: like osd/notify it never claims the
  // island through owners, only through a transient screen, so a real panel covers it.
  // "dictation" is Handy's recording overlay, up for as long as a dictation runs.
  // "moment" is a charger plugged in or a network asking for a sign-in (Activities/Moments.qml);
  // "rebuild" is the system rebuild's progress (Rebuild/RebuildPill.qml); "recording" is a
  // recording that failed (Recorder/RecordingFailedPill.qml).
  readonly property var transientKeys: Object.keys(transientCounts)

  function isTransient(key) {
    return lookup(transientCounts, key, 0) > 0;
  }

  // Which transients want the island, on which output, and how urgently. Only one can be the
  // island at a time, so the highest rank wanting an output has it and the rest wait their
  // turn rather than being knocked out: when it lets go, the next one takes over from it.
  // Keyed by "key@screen" so a surface on one output never clears another's entry.
  property var transientWants: ({})

  // Counts wants as they are made or change rank, so equal ranks take turns first come first
  // served: the older want keeps the island and the younger waits behind it.
  property int wantSerial: 0

  // A negative rank, or no output, withdraws the want.
  function setTransientWant(key, screenName, rank) {
    var id = key + "@" + screenName;
    if (rank < 0 || screenName === "") {
      if (transientWants[id] !== undefined)
        transientWants = writeMap(transientWants, id, "");
      return;
    }
    var cur = transientWants[id];
    if (cur && cur.rank === rank)
      return;
    transientWants = writeMap(transientWants, id, {
      key: key,
      screen: screenName,
      rank: rank,
      serial: ++wantSerial
    });
  }

  // The IslandOrigin that last claimed the island on each output and has not let it go. Unlike
  // owners, which last until the shape is back at the pill, a holder lets go the moment its
  // surface closes, so a transient waiting behind a panel takes over from the panel's close as
  // a handover, rather than waiting it out and growing back out of the pill.
  property var islandHolders: ({})

  function setIslandHolder(screen, origin) {
    if (screen !== "")
      islandHolders = writeMap(islandHolders, screen, origin);
  }

  function clearIslandHolder(screen, origin) {
    if (screen !== "" && lookup(islandHolders, screen, null) === origin)
      islandHolders = writeMap(islandHolders, screen, "");
  }

  function holderKey(origin) {
    return origin && origin.window && origin.window.key !== undefined ? String(origin.window.key) : "";
  }

  // A user-opened surface is open on this output (not merely on its way down).
  function islandOpenFor(name) {
    var key = holderKey(lookup(islandHolders, name, null));
    return key !== "" && !isTransient(key);
  }

  // The same, on any output.
  readonly property bool islandOpenAnywhere: {
    for (var s in islandHolders) {
      var key = root.holderKey(islandHolders[s]);
      if (key !== "" && !root.isTransient(key))
        return true;
    }
    return false;
  }

  // Whether the surface with this key is open on any output.
  function surfaceOpen(key) {
    for (var s in islandHolders) {
      if (root.holderKey(islandHolders[s]) === key)
        return true;
    }
    return false;
  }

  // True while a higher-ranked transient wants this output.
  function transientOutranked(key, screenName, rank) {
    if (screenName === "")
      return false;
    var own = transientWants[key + "@" + screenName];
    var ownSerial = own ? own.serial : Infinity;
    for (var id in transientWants) {
      var want = transientWants[id];
      if (want.screen !== screenName || want.key === key)
        continue;
      if (want.rank > rank || (want.rank === rank && want.serial < ownSerial))
        return true;
    }
    return false;
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

  // The shape a surface was wearing when it let go, and how fast it was changing (px/s per
  // axis), so the taker carries the motion on.
  function publishHandoff(screen, width, height, radius, vw, vh) {
    islandHandoffs = writeMap(islandHandoffs, screen, {
      width: width,
      height: height,
      radius: radius,
      vw: vw,
      vh: vh
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

  // Raised by a surface the first time a frame of it reaches the screen after a claim, with
  // that claim's serial. A still keeps its ground until its own taker reports in.
  signal islandPresented(string screen, int serial)

  function reportPresented(screen, serial) {
    if (screen !== "")
      islandPresented(screen, serial);
  }

  // The island whenever it is anything but the resting pill (open, opening, closing, or the
  // drop well), or null. A surface taking its place starts at the island's actual shape, so
  // the island itself is published rather than measurements.
  property var islandCards: ({})

  function setIslandCard(screen, card) {
    if (screen === "")
      return;
    islandCards = writeMap(islandCards, screen, card);
  }

  function islandCardFor(screen) {
    return lookup(islandCards, screen, null);
  }

  // Where the resting pill sits against its nominal spot, in logical px. The one source: the
  // bar's island and every surface that grows out of it (Ui/IslandOrigin.qml) are placed by
  // these, so a handoff starts from and returns to the pill wherever it is. The shift is the
  // OLED orbit (Services/OledCare.qml); the slide is for anything else that moves the pill
  // sideways, and adds to it.
  property real pillShiftX: 0
  property real pillShiftY: 0
  property real pillSlideX: 0
  readonly property real pillOffsetX: pillShiftX + pillSlideX
  readonly property real pillOffsetY: pillShiftY

  // The workspaces pill takes its own point on the orbit; nothing grows out of it.
  property real workspacesOffsetX: 0
  property real workspacesOffsetY: 0
}
