import QtQuick
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

// PipeWire pushes every node update, so enumeration and tracking are gated on
// this view being on screen.
Item {
  id: root

  property bool active: false

  signal backed

  readonly property int inset: Theme.controlInset
  readonly property int span: width - inset * 2

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource

  readonly property int contentHeight: Math.min(Theme.controlViewMaxHeight, Theme.controlHeaderHeight + Math.ceil(body.implicitHeight) + Theme.controlPadBottom)

  readonly property var sinks: {
    if (!active)
      return [];
    var out = [];
    for (var i = 0; i < Pipewire.nodes.values.length; i++) {
      var n = Pipewire.nodes.values[i];
      if (!n.isStream && n.isSink && n.audio)
        out.push(n);
    }
    return out;
  }

  readonly property var sources: {
    if (!active)
      return [];
    var out = [];
    for (var i = 0; i < Pipewire.nodes.values.length; i++) {
      var n = Pipewire.nodes.values[i];
      if (!n.isStream && !n.isSink && n.audio)
        out.push(n);
    }
    return out;
  }

  readonly property var streams: {
    if (!active)
      return [];
    var out = [];
    for (var i = 0; i < Pipewire.nodes.values.length; i++) {
      var n = Pipewire.nodes.values[i];
      if (n.isStream && n.isSink && n.audio)
        out.push(n);
    }
    return out;
  }

  PwObjectTracker {
    objects: root.sinks.concat(root.sources).concat(root.streams)
  }

  function label(node) {
    return node.nickname || node.description || node.name;
  }

  function appLabel(node) {
    var props = node.properties || {};
    return props["application.name"] || node.description || node.name;
  }

  ViewHeader {
    width: parent.width
    title: "Audio"
    onBacked: root.backed()
  }

  ScrollView {
    x: root.inset
    y: Theme.controlHeaderHeight
    width: root.span
    height: Math.max(0, root.contentHeight - Theme.controlHeaderHeight - Theme.controlPadBottom)

    Column {
      id: body

      width: root.span
      spacing: Theme.controlRowGap

      SectionLabel {
        width: parent.width
        title: "Output device"
      }

      Repeater {
        model: root.sinks

        DeviceRow {
          required property var modelData

          width: body.width
          label: root.label(modelData)
          selected: root.sink !== null && modelData.id === root.sink.id
          showCheck: true
          onClicked: Pipewire.preferredDefaultAudioSink = modelData
        }
      }

      Item {
        width: parent.width
        height: Theme.controlSliderHeight

        BigSlider {
          id: outVolume

          width: parent.width - Theme.controlSliderHeight - 10
          height: parent.height
          glyph: root.sink && root.sink.audio && root.sink.audio.muted ? Icons.volumeMuted : Icons.step(Icons.volume, root.sink && root.sink.audio ? root.sink.audio.volume * 100 : 0)
          value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
          dimmed: root.sink !== null && root.sink.audio !== null && root.sink.audio.muted
          onMoved: function (v) {
            if (root.sink && root.sink.audio) {
              root.sink.audio.muted = false;
              root.sink.audio.volume = v;
            }
          }
        }

        MuteButton {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          muted: root.sink !== null && root.sink.audio !== null && root.sink.audio.muted
          glyph: muted ? Icons.volumeMuted : Icons.step(Icons.volume, root.sink && root.sink.audio ? root.sink.audio.volume * 100 : 0)
          onToggled: if (root.sink && root.sink.audio)
            root.sink.audio.muted = !root.sink.audio.muted
        }
      }

      SectionLabel {
        width: parent.width
        title: "Input device"
        height: Theme.controlSectionHeight + 8
      }

      Repeater {
        model: root.sources

        DeviceRow {
          required property var modelData

          width: body.width
          label: root.label(modelData)
          selected: root.source !== null && modelData.id === root.source.id
          showCheck: true
          onClicked: Pipewire.preferredDefaultAudioSource = modelData
        }
      }

      Item {
        width: parent.width
        height: Theme.controlSliderHeight

        BigSlider {
          width: parent.width - Theme.controlSliderHeight - 10
          height: parent.height
          glyph: root.source && root.source.audio && root.source.audio.muted ? Icons.microphoneMuted : Icons.microphone
          value: root.source && root.source.audio ? root.source.audio.volume : 0
          dimmed: root.source !== null && root.source.audio !== null && root.source.audio.muted
          onMoved: function (v) {
            if (root.source && root.source.audio) {
              root.source.audio.muted = false;
              root.source.audio.volume = v;
            }
          }
        }

        MuteButton {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          muted: root.source !== null && root.source.audio !== null && root.source.audio.muted
          glyph: muted ? Icons.microphoneMuted : Icons.microphone
          onToggled: if (root.source && root.source.audio)
            root.source.audio.muted = !root.source.audio.muted
        }
      }

      SectionLabel {
        width: parent.width
        visible: root.streams.length > 0
        title: "Applications"
        height: Theme.controlSectionHeight + 8
      }

      Repeater {
        model: root.streams

        DeviceRow {
          id: streamRow

          required property var modelData

          width: body.width
          label: root.appLabel(modelData)

          Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 200
            height: 20

            Rectangle {
              y: (parent.height - height) / 2
              width: parent.width
              height: 4
              radius: 2
              color: Theme.withAlpha(Theme.text, 0.18)

              Rectangle {
                width: parent.width * (streamRow.modelData.audio ? streamRow.modelData.audio.volume : 0)
                height: parent.height
                radius: parent.radius
                color: streamRow.modelData.audio && streamRow.modelData.audio.muted ? Theme.withAlpha(Theme.subtle, 0.5) : Theme.accent
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onPressed: function (event) {
                if (streamRow.modelData.audio)
                  streamRow.modelData.audio.volume = Math.max(0, Math.min(1, event.x / width));
              }
              onPositionChanged: function (event) {
                if (pressed && streamRow.modelData.audio)
                  streamRow.modelData.audio.volume = Math.max(0, Math.min(1, event.x / width));
              }
            }
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            horizontalAlignment: Text.AlignRight
            text: Math.round((streamRow.modelData.audio ? streamRow.modelData.audio.volume : 0) * 100) + "%"
            color: Theme.muted
            font.family: Theme.monoFont
            font.pixelSize: Theme.controlSectionSize
          }
        }
      }
    }
  }
}
