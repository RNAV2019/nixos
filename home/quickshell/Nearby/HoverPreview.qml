import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Services
import qs.Ui

// A small preview that trails the cursor while a row under "Received" is hovered: the picture
// for an image, the first lines for a text file, the file's glyph otherwise. It sits below and
// to the right of the pointer and chases it on a slightly under-damped spring - it accelerates
// after the cursor, overshoots a touch and settles - rather than being glued to it. It is a
// sibling of the panel card (IslandSurface.overlay), so the card's clip never trims it, and its
// target is kept on screen instead. It never takes input.
Item {
  id: root

  property bool active: false
  // An absolute path.
  property string path: ""
  // The cursor, in this item's parent's coordinates.
  property real anchorX: 0
  property real anchorY: 0

  z: 1000

  readonly property string kind: Nearby.fileKind(path)
  readonly property bool picture: Nearby.isPreviewableImage(path)
  readonly property bool ready: picture ? pic.status === Image.Ready : true

  // The card takes the picture's aspect, its long edge capped; anything else is a fixed card.
  readonly property real maxEdge: Theme.nearbyPreviewMax
  readonly property real naturalW: pic.implicitWidth
  readonly property real naturalH: pic.implicitHeight
  readonly property real cardW: picture && pic.status === Image.Ready && naturalW > 0 ? (naturalW >= naturalH ? maxEdge : maxEdge * naturalW / naturalH) : kind === "text" ? maxEdge : 132
  readonly property real cardH: picture && pic.status === Image.Ready && naturalW > 0 ? (naturalW >= naturalH ? maxEdge * naturalH / naturalW : maxEdge) : kind === "text" ? 150 : 132

  width: cardW
  height: cardH

  // Down and to the right of the pointer; flipped to the other side of it near an edge.
  readonly property real offset: Theme.nearbyPreviewOffset
  readonly property real targetX: {
    var w = parent ? parent.width : 1e6;
    var tx = anchorX + offset;
    if (tx + cardW > w - 8)
      tx = anchorX - offset - cardW;
    return Math.max(8, tx);
  }
  readonly property real targetY: {
    var h = parent ? parent.height : 1e6;
    var ty = anchorY + offset;
    if (ty + cardH > h - 8)
      ty = anchorY - offset - cardH;
    return Math.max(8, ty);
  }

  // The spring state. Position integrates velocity, velocity integrates a force pulling toward
  // the target and a drag against motion - so the card speeds up after a moving cursor and
  // slows into place once it stops, never jumping.
  property real posX: 0
  property real posY: 0
  property real velX: 0
  property real velY: 0

  x: posX
  y: posY

  function snap() {
    posX = targetX;
    posY = targetY;
    velX = 0;
    velY = 0;
  }

  function step(dt) {
    var k = Theme.nearbyPreviewStiffness;
    var c = 2 * Theme.nearbyPreviewDamping * Math.sqrt(k);
    // Fixed 4 ms sub-steps keep the integration stable through a dropped frame.
    var left = Math.min(dt, 0.1);
    while (left > 0) {
      var h = Math.min(0.004, left);
      velX += (k * (targetX - posX) - c * velX) * h;
      velY += (k * (targetY - posY) - c * velY) * h;
      posX += velX * h;
      posY += velY * h;
      left -= h;
    }
  }

  FrameAnimation {
    running: root.visible && !Theme.reduceMotion
    onTriggered: root.step(frameTime)
  }

  // Under reduced motion the card simply sits at its target.
  Binding {
    when: Theme.reduceMotion
    root.posX: root.targetX
    root.posY: root.targetY
  }

  // A card appearing from nothing starts where it belongs rather than flying in from 0,0.
  onActiveChanged: if (active && opacity < 0.05)
    snap()

  visible: opacity > 0
  opacity: active && path !== "" && ready ? 1 : 0
  scale: 0.94 + 0.06 * opacity
  transformOrigin: Item.TopLeft

  Behavior on opacity {
    Morph {
      duration: Theme.duration(Theme.nearbyPreviewFade)
    }
  }

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
      color: Theme.surfaceRaised
    }

    Image {
      id: pic

      anchors.fill: parent
      visible: root.picture
      source: root.picture && root.path !== "" ? "file://" + root.path : ""
      asynchronous: true
      cache: true
      sourceSize.width: Theme.nearbyPreviewMax * 2
      fillMode: Image.PreserveAspectCrop
    }

    Text {
      visible: root.kind === "text"
      x: 12
      y: 10
      width: parent.width - 24
      height: parent.height - 20
      clip: true
      text: peek.text
      color: Theme.inkSecondary
      font.family: Theme.monoFont
      font.pixelSize: 10
      wrapMode: Text.NoWrap
      elide: Text.ElideRight
    }

    StrokeIcon {
      visible: !root.picture && root.kind !== "text"
      anchors.centerIn: parent
      anchors.verticalCenterOffset: -10
      size: 40
      strokeWidth: 1.8
      path: Nearby.glyphFor(root.kind)
      color: Nearby.inkFor(root.kind)
    }

    Text {
      visible: !root.picture && root.kind !== "text"
      anchors.horizontalCenter: parent.horizontalCenter
      y: parent.height - 34
      width: parent.width - 20
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideMiddle
      text: Nearby.extOf(root.path).toUpperCase()
      color: Theme.inkTertiary
      font.family: Theme.uiFont
      font.pixelSize: 11
      font.weight: Theme.weightSemi
    }
  }

  Item {
    id: mask

    anchors.fill: parent
    visible: false
    layer.enabled: true

    Rectangle {
      anchors.fill: parent
      radius: Theme.nearbyRowRadius
      color: "black"
    }
  }

  // The edge rides on top of the masked content, so the mask never cuts it.
  Rectangle {
    anchors.fill: parent
    radius: Theme.nearbyRowRadius
    color: "transparent"
    border.width: 1
    border.color: Theme.withAlpha(Theme.separator, 0.7)
  }

  FilePeek {
    id: peek

    path: root.kind === "text" && root.path !== "" ? root.path : ""
    lines: 14
    bytes: 2048
  }
}
