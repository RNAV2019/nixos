import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons

// A floating surface that shows the wallpaper through itself.
//
// Each surface takes the crop of the desktop background that sits directly
// behind it, blurs it, and lays a surface tint over the top, so the wallpaper
// blooms through wherever it has detail and reads as flat ink wherever it does
// not. The crop is aligned to the surface's real position on screen, which is
// why the caller has to say where its window sits: screenOffsetX and
// screenOffsetY are that window's own top-left, in screen coordinates.
//
// Only a pill-sized region of the wallpaper is ever rendered. The full-size
// Image is clipped by a layered crop item first, so the blur runs over a few
// thousand pixels rather than the whole screen.
Item {
  id: root

  property int surfaceRadius: height / 2
  property real screenOffsetX: 0
  property real screenOffsetY: 0

  default property alias content: contentHolder.data

  // Overscan for the blur, which would otherwise sample transparency in from
  // outside the crop and fade the surface edges.
  readonly property int blurPad: 40

  readonly property string wallpaper: "file://" + Quickshell.env("HOME") + "/.local/share/wallpaper/current"

  readonly property var win: root.QsWindow.window
  readonly property int screenWidth: win && win.screen ? win.screen.width : 0
  readonly property int screenHeight: win && win.screen ? win.screen.height : 0

  // mapToItem is a one-shot; the watcher is what re-runs this binding when the
  // bar relayouts underneath the surface.
  TransformWatcher {
    id: watcher

    a: root.win ? root.win.contentItem : null
    b: root
  }

  readonly property point screenPos: {
    watcher.transform;
    if (!root.win || !root.win.contentItem)
      return Qt.point(0, 0);
    var p = root.mapToItem(root.win.contentItem, 0, 0);
    return Qt.point(p.x + root.screenOffsetX, p.y + root.screenOffsetY);
  }

  // The drop shadow is cast by an opaque copy of the pill, drawn underneath
  // everything else. MultiEffect pads its own bounds, so the shadow is free to
  // fall outside the surface.
  Rectangle {
    anchors.fill: parent
    radius: root.surfaceRadius
    color: Theme.base
    layer.enabled: true
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: "#000000"
      shadowOpacity: Theme.surfaceShadowAlpha
      shadowVerticalOffset: Theme.surfaceShadowOffset
      shadowBlur: Theme.surfaceShadowBlur
      blurMax: Theme.surfaceShadowMax
    }
  }

  // The frosted stack, masked to the pill radius in one pass at the end.
  Item {
    id: frost

    anchors.fill: parent
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: mask
    }

    // Ground the surface, so it still reads correctly before the wallpaper has
    // loaded or if the file is missing.
    Rectangle {
      anchors.fill: parent
      color: Theme.base
    }

    // Clipped first, layered second: the layer's texture is only as large as
    // this item, so the wallpaper past the crop never reaches the blur.
    Item {
      id: crop

      x: -root.blurPad
      y: -root.blurPad
      width: root.width + root.blurPad * 2
      height: root.height + root.blurPad * 2
      clip: true
      visible: false
      layer.enabled: true

      Image {
        // Positioned so the screen's origin lands where it really is relative
        // to this crop.
        x: root.blurPad - root.screenPos.x
        y: root.blurPad - root.screenPos.y
        width: root.screenWidth
        height: root.screenHeight
        source: root.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
      }
    }

    MultiEffect {
      x: crop.x
      y: crop.y
      width: crop.width
      height: crop.height
      source: crop
      blurEnabled: true
      blur: Theme.surfaceBlur
      blurMax: Theme.surfaceBlurMax
      blurMultiplier: 1
    }

    Rectangle {
      anchors.fill: parent
      color: Theme.withAlpha(Theme.surfaceTint, Theme.surfaceTintAlpha)
    }
  }

  Item {
    id: mask

    anchors.fill: parent
    visible: false
    layer.enabled: true

    Rectangle {
      anchors.fill: parent
      radius: root.surfaceRadius
      color: "black"
    }
  }

  // A hairline that separates the surface from a wallpaper of the same ink.
  Rectangle {
    anchors.fill: parent
    radius: root.surfaceRadius
    color: "transparent"
    border.width: 1
    border.color: Theme.withAlpha(Theme.surfaceBorder, Theme.surfaceBorderAlpha)
  }

  Item {
    id: contentHolder

    anchors.fill: parent
  }
}
