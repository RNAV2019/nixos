import QtQuick
import QtQuick.Shapes
import qs.Commons

// The island-gauge shell: the ring Shape carrying the track/value GaugeArc pair. Children
// the caller adds land inside the Shape, so centre glyphs and label companions are simply
// positioned against the same 48 px box. The label in the bottom gap is left to the caller
// so it can dress the reading its own way.
Shape {
  id: gauge

  // Fraction 0..1 shown by the value arc; the track always stays whole behind it.
  property real value: 0
  property color strokeColor: Theme.accent

  implicitWidth: Theme.islandGaugeSize
  implicitHeight: Theme.islandGaugeSize

  preferredRendererType: Shape.CurveRenderer

  GaugeArc {
    radius: Theme.islandGaugeRadius
    strokeColor: Theme.highlightMed
  }

  GaugeArc {
    radius: Theme.islandGaugeRadius
    value: gauge.value
    strokeColor: gauge.strokeColor
  }
}
