import QtQuick
import qs.Commons

// The phone satellite's body: the shape's right cap and the disc, joined by a liquid neck while it
// holds and by two rounded stubs after it breaks, as one shape over the disc's drop shadow, drawn
// by Shaders/satellite.frag. The properties are the shader's uniforms, in the parent's coordinates;
// the item itself is only as big as the bud (the cap's end, the swell, the neck, the disc) plus
// `aa`, so the window is never covered whole.
//
// The bar draws it while the satellite rides the pill or the open card, and a transient surface's
// window draws it while the satellite rides that transient (Ui/SatelliteLayer.qml hosts both).
ShaderEffect {
  id: root

  // The shape the bud leaves: x of its right edge and the y of its centre, its half height, and
  // the corner radius of that end.
  property point pillEdge: Qt.point(0, 0)
  property real pillHalfH: Theme.barHeight / 2
  property real capRadius: Theme.barHeight / 2
  // The disc: centre x, centre y, radius.
  property vector3d disc: Qt.vector3d(0, 0, 0)
  // The radius of the ball that fillets the cap into the disc (the neck), 0 for none.
  property real neck: 0
  // The broken ends after the neck snaps: how far each reaches, and its radius.
  property point stub: Qt.point(0, 0)
  // How far the cap swells while a disc is drawn in.
  property real bulge: 0
  // No outline: the shell's surfaces float on a shadow instead (Ui/DropShadow.qml).
  property real outlineWidth: 0
  // Premultiplied, as the shader composes them: the ground and the outline over it.
  property color fill: Theme.surface
  property color outline: "transparent"
  property real aa: 1
  property real shadowSigma: Theme.surfaceShadowSigma
  property real shadowOffsetY: Theme.surfaceShadowOffsetY
  property real shadowStrength: Theme.surfaceShadowAlpha
  // How far the disc's shadow reaches past the bud.
  readonly property real shadowRoom: shadowStrength > 0 ? Theme.surfaceShadowRoom : 0

  // Where the bud lies: from inside the cap (the fillet is faintly there too, over the pill's
  // top) to the disc's far side, and as high as the taller of the two plus the swell.
  readonly property real boundReach: Math.max(capRadius, disc.z) + bulge + 2 * aa + shadowRoom
  readonly property real boundLeft: pillEdge.x - 2.5 * capRadius - 2 * aa
  readonly property real boundRight: disc.x + disc.z + 2 * aa + shadowRoom

  // The sizes are snapped to whole device pixels by the caller's aa (1 / ratio).
  x: Math.floor(boundLeft / aa) * aa
  y: Math.floor((disc.y - boundReach) / aa) * aa
  width: Math.ceil((boundRight - x) / aa) * aa
  height: Math.ceil((disc.y + boundReach - y) / aa) * aa

  property size itemSize: Qt.size(width, height)
  property point origin: Qt.point(x, y)

  fragmentShader: Qt.resolvedUrl("../Shaders/satellite.frag.qsb")
}
