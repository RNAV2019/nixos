pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

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

  // MPRIS never pushes position, so poll only while the progress bar is on screen.
  property bool trackPosition: false
  property int positionPulse: 0

  readonly property real length: active && player.lengthSupported && player.length > 0 ? player.length : 0

  // Some players answer this with the wrong type; nothing asks those for a position.
  readonly property bool positionKnown: active && player.positionSupported

   readonly property real position: {
     root.positionPulse;
     return positionKnown ? player.position : 0;
   }

  readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0

  readonly property bool seekable: active && player.canSeek && length > 0

  Timer {
    running: root.trackPosition && root.positionKnown && root.playing
    interval: 1000
    repeat: true
    triggeredOnStart: true
     onTriggered: root.positionPulse++
  }

  function seek(fraction) {
    if (seekable)
      player.position = Math.max(0, Math.min(1, fraction)) * length;
  }

  function toggle() {
    // Capable players only: a player that cannot answer is skipped rather than no-op'ing on the bus.
    if (player && player.canPlay)
      player.togglePlaying();
  }

  function next() {
    if (player && player.canGoNext)
      player.next();
  }

  function previous() {
    if (player && player.canGoPrevious)
      player.previous();
  }
}
