import QtQuick
import qs.Commons
import qs.Services

// The playing track's cover bled in from a surface's start edge: it fills this item, cropped
// to it, and runs out into the surface's ground under a gradient of that ground a pixel wider
// than the picture, so the words beside it stand on the ground and never on a cut edge. The
// surface's own rounded shape crops it; paused, it goes under a dim. With no cover there is
// nothing here at all (`presence`). The hover card's and the Now playing panel's are one anchor
// to a content morph, so the one grows into the other.
Item {
  id: root

  // A content-morph anchor (Ui/MorphScan.js): what it is, and what pairs it across surfaces.
  property string morphRole: "cover"
  property string morphKey: "media.cover"
  property var morphSlot: undefined
  // Leaving with no partner, it fades as the one picture it is, not a cover and a ground apart.
  readonly property bool morphGroup: true

  property string source: Media.artUrl
  property bool dimmed: Media.active && !Media.playing

  // How much picture there is, 0 with none: a new cover fades in over the last (Ui/ArtFade.qml).
  readonly property real presence: art.presence

  // One picture to whatever fades it: faded a child at a time, the cover showed through the
  // ground that covers its far end, which drew that end as a hard edge all the way out. Always
  // on, never by whether there is a cover: a layer going while its window takes a new
  // device-pixel ratio (when it first maps at a fractional scale, which also reloads the
  // picture) is an item deleted under Qt's walk of the scene, and that crashed the shell.
  layer.enabled: true

  ArtFade {
    id: art

    anchors.fill: parent
    source: root.source
    sourceSize: Qt.size(Theme.coverSourceSize, Theme.coverSourceSize)
    opacity: presence
    visible: opacity > 0
  }

  Rectangle {
    objectName: "dim"
    anchors.fill: parent
    color: "black"
    opacity: root.dimmed ? Theme.coverPausedDim * art.presence : 0
    visible: opacity > 0

    Behavior on opacity {
      Morph {
        duration: Theme.stateSwap
      }
    }
  }

  Rectangle {
    objectName: "fade"
    width: parent.width + 1
    height: parent.height
    opacity: art.presence
    visible: opacity > 0

    gradient: Gradient {
      orientation: Gradient.Horizontal

      GradientStop {
        position: 0
        color: Theme.withAlpha(Theme.surface, 0)
      }

      GradientStop {
        position: 0.42
        color: Theme.withAlpha(Theme.surface, 0.08)
      }

      GradientStop {
        position: 0.74
        color: Theme.withAlpha(Theme.surface, 0.72)
      }

      GradientStop {
        position: 1
        color: Theme.surface
      }
    }
  }
}
