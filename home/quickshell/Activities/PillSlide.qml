import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Ui

// The pill's slide beside its satellites, published on the Bus (pillSlideX) for the bar's
// island and for every surface that grows out of it. The pill and the circles are centred as a
// pair, so each circle pushes the pill left by half a circle and a gap; arriving and leaving
// it travels on the one spring in the shell that overshoots (Theme.satelliteSlide*, a few px).
// Folding away for another surface is not that: the pill re-centres on the morph's own
// critically damped spring, in step with the surface that is growing over it.
Scope {
  id: root

  MorphSpring {
    id: slide

    target: Activities.slideFolded ? 0 : -Activities.slideCount * (Theme.satelliteSize + Theme.satelliteGap) / 2
    omega: Activities.slideFolded ? Theme.morphOmega : Theme.satelliteSlideOmega
    zeta: Activities.slideFolded ? 1 : Theme.satelliteSlideZeta
  }

  Binding {
    target: Bus
    property: "pillSlideX"
    value: slide.value
  }

  Binding {
    target: Bus
    property: "pillSlideScreen"
    value: Activities.home
  }
}
