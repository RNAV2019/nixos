pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../Lyrics/Parse.js" as Parse
import "../Lyrics/Pill.js" as Pill

// The words of what is playing, timed, and where the song is in them: what the island's pill
// shows a line at a time (Lyrics/LyricLine.qml). Asked of LyricsPlus first, which times every
// word and names the song's parts, then of LRCLIB, which times lines only (the words are then
// spread across each line). Both ask for no key. Nothing is fetched while the words are switched
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
  // Who answered: "Apple", "QQ Music", "LRCLIB"...
  readonly property string source: model ? model.source : ""

  // The song as a lyrics service files it: a video's "Artist - Title (Official Video)" taken apart.
  readonly property var track: Parse.splitTitle(Media.title, Media.artist)
  readonly property string key: Media.active && root.track.title !== "" ? Parse.cacheKey(root.track.title, root.track.artist, Media.length) : ""

  readonly property string plusUrl: "https://lyricsplus.prjktla.my.id/v2/lyrics/get"
  readonly property string lrclibUrl: "https://lrclib.net/api/get"

  // ---- where the song is ----

  // The lines as the pill shows them, cut to its width (Pill.js's phrases); empty unless ready.
  property var phrases: []
  // The song's time in seconds, read every frame while there are words to show; `pinned` holds
  // it at a moment instead (tests, -1 follows the player).
  property real now: 0
  property real pinned: -1
  // The phrase the pill is wide for (-1: the plain pill), and the last to have come up (-1: none
  // yet): it and the one before it are all that can be on screen.
  property int index: -1
  property int latest: -1
  // The pill carries a line just now. Not while the music is paused: the words wait with it.
  readonly property bool up: ticking && index >= 0
  readonly property bool ticking: enabled && phrases.length > 0 && (pinned >= 0 || (Media.playing && Media.positionKnown))

  property real _estimate: 0

  FontMetrics {
    id: face

    font.family: Theme.uiFont
    font.pixelSize: Theme.islandLyricSize
    font.weight: Theme.weightSemi
  }

  // The gap between two words, which is the face's own space.
  readonly property real wordGap: face.advanceWidth(" ")

  // A word is as wide as its Text will be, which is a whole number of px; the gap is not.
  function plan() {
    root.phrases = root.model ? Pill.phrases(root.model.lines, function (text) {
      return text === " " ? root.wordGap : Math.ceil(face.advanceWidth(text));
    }, Theme.islandLyricMaxText) : [];
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
      root.index = -1;
      root.latest = -1;
      return;
    }
    // The player extrapolates its own position between reports; this glides after it rather
    // than copying it, so a report that lands a few milliseconds off does not jerk the words.
    var raw = Media.positionKnown && Media.player ? Media.player.position : 0;
    if (root.pinned >= 0)
      root._estimate = root.pinned;
    else if (dt <= 0 || Math.abs(raw - root._estimate) > 0.5)
      root._estimate = raw;
    else
      root._estimate += dt + (raw - root._estimate) * Math.min(1, dt * 4);
    root.now = root._estimate;
    var wide = Pill.wideFor(root.phrases, root.now);
    if (wide !== root.index)
      root.index = wide;
    var last = Pill.latest(root.phrases, root.now);
    if (last !== root.latest)
      root.latest = last;
  }

  // The song `state` and `model` are about.
  property string _key: ""
  property var _memo: ({})
  property var _missing: ({})

  function query(names) {
    var q = names.title + "=" + encodeURIComponent(root.track.title) + "&" + names.artist + "=" + encodeURIComponent(root.track.artist);
    if (Media.length > 0)
      q += "&duration=" + Math.round(Media.length);
    return q;
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
    writer.path = root.cachePath(root._key);
    writer.setText(JSON.stringify({
      version: 1,
      model: model
    }));
  }

  // `known` when a service answered that it has no such song (curl's 22, or an answer with no
  // timed lines): only then is the song not asked for again. A fetch that never got through
  // (offline, a timeout) is tried again the next time the song is asked for.
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
      if (kept && kept.version === 1 && kept.model && kept.model.lines && kept.model.lines.length > 0)
        root.take(kept.model, false);
      else
        plus.run();
    }

    onLoadFailed: if (reader.path === root.cachePath(root._key))
      plus.run()
  }

  FileView {
    id: writer

    preload: false
    printErrors: false
    onSaveFailed: console.warn("Lyrics: could not keep " + writer.path)
  }

  // curl, never the GUI thread; an answer for a song since skipped is dropped, and the run
  // queued behind it asks for the new one.
  QueuedProcess {
    id: plus

    property int lastCode: 0

    stamp: root._key
    command: ["curl", "--silent", "--show-error", "--fail", "--max-time", "12", root.plusUrl + "?" + root.query({
        title: "title",
        artist: "artist"
      })]

    stdout: StdioCollector {
      id: plusOut
    }

    onExited: function (code) {
      plus.lastCode = code;
      if (plus.stale || root.state !== "loading")
        return;
      var model = code === 0 ? Parse.fromLyricsPlus(plusOut.text) : null;
      if (model !== null)
        root.take(model, true);
      else
        lrclib.run();
    }
  }

  QueuedProcess {
    id: lrclib

    stamp: root._key
    command: ["curl", "--silent", "--show-error", "--fail", "--max-time", "12", root.lrclibUrl + "?" + root.query({
        title: "track_name",
        artist: "artist_name"
      })]

    stdout: StdioCollector {
      id: lrclibOut
    }

    onExited: function (code) {
      if (lrclib.stale || root.state !== "loading")
        return;
      var model = code === 0 ? Parse.fromLrclib(lrclibOut.text) : null;
      if (model !== null)
        root.take(model, true);
      else
        root.none((code === 0 || code === 22) && (plus.lastCode === 0 || plus.lastCode === 22));
    }
  }
}
