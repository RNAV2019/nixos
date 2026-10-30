import QtQuick
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Control
import qs.Services
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

  // The lists are keyed by node id; nodes come and go as streams start and devices appear,
  // and a row must outlive the churn around it. Rows hold the label as text and look the node
  // up for what they do, so a row fading out after its node is gone still reads.
  function nodeRows(nodes, describe) {
    var rows = [];
    var byKey = {};
    for (var i = 0; i < nodes.length; i++) {
      var key = "n" + nodes[i].id;
      byKey[key] = nodes[i];
      rows.push({
        "key": key,
        "nodeId": nodes[i].id,
        "kind": "node",
        "text": describe(nodes[i])
      });
    }
    return {
      "entries": rows,
      "byKey": byKey
    };
  }

  readonly property var sinkSnapshot: nodeRows(sinks, label)
  readonly property var sourceSnapshot: nodeRows(sources, label)

  // Applications get their heading as the list's first row, so it comes and goes with them.
  readonly property var streamSnapshot: {
    var snap = nodeRows(streams, appLabel);
    if (snap.entries.length > 0)
      snap.entries.unshift({
        "key": "~apps",
        "nodeId": -1,
        "kind": "header",
        "text": "Applications"
      });
    return snap;
  }

  onSinkSnapshotChanged: sinkList.sync(sinkSnapshot.entries, sinkSnapshot.byKey)
  onSourceSnapshotChanged: sourceList.sync(sourceSnapshot.entries, sourceSnapshot.byKey)
  onStreamSnapshotChanged: streamList.sync(streamSnapshot.entries, streamSnapshot.byKey)

  Component.onCompleted: {
    sinkList.sync(sinkSnapshot.entries, sinkSnapshot.byKey);
    sourceList.sync(sourceSnapshot.entries, sourceSnapshot.byKey);
    streamList.sync(streamSnapshot.entries, streamSnapshot.byKey);
  }

  SectionLabel {
    width: parent.width
    title: "Output device"
  }

  KeyedList {
    id: sinkList

    width: parent.width
    animated: root.active

    delegate: DeviceRow {
      required property string key
      required property int nodeId
      required property string text

      width: sinkList.width
      label: text
      selected: root.sink !== null && nodeId === root.sink.id
      showCheck: true
      Accessible.role: Accessible.RadioButton
      Accessible.name: text
      Accessible.checkable: true
      Accessible.checked: selected
      Accessible.focusable: true
      onClicked: {
        var node = sinkList.objectFor(key);
        if (node)
          Pipewire.preferredDefaultAudioSink = node;
      }
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

  KeyedList {
    id: sourceList

    width: parent.width
    animated: root.active

    delegate: DeviceRow {
      required property string key
      required property int nodeId
      required property string text

      width: sourceList.width
      label: text
      selected: root.source !== null && nodeId === root.source.id
      showCheck: true
      Accessible.role: Accessible.RadioButton
      Accessible.name: text
      Accessible.checkable: true
      Accessible.checked: selected
      Accessible.focusable: true
      onClicked: {
        var node = sourceList.objectFor(key);
        if (node)
          Pipewire.preferredDefaultAudioSource = node;
      }
    }
  }

  VolumeRow {
    width: parent.width
    node: root.source
    accessibleName: "Input volume"
    muteAccessibleName: "Mute input"
  }

  KeyedList {
    id: streamList

    width: parent.width
    animated: root.active

    delegate: Item {
      id: slot

      required property string key
      required property string kind
      required property string text

      readonly property bool isHeader: kind === "header"
      readonly property var node: streamList.objectFor(key)

      // The slider follows the node while it lasts and holds its last reading through the
      // fade-out, rather than draining to nothing as the node disappears.
      property real volume: 0
      property bool muted: false

      Binding {
        target: slot
        property: "volume"
        value: slot.node && slot.node.audio ? slot.node.audio.volume : 0
        when: slot.node !== null && slot.node.audio
        restoreMode: Binding.RestoreNone
      }

      Binding {
        target: slot
        property: "muted"
        value: slot.node && slot.node.audio ? slot.node.audio.muted : false
        when: slot.node !== null && slot.node.audio
        restoreMode: Binding.RestoreNone
      }

      width: streamList.width
      height: isHeader ? Theme.controlSectionHeight + 8 : Theme.controlRowHeight

      SectionLabel {
        anchors.fill: parent
        visible: slot.isHeader
        title: slot.text
      }

      DeviceRow {
        anchors.fill: parent
        visible: !slot.isHeader
        label: slot.text

        BigSlider {
          id: streamVolume

          compact: true
          anchors.verticalCenter: parent.verticalCenter
          width: 200
          height: 20
          accessibleName: slot.text + " volume"
          glyph: ""
          value: slot.volume
          dimmed: slot.muted
          onMoved: function (v) {
            if (slot.node && slot.node.audio)
              slot.node.audio.volume = v;
          }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: 34
          horizontalAlignment: Text.AlignRight
          text: Math.round(Math.max(0, Math.min(1, streamVolume.displayValue)) * 100) + "%"
          color: Theme.muted
          font.family: Theme.monoFont
          font.pixelSize: Theme.sectionSize
        }
      }
    }
  }

  SectionLabel {
    width: parent.width
    title: "Sounds"
    height: Theme.controlSectionHeight + 8
  }

  DeviceRow {
    width: parent.width
    label: "Interface sounds"
    sublabel: "Clicks and chimes from the shell"
    Accessible.role: Accessible.CheckBox
    Accessible.name: "Interface sounds"
    Accessible.checkable: true
    Accessible.checked: Sounds.enabled
    onClicked: Sounds.enabled = !Sounds.enabled

    // The row's trailing slot ends 8 px in; the extra 8 puts the switch on the row inset.
    Item {
      width: switchBox.width + 8
      height: switchBox.height

      Switch {
        id: switchBox

        checked: Sounds.enabled
        accessibleName: "Interface sounds"
        onToggled: function (v) {
          Sounds.enabled = v;
        }
      }
    }
  }
}
