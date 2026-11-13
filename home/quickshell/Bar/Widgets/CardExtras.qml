import QtQuick
import qs.Commons
import qs.Services
import qs.Ui

// What the open hover card carries besides what is playing and its clock: the date under the
// clock and, at the right, the weather, the system gauge and the battery ring. Laid out for a
// card the size of this item, about its midline. The bar's island draws it at its live shape
// (Bar/Island.qml), and a surface that grew out of the open card draws the same thing where
// the card stood (Ui/IslandSurfaceBase.qml), so the card's own never goes or comes back on a
// cut.
Item {
  id: root

  // Where the clock and the date start: the side blocks are clipped short of it.
  property real centreLeft: 0
  property date today
  // How far open the card is, 0 the pill and 1 the card: the date and the side blocks each
  // arrive on a stretch of it of their own, the side blocks with a short drift.
  property real openness: 1

  readonly property real dateShown: reveal(Theme.islandDateReveal)
  readonly property real sideShown: reveal(Theme.islandSideReveal)
  readonly property real sideFlight: Theme.islandSideFlight

  // A block's own stretch of the open, eased (as Bar/Island.qml reveal).
  function reveal(stretch) {
    var t = Theme.clamp01((openness - stretch[0]) / (stretch[1] - stretch[0]));
    return t * t * (3 - 2 * t);
  }

  readonly property real midline: height / 2
  readonly property real dateX: date.x
  readonly property real dateWidth: date.width

  // Board 02's gauges: the battery 16 px in from the right, system load beside it. Clipped
  // short of the clock, so nothing crosses it.
  Item {
    id: gauges

    x: root.width - root.centreLeft + 12
    width: Math.max(0, root.width - x)
    height: parent.height
    clip: true

    // The weather, built like a gauge without its ring: the sky's glyph where the ring's would
    // be and the temperature in the gap, on the gauges' own line. With no reading there is
    // nothing here, and the gauges stay where they are.
    Item {
      id: weather

      property real presence: Weather.available ? 1 : 0

      x: system.x - Theme.islandWeatherGap - width
      y: root.midline - height / 2
      width: Theme.islandWeatherWidth
      height: Theme.islandGaugeSize
      opacity: root.sideShown * presence
      visible: opacity > 0

      Behavior on presence {
        Morph {
          duration: Theme.stateSwap
        }
      }

      StrokeIcon {
        x: (parent.width - width) / 2
        y: parent.height / 2 - Theme.islandWeatherGlyphLift - height / 2
        size: Theme.islandWeatherGlyph
        path: Weather.glyph
        color: Theme.text
      }

      GaugeLabel {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.islandGaugeLabelY
        // A true minus below zero, as wide as a digit.
        text: (Weather.temperature < 0 ? "−" : "") + Math.abs(Weather.temperature) + "°"
      }
    }

    SystemGauge {
      id: system

      x: gauges.width - 16 - 12 - 2 * width + root.sideFlight * (1 - root.sideShown)
      y: root.midline - height / 2
      opacity: root.sideShown
    }

    StatusGauge {
      x: gauges.width - 16 - width + root.sideFlight * (1 - root.sideShown)
      y: root.midline - height / 2
      opacity: root.sideShown
    }
  }

  // The date arrives last, rising into place under the clock as it settles.
  Text {
    id: date

    x: (root.width - width) / 2
    y: root.midline + 13.5 - height / 2 + 6 * (1 - root.dateShown)
    opacity: root.dateShown
    text: Qt.formatDateTime(root.today, "ddd, d MMM")
    color: Theme.subtle
    font.family: Theme.uiFont
    font.pixelSize: Theme.islandCaptionSize
  }
}
