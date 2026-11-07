import QtQuick
import qs.Commons

// The shell's drop shadow (Shaders/shadow.frag): a rounded rectangle the size of its parent,
// blurred by a Gaussian and offset down, so a surface floats over the desktop instead of being
// outlined against it. It is solved from the live size every frame, so it tracks a morph
// exactly, and the parent's own footprint is cut out of it, so a ground that fades never shows
// its shadow through itself.
//
// It reaches `room` past the parent on every side; the window must leave that much free or the
// shadow is cut off in a hard line. Drawn behind the parent (z -1).
ShaderEffect {
  id: root

  // The parent's corner radius.
  property real radius: 0
  property real strength: Theme.surfaceShadowAlpha
  property real sigma: Theme.surfaceShadowSigma
  property real offsetY: Theme.surfaceShadowOffsetY
  property real room: Theme.surfaceShadowRoom
  // Device pixels per item pixel, for the cut-out's antialiasing.
  property real pixelRatio: 1

  readonly property real shapeWidth: parent ? parent.width : 0
  readonly property real shapeHeight: parent ? parent.height : 0

  x: -room
  y: -room
  z: -1
  width: shapeWidth + room * 2
  height: shapeHeight + room * 2
  visible: strength > 0 && opacity > 0 && shapeWidth > 0 && shapeHeight > 0

  property size itemSize: Qt.size(width, height)
  property point boxOrigin: Qt.point(room, room)
  property size boxSize: Qt.size(shapeWidth, shapeHeight)
  property point offset: Qt.point(0, offsetY)
  property real aa: 1 / Math.max(1, pixelRatio)

  fragmentShader: Qt.resolvedUrl("../Shaders/shadow.frag.qsb")
}
