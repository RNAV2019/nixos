import QtQuick
import Quickshell.Services.Pipewire
import qs.Commons

IconWidget {
  id: root

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var sinkAudio: sink ? sink.audio : null
  readonly property int percent: sinkAudio ? Math.round(sinkAudio.volume * 100) : 0
  readonly property bool muted: sinkAudio ? sinkAudio.muted : true

  // Tracking is required for reactive volume and mute updates.
  PwObjectTracker {
    objects: root.sink ? [root.sink] : []
  }

  // PipeWire omits device.form-factor; infer headphones from metadata.
  readonly property bool isHeadphone: {
    if (!sink)
      return false;
    var p = sink.properties;
    var hints = [p["device.icon_name"], p["device.icon-name"], p["device.profile.description"], sink.description];
    for (var i = 0; i < hints.length; i++) {
      var h = (hints[i] || "").toLowerCase();
      if (h.indexOf("head") !== -1)
        return true;
    }
    return false;
  }

  glyph: {
    if (muted)
      return Icons.volumeMuted;
    if (isHeadphone)
      return Icons.headphone;
    return Icons.step(Icons.volume, percent);
  }

  readonly property string tooltip: muted ? "Muted" : "Playing at " + percent + "%"

  onScrolled: function (delta) {
    if (!sinkAudio)
      return;
    sinkAudio.volume = Math.max(0, Math.min(1, sinkAudio.volume + delta * 0.05));
  }
}
