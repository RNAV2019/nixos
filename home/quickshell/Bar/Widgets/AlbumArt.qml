import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Services

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

  readonly property bool hasArt: Media.artUrl !== "" && art.status === Image.Ready

  implicitWidth: Theme.islandArtSize
  implicitHeight: Theme.islandArtSize

  Item {
    id: content

    anchors.fill: parent
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: mask
    }

    Rectangle {
      anchors.fill: parent
      color: Theme.overlay
    }

    Item {
      anchors.fill: parent
      visible: !root.hasArt

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

    Image {
      id: art

      anchors.fill: parent
      source: Media.artUrl
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: true
      visible: root.hasArt
    }

    Rectangle {
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: 4
      width: 16
      height: width
      radius: width / 2
      color: Theme.withAlpha(Theme.base, 0.72)
      visible: Media.active

      Text {
        anchors.centerIn: parent
        text: Media.playing ? Icons.pause : Icons.play
        color: Theme.text
        font.family: Theme.iconFont
        font.pixelSize: 9
      }
    }
  }

  Item {
    id: mask

    anchors.fill: parent
    visible: false
    layer.enabled: true

    Rectangle {
      anchors.fill: parent
      radius: root.cornerRadius
      color: "black"
    }
  }
}
