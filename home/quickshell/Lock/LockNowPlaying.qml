import QtQuick
import Quickshell.Widgets
import qs.Commons
import qs.Services
import qs.Ui

// The now-playing card above the login pill: art, title, artist, the three transport
// buttons and a read-only progress track. It talks to the player over MPRIS only, so the
// buttons work while the session is locked and the card never sees more than the track.
Item {
  id: root

  // The lock canvas's unit scale (its height / 1080), so the board's sizes carry over.
  property real ui: 1
  // Lets the IPC preview rehearse a paused card.
  property bool forcePaused: false

  function u(v) {
    return Math.round(v * root.ui);
  }

  function clock(seconds) {
    var s = Math.max(0, Math.floor(seconds));
    var m = Math.floor(s / 60);
    s = s % 60;
    return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
  }

  readonly property bool playing: Media.playing && !forcePaused
  readonly property bool hasArt: Media.artUrl !== "" && art.status === Image.Ready
  readonly property bool canPrevious: Media.player !== null && Media.player.canGoPrevious
  readonly property bool canNext: Media.player !== null && Media.player.canGoNext
  readonly property bool canToggle: Media.player !== null && Media.player.canPlay

  width: u(Theme.lockMediaWidth)
  height: u(Theme.lockMediaHeight)
  visible: Media.active

  // The progress bar is the only thing needing MPRIS polled, so the poll is tied to this card
  // actually showing: the preview keeps an unshown copy of the lock view alive.
  Binding {
    target: Media
    property: "trackPosition"
    value: true
    when: root.visible && root.opacity > 0
    restoreMode: Binding.RestoreBindingOrValue
  }

  Rectangle {
    anchors.fill: parent
    radius: root.u(Theme.lockMediaRadius)
    color: Theme.surface
    border.width: Math.max(1, Math.round(root.ui))
    border.color: Theme.surfaceOutline
  }

  Rectangle {
    id: artPlate

    x: root.u(Theme.lockMediaInset)
    y: root.u(Theme.lockMediaInset)
    width: root.u(Theme.islandArtSize)
    height: width
    radius: root.u(Theme.islandArtRadius)
    color: Theme.surfaceRaised

    ClippingRectangle {
      anchors.fill: parent
      radius: artPlate.radius
      color: "transparent"
      visible: root.hasArt

      Image {
        id: art

        anchors.fill: parent
        source: Media.artUrl
        sourceSize.width: width
        sourceSize.height: height
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
      }
    }
  }

  Text {
    x: root.u(Theme.lockMediaTextLeft)
    y: root.u(Theme.lockMediaTitleTop)
    width: transport.x - x - root.u(10)
    elide: Text.ElideRight
    text: Media.title
    color: Theme.inkPrimary
    font.family: Theme.uiFont
    font.weight: Theme.weightSemi
    font.pixelSize: root.u(Theme.lockMediaTitleSize)
    renderType: Text.QtRendering
  }

  Text {
    x: root.u(Theme.lockMediaTextLeft)
    y: root.u(Theme.lockMediaArtistTop)
    width: transport.x - x - root.u(10)
    elide: Text.ElideRight
    text: Media.artist
    color: Theme.inkTertiary
    font.family: Theme.uiFont
    font.weight: Theme.weightRegular
    font.pixelSize: root.u(Theme.lockMediaArtistSize)
    renderType: Text.QtRendering
  }

  // A button the player cannot honour is left out rather than drawn dead.
  Row {
    id: transport

    x: parent.width - root.u(Theme.lockMediaInset) - width
    y: root.u(Theme.lockMediaButtonTop)
    spacing: root.u(Theme.lockMediaButtonGap)

    Repeater {
      id: buttons

      model: ["previous", "toggle", "next"]

      Rectangle {
        id: button

        required property string modelData

        readonly property string icon: {
          if (modelData === "previous")
            return IconPaths.skipBack;
          if (modelData === "next")
            return IconPaths.skipForward;
          return root.playing ? IconPaths.pause : IconPaths.play;
        }

        function activate() {
          if (modelData === "previous")
            Media.previous();
          else if (modelData === "next")
            Media.next();
          else
            Media.toggle();
        }

        visible: modelData === "previous" ? root.canPrevious : modelData === "next" ? root.canNext : root.canToggle

        width: root.u(Theme.lockMediaButton)
        height: width
        radius: width / 2
        color: Theme.withAlpha(Theme.inkPrimary, press.pressed ? Theme.controlMediaButtonHoverAlpha : Theme.controlMediaButtonAlpha)

        Behavior on color {
          ColorAnimation {
            duration: Theme.duration(Theme.lockStateFade)
          }
        }

        StrokeIcon {
          anchors.centerIn: parent
          size: root.u(Theme.lockMediaGlyph)
          strokeWidth: 1.75 * root.ui
          color: Theme.inkPrimary
          path: button.icon
        }

        MouseArea {
          id: press

          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: button.activate()
        }
      }
    }
  }

  Text {
    x: root.u(Theme.lockMediaInset)
    y: root.u(Theme.lockMediaTimeTop)
    text: root.clock(Media.position)
    color: Theme.inkTertiary
    font.family: Theme.uiFont
    font.weight: Theme.weightRegular
    font.pixelSize: root.u(Theme.lockMediaTimeSize)
    renderType: Text.QtRendering
  }

  Text {
    x: parent.width - root.u(Theme.lockMediaInset) - width
    y: root.u(Theme.lockMediaTimeTop)
    visible: Media.length > 0
    text: root.clock(Media.length)
    color: Theme.inkTertiary
    font.family: Theme.uiFont
    font.weight: Theme.weightRegular
    font.pixelSize: root.u(Theme.lockMediaTimeSize)
    renderType: Text.QtRendering
  }

  // Read-only: the lock never scrubs.
  Rectangle {
    id: track

    x: root.u(Theme.lockMediaTrackInset)
    y: root.u(Theme.lockMediaTrackY)
    width: parent.width - 2 * x
    height: root.u(Theme.lockMediaTrackHeight)
    radius: height / 2
    color: Theme.withAlpha(Theme.inkPrimary, Theme.controlMediaTrackAlpha)

    Rectangle {
      width: track.width * Media.progress
      height: parent.height
      radius: height / 2
      color: root.playing ? Theme.accent : Theme.inkSecondary

      Behavior on color {
        ColorAnimation {
          duration: Theme.duration(Theme.lockStateFade)
        }
      }
    }
  }
}
