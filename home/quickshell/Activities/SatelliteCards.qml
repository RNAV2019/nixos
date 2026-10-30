import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The hover card of a satellite (Penpot "Ariadne / Activity card"). It hangs 8 px under its
// circle, centred on it and kept 24 px off the screen edge, and grows out of the circle's own
// 36 px shape: width and height on one critically damped spring, the corner read off the
// height and never animated. The contents are laid out at the card's final size and uncovered by
// the growing clip, then arrive after a short delay and settle ten pixels down.
//
// Which card is up is Activities.cardKey, set by hovering (Activities.hoverSatellite) with the
// island's open and close delays, and held while the pointer is on the circle or on the card.
// This is not an island surface: it claims nothing and hands nothing over; the circles fold
// and take it with them when something else wants the island.
Variants {
  model: Quickshell.screens

  PanelWindow {
    id: win

    required property var modelData

    readonly property string screenName: win.screen ? win.screen.name : ""
    readonly property bool mine: win.screenName !== "" && win.screenName === Activities.home

    // What is on show, latched so the close has contents to shrink away with.
    property string shownKey: ""
    readonly property var activity: win.shownKey === "" || win.shownKey === "+" ? null : Activities.find(win.shownKey)

    readonly property bool open: win.mine && Activities.cardKey !== "" && !Bus.locking

    onOpenChanged: if (open)
      win.shownKey = Activities.cardKey

    Connections {
      target: Activities

      function onCardKeyChanged() {
        if (win.open)
          win.shownKey = Activities.cardKey;
      }
    }

    // The card's own Component: the activity's, the overflow list, or the generic one.
    readonly property Component source: {
      if (win.shownKey === "+")
        return listCard;
      if (win.activity === null)
        return null;
      return win.activity.card !== null ? win.activity.card : genericCard;
    }

    Component {
      id: listCard

      ListCard {}
    }

    Component {
      id: genericCard

      GenericCard {
        activity: win.activity
      }
    }

    // The size the card settles at, once the loader has built it.
    readonly property real cardWidth: body.item ? body.item.implicitWidth : 0
    readonly property real cardHeight: body.item ? body.item.implicitHeight : 0

    readonly property real circle: Theme.satelliteSize
    readonly property real fromX: Activities.anchorX
    readonly property real fromY: Activities.anchorY
    readonly property real toX: Math.max(Theme.panelSideMargin, Math.min(win.width - Theme.panelSideMargin - cardWidth, fromX + circle / 2 - cardWidth / 2))
    readonly property real toY: fromY + circle + Theme.activityCardGap

    readonly property real fullHeight: Theme.barMarginTop + Theme.oledShiftMax + circle + Theme.activityCardGap + Theme.activityCardMaxHeight + Theme.oledShiftMax

    property bool parked: true
    property bool retained: false
    readonly property bool tall: !parked && win.height >= fullHeight - 1

    readonly property bool morphRunning: widthSpring.running || heightSpring.running
    // Read off the springs, never the snapped size, which depends on the window it would flip.
    readonly property bool showing: open || morphRunning || Math.abs(widthSpring.value - win.circle) > 0.5 || Math.abs(heightSpring.value - win.circle) > 0.5

    onShowingChanged: {
      if (showing) {
        parkDelay.stop();
        retainTimer.stop();
        retained = true;
        parked = false;
      } else {
        parkDelay.restart();
      }
    }

    // A closed card keeps its window a sliver for a while, so the next hover is a resize and
    // not a new window; see Ui/TransientSurface.qml.
    Timer {
      id: parkDelay

      interval: Theme.surfacePark
      onTriggered: {
        if (win.showing)
          return;
        win.parked = true;
        win.shownKey = "";
        retainTimer.restart();
      }
    }

    Timer {
      id: retainTimer

      interval: Theme.surfaceRetain
      onTriggered: if (win.parked)
        win.retained = false
    }

    screen: modelData
    visible: !Bus.locking && win.mine && (win.showing || win.retained)
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-activity-card"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
      top: true
      left: true
      right: true
    }

    implicitHeight: win.parked ? 1 : win.fullHeight
    exclusionMode: ExclusionMode.Ignore

    // Only the card itself takes the pointer.
    mask: win.showing && win.tall ? cardMask : emptyMask

    Region {
      id: emptyMask
    }

    Region {
      id: cardMask

      item: surface
    }

    MorphSpring {
      id: widthSpring

      animate: !Theme.reduceMotion
      target: win.open && win.tall && win.cardWidth > 0 ? win.cardWidth : win.circle
    }

    MorphSpring {
      id: heightSpring

      animate: !Theme.reduceMotion
      target: win.open && win.tall && win.cardHeight > 0 ? win.cardHeight : win.circle
    }

    // How far along the growth is, 0 the circle and 1 the card, on each axis.
    readonly property real progressX: win.cardWidth > win.circle ? Theme.clamp01((widthSpring.value - win.circle) / (win.cardWidth - win.circle)) : 0
    readonly property real progressY: win.cardHeight > win.circle ? Theme.clamp01((heightSpring.value - win.circle) / (win.cardHeight - win.circle)) : 0

    FrostedSurface {
      id: surface

      visible: win.tall && (win.open || win.morphRunning)

      x: snap(win.fromX + (win.toX - win.fromX) * win.progressX)
      y: snap(win.fromY + (win.toY - win.fromY) * win.progressY)
      implicitWidth: widthSpring.value
      implicitHeight: heightSpring.value
      clipContent: true
      surfaceRadius: Math.min(height / 2, Theme.activityCardRadius)
      // Its ground comes in as it leaves the circle, so the circle's own ring and reading are not
      // blanked for the first frames of the growth.
      backdropOpacity: Theme.clamp01(Math.max(win.progressX, win.progressY) * 4)

      HoverHandler {
        onHoveredChanged: Activities.hoverCard(hovered)
      }

      // Laid out at its final place on the screen; the surface grows over it.
      Item {
        id: bodyHolder

        x: surface.snap(win.toX) - surface.x
        y: surface.snap(win.toY) - surface.y
        width: win.cardWidth
        height: win.cardHeight
        opacity: win.open && win.tall ? 1 : 0
        visible: opacity > 0

        transform: Translate {
          y: (1 - bodyHolder.opacity) * -Theme.morphEnterTravel
        }

        Behavior on opacity {
          SequentialAnimation {
            PauseAnimation {
              duration: win.open ? Theme.morphEnterDelay : 0
            }

            Morph {
              duration: win.open ? Theme.morphEnter : Theme.morphContent
            }
          }
        }

        Loader {
          id: body

          sourceComponent: win.source
        }
      }
    }
  }
}
