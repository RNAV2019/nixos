pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../Lyrics/Parse.js" as Parse

// The words of what is playing, timed, for the lyric stage. Asked of LyricsPlus first, which
// times every word and names the song's parts, then of LRCLIB, which times lines only (the words
// are then spread across each line). Both ask for no key. Nothing is fetched unless something
// holds `wanted`, an answer is kept on disk so a song is asked for once, and a song neither has
// is not asked for again until the shell restarts.
Singleton {
  id: root

  // Held by whoever shows lyrics (the stage, while it is up).
  property bool wanted: false

  // "idle" (nothing asked), "loading", "ready" (`model` is set) or "none" (no timed lyrics).
  property string state: "idle"
  // Parse.js's shape, every word marked with its picture where it has one; null unless ready.
  property var model: null
  // Who answered: "Apple", "QQ Music", "LRCLIB"..., for the stage's small print.
  readonly property string source: model ? model.source : ""

  // The song as a lyrics service files it: a video's "Artist - Title (Official Video)" taken apart.
  readonly property var track: Parse.splitTitle(Media.title, Media.artist)
  readonly property string key: Media.active && root.track.title !== "" ? Parse.cacheKey(root.track.title, root.track.artist, Media.length) : ""

  readonly property string plusUrl: "https://lyricsplus.prjktla.my.id/v2/lyrics/get"
  readonly property string lrclibUrl: "https://lrclib.net/api/get"

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
  // (offline, a timeout) is tried again the next time the stage comes up.
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
