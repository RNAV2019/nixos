pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// One choice of "the player that matters" for the whole shell. The island and
// any future media surface have to agree on it, so the pick lives here rather
// than inside a widget.
Singleton {
  id: root

  // Ambient-sound players are not media the island should announce.
  readonly property var ignored: ["blanket", "com.rafaelmardojai.blanket"]

  readonly property var player: {
    var best = null;
    for (var i = 0; i < Mpris.players.values.length; i++) {
      var p = Mpris.players.values[i];
      var id = (p.identity || "").toLowerCase();
      var bus = (p.dbusName || "").toLowerCase();
      var skip = false;
      for (var j = 0; j < ignored.length; j++) {
        if (id.indexOf(ignored[j]) !== -1 || bus.indexOf(ignored[j]) !== -1)
          skip = true;
      }
      if (skip)
        continue;
      if (p.isPlaying)
        return p;
      if (best === null)
        best = p;
    }
    return best;
  }

  readonly property bool active: player !== null && player.playbackState !== MprisPlaybackState.Stopped

  readonly property bool playing: player !== null && player.isPlaying

  readonly property string title: active && player.trackTitle ? player.trackTitle : ""

  readonly property string artist: active && player.trackArtist ? player.trackArtist : ""

  readonly property string artUrl: active && player.trackArtUrl ? player.trackArtUrl : ""

  function toggle() {
    if (player)
      player.togglePlaying();
  }

  function next() {
    if (player)
      player.next();
  }

  function previous() {
    if (player)
      player.previous();
  }
}
