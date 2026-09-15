import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services

// One island surface: the window, the shape, and the handover. Seven surfaces stand in for
// the island, and each used to carry an identical copy of what is in this file.
//
// A caller supplies a key, an open shape, and a body:
//
//   IslandSurface {
//     key: "launcher"
//     openWidth: Theme.launcherWidth
//     openHeight: ...
//     openRadius: Theme.launcherRadius
//
//     Item { ... }
//   }
//
// The surface must be the delegate of the caller's own Variants rather than wrapping one,
// because a default-property body assigned to a Variants would belong to the Variants.
PanelWindow {
  id: win

  required property var modelData

  // Identity on the bus, and the layer-shell namespace. One of "launcher",
  // "control", "wallpaper", "recorder", "calendar", "session", "profiles".
  property string key: ""

  // The shape this surface settles at. Any of the three may be a live binding.
  property real openWidth: 0
  property real openHeight: 0
  property real openRadius: Theme.controlRadius

  property bool open: false
  // Some keyboard-first surfaces need to hide the pointer for their entire mapped window, not
  // only over the opaque card. The guard below accepts no buttons and only owns the cursor.
  property bool hideCursor: false
  property alias origin: origin
  property alias surface: surface

  // Everything the surface draws, laid out at its final metrics from the first frame and
  // uncovered by the growing shape, which makes the open read as a reveal rather than a fade.
  default property alias content: bodyHolder.data

  // Raised inside show(), before the island is claimed, so a caller can reset the state its
  // own open shape is computed from.
  signal opening

  // Every key the surface takes, before Escape is considered. Anything left unaccepted falls
  // through to the Escape below, which closes.
  signal keyPressed(var event)

  // The shape this surface grows out of, and the handover protocol it follows when another
  // surface takes the island.
  IslandOrigin {
    id: origin

    window: win
  }

  // Raised while the island is being handed to another surface. The still held for it rides
  // the taker's own morph, and keeps the final cut to the pill instant.
  property bool handover: false

  // Raised for the length of a handover, and what the still's two fades are driven from.
  // Separate from `handover`, which also disables the shape Behaviors.
  property bool farewell: false

  // True while this surface's contents are arriving out of another surface rather than out
  // of the island. Panel to panel there is no clip to reveal them, so they enter on their
  // own delayed schedule instead.
  readonly property bool entering: win.open && origin.handedOver

  // The few pixels the arriving contents settle through, signed by the direction the height
  // is travelling, so they move with the box. Set once per open, because openHeight is
  // usually a live binding.
  property real enterTravel: 0

  readonly property bool focused: Monitors.isFocused(win.screen)

  // True from the moment the shape starts growing until it is back to pill size, or until a
  // frozen still is taken down: the whole time the bar must keep its island hidden.
  readonly property bool showing: open || origin.held || surface.width > origin.collapsedWidth + 0.5
  readonly property bool morphRunning: widthSpring.running || heightSpring.running

  function show() {
    win.opening();
    handover = false;
    farewell = false;
    // Take the island. The ordering, the card and the handover mailbox live in
    // Ui/IslandOrigin.qml; the arguments are the morph the holder rides with this surface.
    origin.claim(win.openWidth, win.openHeight, win.openRadius, Theme.morphSurface);
    // Read after the claim, which is what fills in the shape this surface grows out of.
    enterTravel = origin.handedOver ? (win.openHeight >= origin.fromHeight ? -Theme.morphEnterTravel : Theme.morphEnterTravel) : 0;
    open = true;
  }

  function hide() {
    origin.release();
    // The travel belongs to the arrival: a close is a close whichever shape it grew out of.
    enterTravel = 0;
    open = false;
  }

  // Giving the island up to the surface that claimed it. The still is what the eye sees
  // until the taker's first frame lands.
  function dismiss() {
    origin.publish(surface.width, surface.height, surface.surfaceRadius);
    origin.hold(surface.width, surface.height, surface.surfaceRadius);
    handover = true;
    farewell = true;
    open = false;
  }

  screen: modelData
  visible: !Bus.locking && showing
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

  // Hyprland focuses an OnDemand surface when it first maps, but not when an already mapped
  // one goes None -> OnDemand, and this surface stays mapped through its close animation.
  // Exclusive covers that, but cannot be permanent: it would route every pointer event here.
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
      // Layer-shell hands the surface focus, but Qt still needs an active-focus target inside it.
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
      // The close is off screen; the shape Behaviors are live again for the next open. A held
      // still unmaps with handover still raised, which keeps its cut to the pill instant.
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

    // Another surface taking the island takes it from here. On this output it is growing in
    // this surface's place, so this one cuts; on any other it takes its own close.
    function onIslandClaimed(screen) {
      if (!win.open)
        return;
      if (win.screen && screen === win.screen.name)
        win.dismiss();
      else
        win.hide();
    }
  }

  // A click anywhere off the surface dismisses. The surface sits on top and takes its own.
  MouseArea {
    anchors.fill: parent
    enabled: win.open
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: win.hide()
  }

  // Gated on visibility, not `enabled`: Qt Quick's cursor lookup skips hidden items but not
  // disabled ones, so a merely disabled guard blanked the pointer on every surface.
  MouseArea {
    id: cursorGuard

    anchors.fill: parent
    z: 1000
    visible: win.open && win.hideCursor
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    cursorShape: Qt.BlankCursor
  }

  FrostedSurface {
    id: surface

    // The still bridges the mapping gap with pixels. The taker's window maps in single-digit
    // milliseconds but does not present a frame for 147-216 ms, and the bar keeps its pill
    // stood down throughout, so cutting the whole surface here left a hole.
    //
    // So the still fades in two parts. Its contents go first and go quickly, because the
    // taker's blur samples what is behind it and the old panel's text is the one thing it
    // must not find. The ground stays through the gap: a flat tint is what that blur wants.
    contentOpacity: win.farewell ? 0 : 1
    backdropOpacity: win.farewell ? 0 : 1

    // Only the fade out is animated. The reset happens off screen, between one open and the
    // next, and has to land in a single frame.
    //
    // Guarded on `handover` and not on `farewell`. A Behavior's `enabled` is a binding like
    // any other, and on the frame `farewell` changes the value binding is evaluated before
    // it, so a guard read off `farewell` answers for the frame before and got both ends
    // wrong. Both call sites move `handover` immediately before `farewell`.
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
          duration: Theme.duration(Theme.morphGroundFade)
          easing.type: Easing.OutCubic
        }
      }
    }

    x: (win.width - width) / 2
    y: Theme.barMarginTop

    clipContent: true

    implicitWidth: win.open ? win.openWidth : origin.held ? origin.heldWidth : origin.originWidth
    implicitHeight: win.open ? win.openHeight : origin.held ? origin.heldHeight : origin.originHeight

    // Read off the height rather than travelling; see Bar/Island.qml. The radius asked for is
    // this surface's own in every state including the close, but a still riding a taker's
    // morph asks for the taker's, as it does for the target shape and duration.
    surfaceRadius: Math.min(height / 2, origin.held ? origin.heldRadius : win.openRadius)

    Behavior on implicitWidth {
      enabled: !Theme.reduceMotion && !origin.snapping && (!win.handover || origin.held)

      SurfaceSpring {
        id: widthSpring
      }
    }

    Behavior on implicitHeight {
      enabled: !Theme.reduceMotion && !origin.snapping && (!win.handover || origin.held)

      SurfaceSpring {
        id: heightSpring
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

    // The complete collapsed pill carried over from the shape this surface grew out of.
    CollapsedPill {
      anchors.fill: parent
      origin: origin
      shown: !win.open && !origin.held
    }

    // Everything the surface draws, cross-faded against that clock. Nothing inside fades on
    // its own; the growing shape uncovers it.
    //
    // Out of another panel there is no growing shape to uncover anything, so the contents
    // wait for the box to be most of the way to its target and then arrive, settling through
    // a few pixels: the container leads and the contents follow.
    Item {
      id: bodyHolder

      anchors.fill: parent
      opacity: win.open || origin.held ? 1 : 0
      visible: opacity > 0

      // Taken off the fade rather than run beside it, so the two cannot fall out of step and
      // the reveal out of the pill, where the travel is zero, is left untouched.
      transform: Translate {
        y: (1 - bodyHolder.opacity) * win.enterTravel
      }

      Behavior on opacity {
        enabled: !origin.held

        SequentialAnimation {
          PauseAnimation {
            duration: win.entering ? Theme.duration(Theme.morphEnterDelay) : 0
          }

          NumberAnimation {
            duration: win.entering ? Theme.duration(Theme.morphEnter) : Theme.duration(Theme.morphContent)
            easing.type: Easing.OutCubic
          }
        }
      }
    }
  }
}
