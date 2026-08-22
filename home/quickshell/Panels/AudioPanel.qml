import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

PanelContent {
  id: root

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource

  readonly property var sinks: {
    var out = [];
    for (var i = 0; i < Pipewire.nodes.values.length; i++) {
      var n = Pipewire.nodes.values[i];
      if (!n.isStream && n.isSink && n.audio)
        out.push(n);
    }
    return out;
  }

  readonly property var sources: {
    var out = [];
    for (var i = 0; i < Pipewire.nodes.values.length; i++) {
      var n = Pipewire.nodes.values[i];
      if (!n.isStream && !n.isSink && n.audio)
        out.push(n);
    }
    return out;
  }

  // PipeWire properties update only for tracked nodes.
  PwObjectTracker {
    objects: root.sinks.concat(root.sources)
  }

  function label(node) {
    return node.nickname || node.description || node.name;
  }

  preferredWidth: Theme.panelWidthWide

  ColumnLayout {
    id: column
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    spacing: Theme.spacingMd

    SectionHeader {
      title: "Output"
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Theme.spacingLg

      Text {
        text: root.sink && root.sink.audio && root.sink.audio.muted ? Icons.volumeMuted : Icons.step(Icons.volume, root.sink && root.sink.audio ? root.sink.audio.volume * 100 : 0)
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLarge
        Layout.preferredWidth: 20

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.sink && root.sink.audio)
              root.sink.audio.muted = !root.sink.audio.muted;
          }
        }
      }

      PanelSlider {
        Layout.fillWidth: true
        enabled: root.sink !== null && root.sink.audio !== null
        value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
        onMoved: function (v) {
          if (root.sink && root.sink.audio)
            root.sink.audio.volume = v;
        }
      }

      Text {
        text: Math.round((root.sink && root.sink.audio ? root.sink.audio.volume : 0) * 100) + "%"
        color: Theme.subtle
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        Layout.preferredWidth: 38
        horizontalAlignment: Text.AlignRight
      }
    }

    Repeater {
      model: root.sinks

      PanelRow {
        id: sinkRow

        required property var modelData

        Layout.fillWidth: true
        selected: root.sink !== null && modelData.id === root.sink.id
        onClicked: Pipewire.preferredDefaultAudioSink = modelData

        Text {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.label(sinkRow.modelData)
          color: Theme.text
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          elide: Text.ElideRight
        }
      }
    }

    Separator {
      Layout.fillWidth: true
      Layout.topMargin: Theme.spacingSm
    }

    SectionHeader {
      title: "Input"
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Theme.spacingLg

      Text {
        text: root.source && root.source.audio && root.source.audio.muted ? "󰍭" : "󰍬"
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLarge
        Layout.preferredWidth: 20

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.source && root.source.audio)
              root.source.audio.muted = !root.source.audio.muted;
          }
        }
      }

      PanelSlider {
        Layout.fillWidth: true
        enabled: root.source !== null && root.source.audio !== null
        value: root.source && root.source.audio ? root.source.audio.volume : 0
        onMoved: function (v) {
          if (root.source && root.source.audio)
            root.source.audio.volume = v;
        }
      }

      Text {
        text: Math.round((root.source && root.source.audio ? root.source.audio.volume : 0) * 100) + "%"
        color: Theme.subtle
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        Layout.preferredWidth: 38
        horizontalAlignment: Text.AlignRight
      }
    }

    Repeater {
      model: root.sources

      PanelRow {
        id: sourceRow

        required property var modelData

        Layout.fillWidth: true
        selected: root.source !== null && modelData.id === root.source.id
        onClicked: Pipewire.preferredDefaultAudioSource = modelData

        Text {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.label(sourceRow.modelData)
          color: Theme.text
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
          elide: Text.ElideRight
        }
      }
    }
  }
}
