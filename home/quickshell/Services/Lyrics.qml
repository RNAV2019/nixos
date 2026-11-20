pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../Lyrics/Clock.js" as Clock
import "../Lyrics/Parse.js" as Parse
import "../Lyrics/Pill.js" as Pill
import "../Lyrics/Rank.js" as Rank
import "../Lyrics/Sheets.js" as Sheets

// The words of what is playing, timed, and where the song is in them: what the island's pill
// shows a line at a time, and what it shows while nobody sings (Lyrics/LyricFace.qml). They come
// from where Sonora's lyrics panel gets them, chosen by its rules, so the pill and the panel
// show the same sheet: Apple Music's own, timed word by word, from a public catalogue of them,
// and failing that the best of LRCLIB's uploads for the recording (Lyrics/Rank.js). Only a sheet
// for the recording that is playing is taken, by its length: another take of the song keeps
// another time. Neither source asks for a key. Nothing is fetched while the words are switched
// off (`enabled`, ALT + L), an answer is kept on disk so a song is asked for once, and a song
// neither has is not asked for again until the shell restarts.
Singleton {
  id: root

  // Whether the pill shows the words at all (ALT + L). Kept across restarts; on until told
  // otherwise.
  property bool enabled: true

  function toggle() {
    root.enabled = !root.enabled;
    saved.save(root.enabled ? "1" : "0");
  }

  PersistedValue {
    id: saved

    name: "lyrics"

    onRestored: text => {
      if (text === "0")
        root.enabled = false;
    }
  }

  // Nothing is asked of a lyrics service until the saved choice is known.
  readonly property bool wanted: enabled && saved.loaded

  // "idle" (nothing asked), "loading", "ready" (`model` is set) or "none" (no timed lyrics).
  property string state: "idle"
  // Parse.js's shape; null unless ready.
  property var model: null
  // Who answered: "Apple Music" or "LRCLIB".
  readonly property string source: model ? model.source : ""

  // The song as a lyrics service files it: a video's "Artist - Title (Official Video)" taken apart.
  readonly property var track: Parse.splitTitle(Media.title, Media.artist)
  readonly property string key: Media.active && root.track.title !== "" ? Parse.cacheKey(root.track.title, root.track.artist, Media.length) : ""
  // The song as the sources are asked for it and their answers are held against (Rank.js).
  readonly property var query: ({
      title: root.track.title,
      artist: root.track.artists,
      album: Media.album,
      duration: Media.length
    })

  // The catalogue of Apple Music's sheets Sonora asks (it answers with where each sheet is),
  // and LRCLIB's search, which answers with every upload it has for the song.
  readonly property string appleUrl: "https://lyrics-api.binimum.org/"
  readonly property string lrclibUrl: "https://lrclib.net/api/search"
  // Whose sheet is taken first when both have one the length of the song.
  readonly property var order: ["Apple Music", "LRCLIB"]
  // What a request says it is from: the shell's kind, and nothing of whose it is.
  readonly property string agent: "quickshell-lyrics/2"

  // ---- where the song is ----

  // The lines as the pill shows them, cut to its width (Pill.js's phrases); empty unless ready.
  property var phrases: []
  // When the song's title is up at its start (Pill.opening), or null.
  property var titled: null
  // The song's time in seconds, read every frame while there are words to show; `pinned` holds
  // it at a moment instead (tests, -1 follows the player).
  property real now: 0
  property real pinned: -1
  // What the pill is just now (Pill.faceAt): `face` is "line" (a phrase being sung), "dots"
  // (nobody singing, a line to come), "title" (the song named at its start) or "plain" (the
  // clock's pill), and `facing` the whole answer, replaced only when it changes. `index` is the
  // phrase the pill is wide for (-1 unless a line), and `latest` the last to have come up (-1:
  // none yet): it and the one before it are all that can be on screen.
  property string face: "plain"
  property var facing: null
  property int index: -1
  property int latest: -1
  // The song is being followed. Not while it is paused: the words wait with it.
  readonly property bool ticking: enabled && phrases.length > 0 && (pinned >= 0 || (Media.playing && Media.positionKnown))
  // The shut pill is not the clock's: a line, the dots or the title. Never for a lock, which
  // takes the island as the clock's pill and gives it back as that: its clock flies out of the
  // pill's and home into it. So the face is down from the moment a lock is asked for, and stays
  // down a beat after the lock has let go, so the clock is seen to land before the words take
  // its place.
  readonly property bool faced: ticking && face !== "plain" && !Bus.locking && !Bus.lockClosing && !afterLock
  property bool afterLock: false

  Connections {
    target: Bus

    function onLockingChanged() {
      if (Bus.locking) {
        lockBeat.stop();
        root.afterLock = true;
      } else {
        lockBeat.restart();
      }
    }
  }

  Timer {
    id: lockBeat

    interval: Theme.islandLyricAfterLock
    onTriggered: root.afterLock = Bus.locking
  }

  // How wide what the pill shows is, without the room either side of it; 0 for the clock's pill.
  readonly property real faceWidth: {
    if (!root.faced)
      return 0;
    if (root.face === "line")
      return root.index >= 0 && root.index < root.phrases.length ? root.phrases[root.index].width : 0;
    return root.face === "title" ? root.titleWidth : Theme.islandLyricDots;
  }

  // The shut pill's width, whatever it shows: what the island rests at, and what every surface
  // that grows out of it starts from and comes back to (Ui/IslandOrigin.qml).
  readonly property real pillWidth: faced ? Math.ceil(faceWidth) + 2 * Theme.islandLyricSide(Recorder.recording, Privacy.camera, Privacy.microphone) : Theme.islandCollapsedWidth(Media.announced, Recorder.recording, Privacy.camera, Privacy.microphone)

  property real _estimate: 0

  FontMetrics {
    id: face15

    font.family: Theme.uiFont
    font.pixelSize: Theme.islandLyricSize
    font.weight: Theme.weightSemi
  }

  FontMetrics {
    id: byline

    font.family: Theme.uiFont
    font.pixelSize: Theme.islandLyricSize
    font.weight: Theme.weightMedium
  }

  // The gap between two words, which is the face's own space.
  readonly property real wordGap: face15.advanceWidth(" ")

  // The song as the pill names it: its title, and its artist beside it where both fit. A title
  // too long for the pill is cut to it (the Text elides) and stands alone.
  readonly property string titleText: root.track.title
  readonly property real titleNatural: Math.ceil(face15.advanceWidth(root.titleText))
  readonly property real artistNatural: Math.ceil(byline.advanceWidth(root.track.artist))
  readonly property bool artistShown: root.track.artist !== "" && root.titleNatural + Theme.islandLyricTitleGap + root.artistNatural <= Theme.islandLyricMaxText
  readonly property real titleShown: Math.min(root.titleNatural, Theme.islandLyricMaxText)
  readonly property real titleWidth: root.titleShown + (root.artistShown ? Theme.islandLyricTitleGap + root.artistNatural : 0)

  // A word is as wide as its Text will be, which is a whole number of px; the gap is not.
  function plan() {
    var list = root.model ? Pill.phrases(root.model.lines, function (text) {
      return text === " " ? root.wordGap : Math.ceil(face15.advanceWidth(text));
    }, Theme.islandLyricMaxText) : [];
    root.titled = Pill.opening(list);
    root.phrases = list;
  }

  onModelChanged: root.plan()

  FrameAnimation {
    running: root.ticking
    onTriggered: root.tick(Math.min(0.1, frameTime))
  }

  onTickingChanged: root.tick(0)
  onPhrasesChanged: root.tick(0)
  onPinnedChanged: root.tick(0)

  function tick(dt) {
    if (!root.ticking) {
      root.face = "plain";
      root.facing = null;
      root.index = -1;
      root.latest = -1;
      return;
    }
    // The player's position is run on between its reports (and set right against the player by
    // `correction`, below); this glides after it rather than copying it, so a report that lands
    // a few milliseconds off does not jerk the words.
    var told = Media.positionKnown && Media.player ? Media.player.position : 0;
    root.follow(told);
    var raw = root.holding >= 0 ? root.holding : told + root.correction;
    if (root.pinned >= 0)
      root._estimate = root.pinned;
    else if (root.holding >= 0)
      root._estimate = root.holding;
    else if (dt <= 0 || Math.abs(raw - root._estimate) > 0.5)
      root._estimate = raw;
    else
      root._estimate += dt + (raw - root._estimate) * Math.min(1, dt * 4);
    root.now = root._estimate;
    var f = Pill.faceAt(root.phrases, root.now, root.titled);
    if (root.facing === null || f.kind !== root.facing.kind || f.index !== root.facing.index) {
      root.facing = f;
      root.index = f.kind === "line" ? f.index : -1;
      root.face = f.kind;
    }
    var last = Pill.latest(root.phrases, root.now);
    if (last !== root.latest)
      root.latest = last;
  }

  // ---- the song's clock, set right ----

  // Between a player's reports its position is run on from the last one, which is as good as
  // the report was. Some are not good to the second: Sonora says a track is playing while it is
  // still loading it, renews the position it gives once a second, and says it has jumped only
  // when it is two seconds out, so run on from one reading the words can be up to two seconds
  // early for the whole of a song that took a moment to start. So the player is asked: a burst
  // of readings over a second and a bit, each held as it comes against where the run-on
  // position was at that instant (Lyrics/Clock.js). `correction` is what they say the run-on
  // position is out by, in seconds. A player whose position does not move between its reports
  // gives nothing to go by and is left alone, unless it is one seen to move finely, in which
  // case it is waiting (a track loading, a stream that stalled) and the song's time waits with
  // it: `holding` is where, in seconds, and -1 when the song is running.
  property real correction: 0
  property real holding: -1
  // Players whose position has been seen to move by a second or less at a time, by bus name:
  // only those are held when it stands still through a burst, since one renewed every few
  // seconds stands still through most bursts while playing perfectly well.
  property var _fine: ({})
  property real _toldLast: -1
  property real _toldWall: 0
  // What the readings are about: a new one each time the run-on position is set anew, so a
  // burst begun before then is dropped.
  property int _epoch: 0
  // Bursts in which nothing moved since the epoch began, by a player not known to move finely:
  // it is asked a few times more, then left to the slow round.
  property int _still: 0
  // How many readings a burst takes and how far apart; together longer than a second, so a
  // position renewed once a second steps at least once inside it.
  readonly property int clockReadings: 18
  readonly property real clockEvery: 0.075
  readonly property string clockBus: Media.player && Media.player.dbusName ? Media.player.dbusName : ""
  readonly property real clockRate: Media.player && Media.player.rate > 0 ? Media.player.rate : 1
  readonly property bool clockWanted: root.ticking && root.pinned < 0 && root.clockBus !== ""

  // What was known of the run-on position's error is void: it starts from nothing again.
  function forget() {
    root._epoch++;
    root._still = 0;
    root._toldLast = -1;
    root.correction = 0;
    root.holding = -1;
  }

  // A run-on position that jumps was set anew by the player (a seek, a new track, a resume):
  // the player is asked again at once.
  function follow(told) {
    var wall = Date.now() / 1000;
    var jumped = root._toldLast >= 0 && Math.abs(told - root._toldLast - root.clockRate * (wall - root._toldWall)) > 0.3;
    if (jumped) {
      root.forget();
      clockAsk.restart();
    }
    root._toldLast = told;
    root._toldWall = wall;
  }

  onClockWantedChanged: {
    root.forget();
    if (root.clockWanted)
      clockAsk.restart();
  }
  onClockBusChanged: root.forget()

  // A moment after anything changes, then every twelve seconds while there are words to show.
  Timer {
    id: clockAsk

    interval: 150
    onTriggered: if (root.clockWanted)
      clock.run()
  }

  Timer {
    interval: 12000
    repeat: true
    running: root.clockWanted
    onTriggered: clock.run()
  }

  QueuedProcess {
    id: clock

    property int epoch: -1
    property var before: null
    property int readings: 0
    property int steps: 0

    command: ["env", "LC_ALL=C", "bash", "-c", 'for i in $(seq "$2"); do printf "%s " "$EPOCHREALTIME"; busctl --user get-property "$1" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player Position || exit 1; sleep "$3"; done', "clock", root.clockBus, String(root.clockReadings), String(root.clockEvery)]

    onRunningChanged: {
      if (!clock.running)
        return;
      clock.epoch = root._epoch;
      clock.before = null;
      clock.readings = 0;
      clock.steps = 0;
    }

    stdout: SplitParser {
      onRead: function (row) {
        var reading = Clock.parse(row);
        if (reading === null || clock.epoch !== root._epoch || !root.clockWanted || !Media.player)
          return;
        var before = clock.before;
        clock.before = reading;
        clock.readings++;
        if (before === null)
          return;
        var said = Clock.step(before, reading, Media.player.position, Date.now() / 1000, root.clockRate);
        if (!said.moved)
          return;
        clock.steps++;
        if (said.stride > 0 && said.stride < 1.1 * root.clockRate && !root._fine[root.clockBus]) {
          var fine = root._fine;
          fine[root.clockBus] = true;
          root._fine = fine;
        }
        if (said.ahead === null)
          return;
        // A live position says the same thing every reading, give or take the bus: it is not
        // followed through every hundredth.
        if (root.holding >= 0 || !said.live || Math.abs(said.ahead - root.correction) > 0.02) {
          root.holding = -1;
          root.correction = said.ahead;
        }
      }
    }

    onExited: function (code) {
      if (code !== 0 || clock.epoch !== root._epoch || !root.clockWanted || clock.readings < 4 || clock.steps > 0)
        return;
      // Nothing moved all burst long.
      if (root._fine[root.clockBus]) {
        root.holding = clock.before.position;
        clockAsk.restart();
      } else if (root._still < 3) {
        root._still++;
        clockAsk.restart();
      }
    }
  }

  // ---- fetching ----

  // The song `state` and `model` are about.
  property string _key: ""
  property var _memo: ({})
  property var _missing: ({})
  // The lookup in flight: the song it is for ("" with none), what it asks for, what has come
  // back, and who has yet to answer.
  property string _asked: ""
  property var _query: null
  property var _hits: []
  property bool _appleOpen: false
  property bool _lrclibOpen: false
  // A source could not be reached, so "nothing" is not yet known.
  property bool _unreached: false
  property var _match: null

  function url(base, pairs) {
    var parts = [];
    for (var i = 0; i < pairs.length; i++)
      if (pairs[i][1] !== "")
        parts.push(pairs[i][0] + "=" + encodeURIComponent(pairs[i][1]));
    return base + "?" + parts.join("&");
  }

  function seconds(query) {
    return query && query.duration > 0 ? String(Math.floor(query.duration)) : "";
  }

  function cachePath(key) {
    return Paths.lyricsDir + "/" + key + ".json";
  }

  function refresh() {
    if (!root.wanted || root.key === "") {
      root._key = "";
      root.model = null;
      root.state = "idle";
      return;
    }
    if (root.key === root._key)
      return;
    root._key = root.key;
    root._asked = "";
    root.model = null;
    if (root._memo[root.key] !== undefined) {
      root.take(root._memo[root.key], false);
    } else if (root._missing[root.key] === true) {
      root.state = "none";
    } else {
      root.state = "loading";
      reader.path = "";
      reader.path = root.cachePath(root.key);
    }
  }

  onWantedChanged: root.refresh()
  onKeyChanged: root.refresh()

  // Asks both sources at once for the song in hand.
  function ask() {
    root._asked = root._key;
    root._query = root.query;
    root._hits = [];
    root._unreached = false;
    root._match = null;
    root._appleOpen = true;
    root._lrclibOpen = true;
    appleFind.byAlbum = root._query.album !== "";
    appleFind.run();
    lrclib.run();
  }

  // One source has said all it will: `hits` are its sheets, and `reached` whether it answered
  // at all (having nothing is an answer).
  function answered(source, hits, reached) {
    if (!reached)
      root._unreached = true;
    if (hits.length > 0)
      root._hits = root._hits.concat(hits);
    if (source === "apple")
      root._appleOpen = false;
    else
      root._lrclibOpen = false;
    // Choosing among the sheets is work of its own: it has the next turn, so the reading that
    // came before it and the choosing do not fall in one frame.
    Qt.callLater(root.settle);
  }

  // Takes the best sheet there is once it cannot be bettered: the first source's whole sheet
  // the moment it is in, anything else when every source has answered.
  function settle() {
    // Not for a song skipped since the answer came: its lookup is no longer the one in flight.
    if (root.state !== "loading" || root._asked !== root._key)
      return;
    var waiting = root._appleOpen || root._lrclibOpen;
    // With a source still to answer, only the first source's sheet could settle it.
    if (waiting && !root._hits.some(function (hit) {
      return hit.source === root.order[0];
    }))
      return;
    var best = Rank.best(root._query, root._hits, root.order, Sheets.resolved);
    if (best !== null && ((best.source === root.order[0] && Rank.fullySynced(root._query, best)) || !waiting)) {
      var model = Parse.fromSheet(best);
      if (model !== null) {
        root.take(model, true);
        return;
      }
    }
    if (!waiting)
      root.none(!root._unreached);
  }

  // An answer for the song in hand. `fresh` ones are kept: in memory for the session, and on
  // disk in the one shape, whoever gave them.
  function take(model, fresh) {
    root.model = model;
    root.state = "ready";
    if (!fresh)
      return;
    var memo = root._memo;
    memo[root._key] = model;
    root._memo = memo;
    // Chosen while a source could not be reached, it is good for the session only: the next
    // one asks again, in case that source has the better sheet.
    if (root._unreached)
      return;
    writer.path = root.cachePath(root._key);
    writer.setText(JSON.stringify({
      version: 2,
      model: model
    }));
  }

  // `known` when every source answered and none has the song: only then is it not asked for
  // again. A fetch that never got through (offline, a timeout, a source that is down) is tried
  // again the next time the song is asked for.
  function none(known) {
    if (known) {
      var missing = root._missing;
      missing[root._key] = true;
      root._missing = missing;
    }
    root.state = "none";
  }

  FileView {
    id: reader

    printErrors: false

    onLoaded: {
      if (reader.path !== root.cachePath(root._key))
        return;
      var kept = null;
      try {
        kept = JSON.parse(reader.text());
      } catch (e) {}
      // Version 1 was the sources before these, which could be a sheet for another recording.
      if (kept && kept.version === 2 && kept.model && kept.model.lines && kept.model.lines.length > 0)
        root.take(kept.model, false);
      else
        root.ask();
    }

    onLoadFailed: if (reader.path === root.cachePath(root._key))
      root.ask()
  }

  FileView {
    id: writer

    preload: false
    printErrors: false
    onSaveFailed: console.warn("Lyrics: could not keep " + writer.path)
  }

  // curl, never the GUI thread; an answer for a song since skipped is dropped, and the run
  // queued behind it asks for the new one. Its exit says how it went: 0 an answer, 22 the
  // source saying it has no such thing, anything else that it was not reached.

  // The catalogue, for the recordings it has of the song: by its album first, which tells two
  // editions apart, then without, since the catalogue may name the album otherwise.
  QueuedProcess {
    id: appleFind

    property bool byAlbum: true

    stamp: root._key
    command: ["curl", "--silent", "--show-error", "--fail", "--location", "--max-time", "12", "--user-agent", root.agent, root.url(root.appleUrl, [["track", root.query.title], ["artist", root.query.artist], ["album", appleFind.byAlbum ? root.query.album : ""], ["duration", root.seconds(root.query)]])]

    stdout: StdioCollector {
      id: appleFound
    }

    onExited: function (code) {
      if (appleFind.stale || root.state !== "loading" || root._asked !== root._key || !root._appleOpen)
        return;
      var matches = code === 0 ? Sheets.appleMatches(appleFound.text) : null;
      var mine = matches !== null ? Rank.pick(root._query, matches) : null;
      if (mine !== null) {
        root._match = mine;
        appleSheet.run();
      } else if (appleFind.byAlbum && (matches !== null || code === 22)) {
        appleFind.byAlbum = false;
        Qt.callLater(appleFind.run);
      } else {
        root.answered("apple", [], matches !== null || code === 22);
      }
    }
  }

  // The sheet of the recording the catalogue matched.
  QueuedProcess {
    id: appleSheet

    stamp: root._key
    command: ["curl", "--silent", "--show-error", "--fail", "--location", "--max-time", "12", "--user-agent", root.agent, root._match ? root._match.url : ""]

    stdout: StdioCollector {
      id: appleSheetOut
    }

    onExited: function (code) {
      if (appleSheet.stale || root.state !== "loading" || root._asked !== root._key || !root._appleOpen || root._match === null)
        return;
      var hit = code === 0 ? Sheets.appleHit(root._match, appleSheetOut.text) : null;
      root.answered("apple", hit !== null ? [hit] : [], code === 0 || code === 22);
    }
  }

  QueuedProcess {
    id: lrclib

    stamp: root._key
    command: ["curl", "--silent", "--show-error", "--fail", "--location", "--max-time", "12", "--user-agent", root.agent, root.url(root.lrclibUrl, [["track_name", root.query.title], ["artist_name", root.query.artist]])]

    stdout: StdioCollector {
      id: lrclibOut
    }

    onExited: function (code) {
      if (lrclib.stale || root.state !== "loading" || root._asked !== root._key || !root._lrclibOpen)
        return;
      var query = root._query;
      var hits = code === 0 ? Sheets.lrclibHits(lrclibOut.text, function (upload) {
        return Rank.matched(query, upload);
      }) : null;
      root.answered("lrclib", hits !== null ? hits : [], hits !== null || code === 22);
    }
  }
}
