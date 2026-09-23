import QtQuick
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

// PipeWire pushes every node update, so enumeration and tracking are gated on this view being
// on screen.
Item {
  id: root

  property bool active: false

  enabled: active
  focus: active
  activeFocusOnTab: true

  Accessible.role: Accessible.Pane
  Accessible.name: "Audio settings"
  Accessible.focusable: true
  Accessible.focused: root.activeFocus

  signal backed

  readonly property int inset: Theme.controlInset
  readonly property int span: width - inset * 2

  readonly property var sink: active ? Pipewire.defaultAudioSink : null
  readonly property var source: active ? Pipewire.defaultAudioSource : null

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

  Keys.onPressed: function (event) {
    if (event.key !== Qt.Key_Escape && event.key !== Qt.Key_Backspace)
      return;
    root.backed();
    event.accepted = true;
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
          Accessible.role: Accessible.RadioButton
          Accessible.name: root.label(modelData)
          Accessible.checkable: true
          Accessible.checked: selected
          Accessible.focusable: true
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
          accessibleName: "Output volume"
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
          Accessible.role: Accessible.Button
          Accessible.name: "Mute output"
          Accessible.checkable: true
          Accessible.checked: muted
          Accessible.focusable: true
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
          Accessible.role: Accessible.RadioButton
          Accessible.name: root.label(modelData)
          Accessible.checkable: true
          Accessible.checked: selected
          Accessible.focusable: true
          onClicked: Pipewire.preferredDefaultAudioSource = modelData
        }
      }

      Item {
        width: parent.width
        height: Theme.controlSliderHeight

        BigSlider {
          width: parent.width - Theme.controlSliderHeight - 10
          height: parent.height
          accessibleName: "Input volume"
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
          Accessible.role: Accessible.Button
          Accessible.name: "Mute input"
          Accessible.checkable: true
          Accessible.checked: muted
          Accessible.focusable: true
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

          property real pendingVolume: 0
          property bool hasPendingVolume: false

          readonly property real displayedVolume: hasPendingVolume ? pendingVolume : (modelData.audio ? modelData.audio.volume : 0)

          function queueVolume(v) {
            pendingVolume = Math.max(0, Math.min(1, v));
            hasPendingVolume = true;
            streamWrite.restart();
          }

          function flushVolume() {
            if (!hasPendingVolume)
              return;
            var next = pendingVolume;
            hasPendingVolume = false;
            if (modelData.audio)
              modelData.audio.volume = next;
          }

          Timer {
            id: streamWrite

            interval: 16
            repeat: false
            onTriggered: streamRow.flushVolume()
          }

          width: body.width
          label: root.appLabel(modelData)

          Item {
            id: streamControl

            anchors.verticalCenter: parent.verticalCenter
            width: 200
            height: 20

            activeFocusOnTab: true

            Accessible.role: Accessible.Slider
            Accessible.name: root.appLabel(streamRow.modelData) + " volume"
            Accessible.description: Math.round(streamRow.displayedVolume * 100) + "%"
            Accessible.focusable: true
            Accessible.focused: streamControl.activeFocus

            Keys.onPressed: function (event) {
              var next = streamRow.displayedVolume;
              var absolute = false;
              switch (event.key) {
              case Qt.Key_Left:
              case Qt.Key_Down:
                next -= 0.05;
                break;
              case Qt.Key_Right:
              case Qt.Key_Up:
                next += 0.05;
                break;
              case Qt.Key_Home:
                next = 0;
                absolute = true;
                break;
              case Qt.Key_End:
                next = 1;
                absolute = true;
                break;
              default:
                return;
              }
              streamRow.queueVolume(absolute ? next : Math.max(0, Math.min(1, next)));
              event.accepted = true;
            }

            Rectangle {
              y: (parent.height - height) / 2
              width: parent.width
              height: 4
              radius: 2
              color: Theme.withAlpha(Theme.text, 0.18)

              Rectangle {
                width: parent.width * streamRow.displayedVolume
                height: parent.height
                radius: parent.radius
                color: streamRow.modelData.audio && streamRow.modelData.audio.muted ? Theme.withAlpha(Theme.subtle, 0.5) : Theme.accent
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onPressed: function (event) {
                streamControl.forceActiveFocus();
                streamRow.queueVolume(event.x / width);
              }
              onPositionChanged: function (event) {
                if (pressed)
                  streamRow.queueVolume(event.x / width);
              }
              onReleased: streamRow.flushVolume()
              onCanceled: streamRow.flushVolume()
              onWheel: function (event) {
                streamControl.forceActiveFocus();
                streamRow.queueVolume(streamRow.displayedVolume + (event.angleDelta.y > 0 ? 0.05 : -0.05));
                event.accepted = true;
              }
            }
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            horizontalAlignment: Text.AlignRight
            text: Math.round(streamRow.displayedVolume * 100) + "%"
            color: Theme.muted
            font.family: Theme.monoFont
            font.pixelSize: Theme.controlSectionSize
          }
        }
      }
    }
  }
}
