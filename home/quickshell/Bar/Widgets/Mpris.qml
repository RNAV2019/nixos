import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Commons

Item {
  id: root

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

  // The timer stops the moment playing goes false, so it never ticks again to
  // show where playback actually stopped. Push that one refresh here.
  onPlayingChanged: if (player)
    player.positionChanged()

  function formatTime(seconds) {
    var s = Math.max(0, Math.floor(seconds));
    var m = Math.floor(s / 60);
    var r = s % 60;
    return (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r;
  }

  // Fit fields by priority into 40 characters, excluding separators.
  readonly property string dynamic: {
    if (!player)
      return "";

    var title = player.trackTitle || "";
    var artist = player.trackArtist || "";
    var pos = player.positionSupported ? formatTime(player.position) : "";
    var len = (player.lengthSupported && player.length > 0) ? formatTime(player.length) : "";

    var budget = 40;
    var used = 0;
    var keep = {};
    var order = [["title", title], ["artist", artist], ["position", pos], ["length", len]];
    for (var i = 0; i < order.length; i++) {
      var name = order[i][0];
      var value = order[i][1];
      if (value.length === 0)
        continue;
      if (used + value.length > budget)
        continue;
      keep[name] = true;
      used += value.length;
    }

    var s = keep["title"] ? title : title.substring(0, budget - 1) + "…";
    if (keep["artist"])
      s += " - " + artist;
    var time = "";
    if (keep["position"])
      time = pos;
    if (keep["length"])
      time += (time.length > 0 ? "/" : "") + len;
    if (time.length > 0)
      s += " [" + time + "]";
    return s;
  }

  // positionChanged() refreshes the visible position. A paused player does not
  // advance, so only poll while playing; the pause itself still pushes one
  // refresh so the final position is correct.
  Timer {
    running: root.playing
    repeat: true
    triggeredOnStart: true
    interval: 1000
    onTriggered: root.player.positionChanged()
  }

  implicitWidth: active ? Math.min(label.implicitWidth, Theme.barMprisMaxWidth) + Theme.barPillPadding * 2 : 0
  implicitHeight: Theme.barHeight
  visible: active

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: Theme.base
    clip: true

    // The transport glyph keeps the Nerd Font; the track title is prose.
    Row {
      id: label

      anchors.centerIn: parent
      spacing: Theme.spacingSm

      Text {
        id: mprisGlyph
        anchors.verticalCenter: parent.verticalCenter
        text: root.player && root.player.isPlaying ? Icons.mprisPlaying : Icons.mprisPaused
        color: Theme.foam
        font.family: Theme.iconFont
        font.pixelSize: Theme.fontSize
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        // Prevent long titles from displacing the centered workspaces.
        width: Math.min(implicitWidth, Theme.barMprisMaxWidth - mprisGlyph.width - label.spacing)
        elide: Text.ElideRight
        color: Theme.foam
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontSize
        text: root.dynamic
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.ForwardButton | Qt.BackButton
      onClicked: function (event) {
        if (!root.player)
          return;
        if (event.button === Qt.ForwardButton)
          root.player.next();
        else if (event.button === Qt.BackButton)
          root.player.previous();
        else
          root.player.togglePlaying();
      }
    }
  }
}
