import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services

// One island surface: the window, the shape, and the handover.
//
// Seven surfaces stand in for the island - the launcher, the control centre,
// the calendar, the wallpaper picker, the recorder picker, the power menu and
// the profiles card - and every one of them used to carry its own copy of this
// file's contents. Not similar copies: identical ones. All seven `dismiss()`
// bodies matched byte for byte, all seven had the same 75 ms focus prime, the
// same shape Behaviors with the same guard expression, the same
// `showing` definition, the same off-surface dismiss area, and the same
// `onIslandClaimed` handler. Roughly nine hundred lines of it.
//
// The one thing that genuinely differed was the morph duration, and the
// motion pass collapsed those six values into Theme.morphSurface, because at
// 60 fps they were all the same duration wearing different numbers. With that
// gone there was nothing left to vary, so this is the whole of it.
//
// A caller supplies a key, an open shape, and a body:
//
//   Variants {
//     model: Quickshell.screens
//
//     IslandSurface {
//       key: "launcher"
//       openWidth: Theme.launcherWidth
//       openHeight: ...
//       openRadius: Theme.launcherRadius
//
//       Item { ... }
//     }
//   }
//
// The surface must be the delegate of the caller's own Variants rather than
// wrapping one, because a default-property body assigned to a Variants would
// belong to the Variants and not to its per-screen delegate.
PanelWindow {
  id: win

  required property var modelData

  // Identity on the bus, and the layer-shell namespace. One of "launcher",
  // "control", "wallpaper", "recorder", "calendar", "session", "profiles".
  property string key: ""

  // The shape this surface settles at. Any of the three may be a binding that
  // changes while the surface is open; the height usually is.
  property real openWidth: 0
  property real openHeight: 0
  property real openRadius: Theme.controlRadius

  property bool open: false
  property alias origin: origin
  property alias surface: surface

  // Everything the surface draws. Laid out at its final metrics from the first
  // frame and uncovered by the growing shape, which is what makes the open
  // read as a reveal rather than a fade.
  default property alias content: bodyHolder.data

  // Raised inside show(), before the island is claimed, so a caller can reset
  // the state that its own open shape is computed from.
  signal opening

  // Every key the surface takes, before Escape is considered. A caller that
  // accepts the event owns it; anything left unaccepted falls through to the
  // Escape below, which closes.
  signal keyPressed(var event)

  // The shape this surface grows out of, and the handover protocol it follows
  // when another surface takes the island: adopt the island's card, claim,
  // take the shape the holder was wearing.
  IslandOrigin {
    id: origin

    window: win
  }

  // Raised while the island is being handed to another surface. While the
  // handover's still is held, this surface's shape rides the taker's own
  // morph; handover is also what keeps the final cut to the pill - once the
  // still is taken down, covered by the taker - instant.
  property bool handover: false

  // Raised for the length of a handover, and what the still's two fades are
  // driven from. Separate from `handover` because that one is also what
  // disables the shape Behaviors, and is left raised while the still unmaps.
  property bool farewell: false

  // True while this surface's contents are arriving out of another surface
  // rather than out of the island. Panel to panel there is no clip to reveal
  // them, so they enter on their own delayed schedule instead; growing out of
  // the pill is left exactly as it was measured.
  readonly property bool entering: win.open && origin.handedOver

  // The few pixels the arriving contents settle through, signed by the
  // direction the height is travelling: down out of a shorter panel, up out of
  // a taller one, so the contents move with the box rather than against it.
  // Set once per open, because openHeight is usually a live binding.
  property real enterTravel: 0

  readonly property bool focused: Monitors.isFocused(win.screen)

  // True from the moment the shape starts growing until it is back to pill
  // size - or until the frozen still it left for a taker is taken down -
  // which is the whole time the bar must keep its island hidden.
  readonly property bool showing: open || origin.held || surface.width > origin.collapsedWidth + 0.5

  function show() {
    win.opening();
    handover = false;
    farewell = false;
    // Take the island. The ordering, the card, the handover mailbox and the
    // still the holder leaves behind all live in Ui/IslandOrigin.qml; the
    // four arguments are the morph this surface is about to travel, which the
    // holder rides with it.
    origin.claim(win.openWidth, win.openHeight, win.openRadius, Theme.morphSurface);
    // Read after the claim, because the claim is what fills in the shape this
    // surface is growing out of.
    enterTravel = origin.handedOver ? (win.openHeight >= origin.fromHeight ? -Theme.morphEnterTravel : Theme.morphEnterTravel) : 0;
    open = true;
  }

  function hide() {
    origin.release();
    // The travel belongs to the arrival. A close is a close whichever shape
    // this surface grew out of, so it does not drift on the way down.
    enterTravel = 0;
    open = false;
  }

  // Giving the island up to the surface that claimed it. The still this leaves
  // behind is what the eye sees until the taker's first frame lands.
  function dismiss() {
    origin.publish(surface.width, surface.height);
    origin.hold(surface.width, surface.height, surface.surfaceRadius);
    handover = true;
    farewell = true;
    open = false;
  }

  screen: modelData
  visible: showing
  color: "transparent"

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "quickshell-" + win.key

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  exclusionMode: ExclusionMode.Ignore

  // Hyprland focuses an OnDemand surface when it first maps, but not when an
  // already-mapped one goes None -> OnDemand, and this surface stays mapped
  // through its close animation. Exclusive covers the second case; staying
  // Exclusive is not an option, because it would route every pointer event on
  // every output here.
  property bool focusPrimed: false

  WlrLayershell.keyboardFocus: win.open ? (win.focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

  Timer {
    id: focusPrime

    interval: 75
    onTriggered: win.focusPrimed = true
  }

  onOpenChanged: {
    if (open) {
      focusPrimed = false;
      focusPrime.restart();
      // Layer-shell hands the surface focus, but Qt still needs an
      // active-focus target inside it before the input sees a key.
      Qt.callLater(function () {
        if (win.open)
          keys.forceActiveFocus();
      });
    } else {
      focusPrime.stop();
      focusPrimed = false;
    }
  }

  onShowingChanged: {
    if (showing) {
      Bus.setOwner(win.key, win.screen ? win.screen.name : "");
    } else {
      // The close is off screen; the shape Behaviors are live again for the
      // next open. A held still unmaps with handover still raised, which is
      // what keeps its cut to the pill instant.
      win.handover = false;
      win.farewell = false;
      if (win.screen && Bus.ownerOf(win.key) === win.screen.name)
        Bus.setOwner(win.key, "");
    }
  }

  Connections {
    target: Bus

    function onSurfaceToggled(key) {
      if (key !== win.key)
        return;
      if (win.open)
        win.hide();
      else if (win.focused)
        win.show();
    }

    function onSurfaceClosed(key) {
      if (key === win.key)
        win.hide();
    }

    // Another surface taking the island takes it from here. On this output it
    // is growing in this surface's place, so this one cuts; on any other
    // output nothing is growing here, so this one takes its own close.
    function onIslandClaimed(screen) {
      if (!win.open)
        return;
      if (win.screen && screen === win.screen.name)
        win.dismiss();
      else
        win.hide();
    }
  }

  // A click anywhere off the surface dismisses. The surface sits on top of
  // this and takes its own clicks.
  MouseArea {
    anchors.fill: parent
    enabled: win.open
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: win.hide()
  }

  FrostedSurface {
    id: surface

    // The still bridges the mapping gap before the taker appears, and it does
    // it with pixels. Cutting the whole surface here is what left a hole: the
    // taker's window maps in single-digit milliseconds but does not present a
    // frame for 147-216 ms, and for that whole stretch nothing at all was
    // painted in the island's place - the still was transparent, the taker was
    // not there yet, and the bar keeps its pill stood down throughout.
    //
    // So the still fades in two parts instead. Its contents go first and go
    // quickly, because the taker's blur samples whatever is behind it and the
    // old panel's text is the one thing it must not find there. Its ground
    // stays through the gap and comes off afterwards, and a flat tint is what
    // the taker's blur wants to find anyway.
    contentOpacity: win.farewell ? 0 : 1
    backdropOpacity: win.farewell ? 0 : 1

    // Only the fade out is animated. The reset happens off screen, between one
    // open and the next, and has to land in a single frame.
    //
    // Guarded on `handover` and not on `farewell`, even though `farewell` is
    // what the two values above are bound to. A Behavior's `enabled` is a
    // binding like any other, and on the frame `farewell` changes the value
    // binding is evaluated before it, so a guard read off `farewell` answers
    // for the frame before. That got both ends wrong: the fade out was written
    // while the guard still said false and cut instead of fading, and the
    // reset was written while it still said true and ran that schedule
    // backwards - the contents fading in over a ground still 130 ms from
    // coming back. That is the panel with no background under it, seen on a
    // fast switch back to a surface still holding its own still. Both call
    // sites move `handover` immediately before `farewell`, so this guard is
    // settled by the time the values are written.
    Behavior on contentOpacity {
      enabled: win.handover

      Morph {
        duration: Theme.morphFarewell
      }
    }

    Behavior on backdropOpacity {
      enabled: win.handover

      SequentialAnimation {
        PauseAnimation {
          duration: Theme.morphGround
        }

        NumberAnimation {
          duration: Theme.morphGroundFade
          easing.type: Easing.Bezier
          easing.bezierCurve: Theme.morphCurve
        }
      }
    }

    x: (win.width - width) / 2
    y: Theme.barMarginTop

    clipContent: true

    implicitWidth: win.open ? win.openWidth : origin.held ? origin.heldWidth : origin.originWidth
    implicitHeight: win.open ? win.openHeight : origin.held ? origin.heldHeight : origin.originHeight

    // Read off the height rather than travelling; see Bar/Island.qml. The
    // radius asked for is this surface's own in every state including the
    // close, because on the way back down the shape is still this surface's
    // until it is short enough for the stadium to take over. A still riding a
    // taker's morph asks for the taker's instead, the same way it takes the
    // taker's target shape and duration.
    surfaceRadius: Math.min(height / 2, origin.held ? origin.heldRadius : win.openRadius)

    Behavior on implicitWidth {
      enabled: !origin.snapping && (!win.handover || origin.held)

      Morph {
        duration: origin.held ? origin.heldDuration : Theme.morphSurface
      }
    }

    Behavior on implicitHeight {
      enabled: !origin.snapping && (!win.handover || origin.held)

      Morph {
        duration: origin.held ? origin.heldDuration : Theme.morphSurface
      }
    }

    Item {
      id: keys

      anchors.fill: parent
      focus: true

      Keys.onPressed: function (event) {
        win.keyPressed(event);
        if (event.accepted)
          return;
        if (event.key === Qt.Key_Escape) {
          win.hide();
          event.accepted = true;
        }
      }
    }

    // The clock carried over from the shape this surface grew out of; see
    // Ui/IslandClock.qml.
    IslandClock {
      anchors.fill: parent
      origin: origin
      shown: !win.open && !origin.held
    }

    // Everything the surface draws, cross-faded against that clock on the
    // short clock the island uses for its own contents. Nothing inside fades
    // on its own; the growing shape uncovers it.
    //
    // Out of another panel there is no growing shape to uncover anything, so
    // the contents wait for the box to be most of the way to its target and
    // then arrive, settling through a few pixels as they come. The container
    // leads and the contents follow, rather than the contents being at rest
    // two thirds of a morph before the container is.
    Item {
      id: bodyHolder

      anchors.fill: parent
      opacity: win.open || origin.held ? 1 : 0
      visible: opacity > 0

      // Taken off the fade rather than run beside it, so the two cannot fall
      // out of step and the reveal out of the pill, where the travel is zero,
      // is left untouched.
      transform: Translate {
        y: (1 - bodyHolder.opacity) * win.enterTravel
      }

      Behavior on opacity {
        enabled: !origin.held

        SequentialAnimation {
          PauseAnimation {
            duration: win.entering ? Theme.morphEnterDelay : 0
          }

          NumberAnimation {
            duration: win.entering ? Theme.morphEnter : Theme.morphContent
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.morphCurve
          }
        }
      }
    }
  }
}
