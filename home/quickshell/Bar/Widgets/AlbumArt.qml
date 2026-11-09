import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Services
import qs.Ui

Item {
  id: root

  component Bloom: Rectangle {
    property color blobColor: Theme.iris
    property real blobOpacity: 1

    radius: Math.min(width, height) / 2
    color: Theme.withAlpha(blobColor, blobOpacity)
    layer.enabled: true
    layer.effect: MultiEffect {
      blurEnabled: true
      blur: 0.45
      blurMax: 32
    }
  }

  property real cornerRadius: Theme.islandArtRadius * (width / Theme.islandArtSize)

  readonly property bool hasArt: art.hasArt

  implicitWidth: Theme.islandArtSize
  implicitHeight: Theme.islandArtSize

  RoundedClip {
    anchors.fill: parent
    radius: root.cornerRadius

    Rectangle {
      anchors.fill: parent
      color: Theme.overlay
    }

    Item {
      anchors.fill: parent
      // Under the art until it has wholly arrived, so the two cross-fade.
      visible: art.presence < 1

      Bloom {
        blobColor: Theme.love
        blobOpacity: 0.75
        x: -10
        y: -14
        width: 44
        height: 40
      }

      Bloom {
        blobColor: Theme.gold
        blobOpacity: 0.6
        x: 20
        y: 8
        width: 40
        height: 40
      }

      Bloom {
        blobColor: Theme.iris
        blobOpacity: 0.7
        x: -6
        y: 22
        width: 34
        height: 32
      }
    }

    // A new cover fades in over the last, and a first or a lost one over the blooms.
    ArtFade {
      id: art

      anchors.fill: parent
      source: Media.artUrl
      opacity: presence
      visible: opacity > 0
    }

    Rectangle {
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: 4
      width: 16
      height: width
      radius: width / 2
      color: Theme.withAlpha(Theme.canvas, 0.72)
      visible: Media.active

      StrokeIcon {
        anchors.centerIn: parent
        size: 9
        path: Media.playing ? Icons.pause : Icons.play
        color: Theme.text
      }
    }
  }
}
