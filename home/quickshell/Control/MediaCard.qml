import QtQuick
import QtQuick.Effects
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Services
import qs.Ui

Item {
  id: root

  readonly property var sink: Pipewire.defaultAudioSink

  readonly property string output: {
    if (!sink)
      return "No output";
    return sink.nickname || sink.description || sink.name;
  }

  readonly property bool hasArt: Media.artUrl !== "" && art.status === Image.Ready

  implicitHeight: Theme.controlMediaHeight

  PwObjectTracker {
    objects: root.sink ? [root.sink] : []
  }

  // Masked together, so the blur cannot bleed past the card's corners.
  Item {
    id: ground

    anchors.fill: parent
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: mask
    }

    Rectangle {
      anchors.fill: parent
      color: Theme.surfaceRaised
    }

    // Overscanned, because a blur that samples the card's own edge fades it out.
    Item {
      id: crop

      x: -40
      y: -40
      width: parent.width + 80
      height: parent.height + 80
      visible: false
      layer.enabled: true

      Image {
        id: art

        anchors.fill: parent
        source: Media.artUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
      }
    }

    MultiEffect {
      x: crop.x
      y: crop.y
      width: crop.width
      height: crop.height
      source: crop
      visible: root.hasArt
      blurEnabled: true
      blur: 0.6
      blurMax: 48
      blurMultiplier: 1
    }

    Rectangle {
      anchors.fill: parent
      color: Theme.withAlpha(Theme.canvas, root.hasArt ? 0.58 : 0.2)
    }
  }

  Item {
    id: mask

    anchors.fill: parent
    visible: false
    layer.enabled: true

    Rectangle {
      anchors.fill: parent
      radius: Theme.controlMediaRadius
      color: "black"
    }
  }

  Text {
    id: outputGlyph

    x: 16
    y: 13
    text: root.sink && root.sink.audio && root.sink.audio.muted ? Icons.volumeMuted : Icons.step(Icons.volume, root.sink && root.sink.audio ? root.sink.audio.volume * 100 : 0)
    color: Theme.inkSecondary
    font.family: Theme.iconFont
    font.pixelSize: Theme.controlMediaCaptionSize
  }

  Text {
    x: 36
    y: 13
    width: Math.max(0, root.width - x - 16)
    text: root.output
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlMediaCaptionSize
    elide: Text.ElideRight
  }

  Text {
    id: title

    x: 16
    y: 42
    width: Math.max(0, play.x - x - 12)
    text: Media.active ? Media.title : "Nothing playing"
    color: Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlMediaTitleSize
    font.weight: Theme.weightSemi
    elide: Text.ElideRight
  }

  Text {
    x: title.x
    y: 70
    width: title.width
    visible: Media.artist !== ""
    text: Media.artist
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlMediaArtistSize
    elide: Text.ElideRight
  }

  Rectangle {
    id: play

    x: root.width - width - 16
    y: 32
    width: Theme.controlMediaPlaySize
    height: Theme.controlMediaPlaySize
    radius: height / 2
    Accessible.role: Accessible.Button
    Accessible.name: Media.playing ? "Pause" : "Play"
    Accessible.focusable: true
    Accessible.focused: playHover.activeFocus
    Accessible.onPressAction: if (Media.active)
      Media.toggle()
    color: Theme.withAlpha(Theme.text, playHover.containsMouse ? 1 : 0.94)
    scale: playHover.pressed ? 0.97 : 1

    Behavior on color {
      Tint {}
    }

    Behavior on scale {
      Morph { duration: Theme.morphState }
    }

    Text {
      anchors.centerIn: parent
      text: Media.playing ? Icons.pause : Icons.play
      color: Theme.inkOnAccent
      font.family: Theme.iconFont
      font.pixelSize: 20
    }

    MouseArea {
      id: playHover

      anchors.fill: parent
      hoverEnabled: true
      enabled: Media.active
      activeFocusOnTab: true
      cursorShape: Qt.PointingHandCursor
      onPressed: playHover.forceActiveFocus()
      onClicked: Media.toggle()
    }
  }

  component Skip: Text {
    property alias hovered: skipHover.containsMouse
    property string accessibleName: ""

    signal activated

    y: 104
    width: Theme.controlMediaSkipSize
    height: Theme.controlMediaSkipSize
    color: hovered ? Theme.text : Theme.withAlpha(Theme.text, 0.75)
    scale: skipHover.pressed ? 0.95 : 1
    font.family: Theme.iconFont
    font.pixelSize: Theme.controlMediaSkipSize
    Accessible.role: Accessible.Button
    Accessible.name: accessibleName
    Accessible.focusable: true
    Accessible.focused: skipHover.activeFocus

    Behavior on color {
      Tint {}
    }

    Behavior on scale {
      Morph { duration: Theme.morphState }
    }
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter

    MouseArea {
      id: skipHover

      anchors.fill: parent
      anchors.margins: -6
      hoverEnabled: true
      enabled: Media.active
      activeFocusOnTab: true
      cursorShape: Qt.PointingHandCursor
      onPressed: skipHover.forceActiveFocus()
      onClicked: parent.activated()
    }
  }

  Skip {
    id: previous

    x: 16
    text: Icons.previous
    accessibleName: "Previous track"
    onActivated: Media.previous()
  }

  Skip {
    id: next

    x: root.width - width - 16
    text: Icons.next
    accessibleName: "Next track"
    onActivated: Media.next()
  }

  // The bar is a seek target too, so its hit area is taller than the 3 px it draws.
  Item {
    id: progress

    x: previous.x + previous.width + 12
    y: previous.y
    width: Math.max(0, next.x - 12 - x)
    height: previous.height

    Rectangle {
      y: (parent.height - height) / 2
      width: parent.width
      height: Theme.controlMediaProgressHeight
      radius: height / 2
      color: Theme.withAlpha(Theme.text, 0.22)

      Rectangle {
        width: parent.width * Media.progress
        height: parent.height
        radius: height / 2
        color: Theme.withAlpha(Theme.text, 0.95)
      }
    }

    MouseArea {
      anchors.fill: parent
      enabled: Media.seekable
      cursorShape: Qt.PointingHandCursor
      onPressed: function (event) {
        Media.seek(event.x / Math.max(1, width));
      }
      onPositionChanged: function (event) {
        if (pressed)
          Media.seek(event.x / Math.max(1, width));
      }
    }
  }
}
