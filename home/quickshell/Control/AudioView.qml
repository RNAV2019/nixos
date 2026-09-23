import QtQuick
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Control
import qs.Ui

// PipeWire pushes every node update, so enumeration and tracking are gated on this view being
// on screen.
ControlSubView {
  id: root

  title: "Audio"
  accessibleName: "Audio settings"

  readonly property var sink: active ? Pipewire.defaultAudioSink : null
  readonly property var source: active ? Pipewire.defaultAudioSource : null

  readonly property var sinks: {
    if (!active)
      return [];
    return Util.filterDevices(Pipewire.nodes.values, function (n) {
      return !n.isStream && n.isSink && n.audio;
    });
  }

  readonly property var sources: {
    if (!active)
      return [];
    return Util.filterDevices(Pipewire.nodes.values, function (n) {
      return !n.isStream && !n.isSink && n.audio;
    });
  }

  readonly property var streams: {
    if (!active)
      return [];
    return Util.filterDevices(Pipewire.nodes.values, function (n) {
      return n.isStream && n.isSink && n.audio;
    });
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

  SectionLabel {
    width: parent.width
    title: "Output device"
  }

  Repeater {
    model: root.sinks

    DeviceRow {
      required property var modelData

      width: parent.width
      label: root.label(modelData)
      selected: root.sink !== null && modelData.id === root.sink.id
      showCheck: true
      Accessible.role: Accessible.RadioButton
      Accessible.name: root.label(modelData)
      Accessible.checkable: true
      Accessible.checked: selected
      Accessible.focusable: true
      onClicked: Pipewire.preferredDefaultAudioSink = modelData
    }
  }

  VolumeRow {
    width: parent.width
    node: root.sink
    accessibleName: "Output volume"
    muteAccessibleName: "Mute output"
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

      width: parent.width
      label: root.label(modelData)
      selected: root.source !== null && modelData.id === root.source.id
      showCheck: true
      Accessible.role: Accessible.RadioButton
      Accessible.name: root.label(modelData)
      Accessible.checkable: true
      Accessible.checked: selected
      Accessible.focusable: true
      onClicked: Pipewire.preferredDefaultAudioSource = modelData
    }
  }

  VolumeRow {
    width: parent.width
    node: root.source
    accessibleName: "Input volume"
    muteAccessibleName: "Mute input"
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

      width: parent.width
      label: root.appLabel(modelData)

      BigSlider {
        id: streamVolume

        compact: true
        anchors.verticalCenter: parent.verticalCenter
        width: 200
        height: 20
        accessibleName: root.appLabel(streamRow.modelData) + " volume"
        glyph: ""
        value: streamRow.modelData.audio ? streamRow.modelData.audio.volume : 0
        dimmed: streamRow.modelData.audio && streamRow.modelData.audio.muted
        onMoved: function (v) {
          if (streamRow.modelData.audio)
            streamRow.modelData.audio.volume = v;
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        horizontalAlignment: Text.AlignRight
        text: Math.round(Math.max(0, Math.min(1, streamVolume.displayValue)) * 100) + "%"
        color: Theme.muted
        font.family: Theme.monoFont
        font.pixelSize: Theme.controlSectionSize
      }
    }
  }
}
