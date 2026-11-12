import QtQuick
import QtQuick.Effects
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Services
import qs.Ui

Item {
  id: root

  // A content-morph anchor (Ui/MorphScan.js): what it is, and what pairs it across panels.
  property string morphRole: "media"
  property string morphKey: "media"
  property var morphSlot: undefined

  readonly property var sink: Pipewire.defaultAudioSink

  readonly property string output: {
    if (!sink)
      return "No output";
    return sink.nickname || sink.description || sink.name;
  }

  readonly property bool hasArt: art.hasArt

  implicitHeight: Theme.controlMediaHeight

  PwObjectTracker {
    objects: root.sink ? [root.sink] : []
  }

  // Masked together so the blur cannot bleed past the card's corners.
  RoundedClip {
    id: ground

    anchors.fill: parent
    radius: Theme.controlMediaRadius

    Rectangle {
      anchors.fill: parent
      color: Theme.surfaceRaised
    }

    // Overscanned: a blur sampling the card's own edge fades it out.
    Item {
      id: crop

      x: -40
      y: -40
      width: parent.width + 80
      height: parent.height + 80
      visible: false
      layer.enabled: true

      // A new cover fades in over the last one here, under the blur.
      ArtFade {
        id: art

        anchors.fill: parent
        source: Media.artUrl
      }
    }

    MultiEffect {
      x: crop.x
      y: crop.y
      width: crop.width
      height: crop.height
      source: crop
      // The blurred cover arrives and leaves on a fade, with the scrim below following it.
      opacity: art.presence
      visible: opacity > 0
      blurEnabled: true
      blur: 0.6
      blurMax: 48
      blurMultiplier: 1
    }

    Rectangle {
      anchors.fill: parent
      color: Theme.withAlpha(Theme.canvas, 0.2 + 0.38 * art.presence)
    }
  }

  Text {
    id: outputGlyph

    x: 16
    y: 13
    text: Volume.glyphFor(root.sink)
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
    y: 36
    width: Math.max(0, transport.x - x - 12)
    text: Media.active ? Media.title : "Nothing playing"
    color: Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlMediaTitleSize
    font.weight: Theme.weightSemi
    elide: Text.ElideRight
  }

  Text {
    x: title.x
    y: 61
    width: title.width
    visible: Media.artist !== ""
    text: Media.artist
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlMediaArtistSize
    elide: Text.ElideRight
  }

  // Previous, play/pause and next as three equal discs, centred on the title block.
  Row {
    id: transport

    x: root.width - width - 16
    y: 56 - height / 2
    spacing: Theme.controlMediaButtonGap

    Repeater {
      model: [
        {
          kind: "previous",
          name: "Previous track"
        },
        {
          kind: "toggle",
          name: "Play or pause"
        },
        {
          kind: "next",
          name: "Next track"
        }
      ]

      Button {
        id: button

        required property var modelData

        kind: Button.Disc
        size: Button.Large
        // Large enough that play's triangle keeps the ink the hand-drawn one had (about 13 x 15).
        iconSize: 30
        icon: Icons.transportGlyph(button.modelData.kind === "toggle" ? (Media.playing ? "pause" : "play") : button.modelData.kind)
        enabled: Media.active
        accessibleName: modelData.kind === "toggle" ? (Media.playing ? "Pause" : "Play") : modelData.name
        onClicked: {
          if (modelData.kind === "previous")
            Media.previous();
          else if (modelData.kind === "next")
            Media.next();
          else
            Media.toggle();
        }
      }
    }
  }

  // The scrub bar (Ui/MediaScrub.qml).
  MediaScrub {
    x: 16
    width: root.width - 32
    height: parent.height
    trackY: Theme.controlMediaTrackY
    timeY: Theme.controlMediaTimeY
  }
}
