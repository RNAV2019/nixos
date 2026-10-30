import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services

// One island surface: the window, the shape, and the handover. Caller supplies a key,
// openWidth/openHeight/openRadius and a body; must be the caller's Variants delegate.
PanelWindow {
  id: win

  required property var modelData

  // Identity on the bus, and the layer-shell namespace. One of "launcher",
  // "control", "wallpaper", "theme", "recorder", "calendar", "session", "profiles".
  property string key: ""

  // The shape this surface settles at. Any of the three may be a live binding.
  property real openWidth: 0
  property real openHeight: 0
  property real openRadius: Theme.controlRadius

  property bool open: false
  // Whether the surface holds the keyboard while open. Result cards that arrive unasked turn it
  // off until the pointer is on them, so typing elsewhere is not stolen.
  property bool keyboard: true
  // Some keyboard-first surfaces hide the pointer for their whole mapped window, not just the
  // card. The guard below accepts no buttons and only owns the cursor.
  property bool hideCursor: false
  // A surface that spawns its own toplevel (the Nearby panel's file chooser) must not have
  // the full-screen window swallow input aimed at it. When set, only the card is a target;
  // clicks outside fall through to whatever is below.
  property bool passThrough: false
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
    frameItem: surface
    presentable: !Bus.locking && win.tall
  }

  // Raised while the island is being handed to another surface. The still held for it rides
  // the taker's own morph, and keeps the final cut to the pill instant.
  property bool handover: false

  // Raised for the length of a handover, and what the still's two fades are driven from.
  // Separate from `handover`, which also disables the shape Behaviors.
  property bool farewell: false

  // True while contents arrive out of another surface rather than the island. Panel to panel
  // there is no clip to reveal them, so they enter on their own delayed schedule.
  readonly property bool entering: win.open && origin.handedOver

  // The few pixels arriving contents settle through, signed by the height's direction so they
  // move with the box. Set once per open, since openHeight is usually a live binding.
  property real enterTravel: 0

  readonly property bool focused: Monitors.isFocused(win.screen)

  // True from the moment the shape starts growing until it is at rest on the pill, or until a
  // frozen still is taken down. At rest, not merely back: the spring dips under the pill and
  // returns, and the bar's own pill must not appear in the middle of that.
  readonly property bool morphRunning: widthSpring.running || heightSpring.running
  // Read off the spring, never the snapped size: snapping depends on the window it would flip.
  readonly property bool showing: open || origin.held || morphRunning || Math.abs(widthSpring.value - origin.collapsedWidth) > 0.5 || Math.abs(heightSpring.value - Theme.barHeight) > 0.5

  // The whole time the bar must keep its island hidden: from this surface's first frame on
  // screen, never before it, so the pill is never taken away with nothing drawn in its place.
  readonly property bool covering: showing && (origin.presented || !open)

  // Shared gate for the shape springs: no motion when asked, no travel when the surface was
  // snapped onto a shape, and no travelling while a still is being cut away from.
  // Parked, a change of pill (media starting, a recording) is taken at once: a parked surface
  // must not wake to travel between two pills nobody can see.
  readonly property bool geometryAnimEnabled: !Theme.reduceMotion && !origin.snapping && !win.parked && (!win.handover || origin.held)

  // Raised inside show() around the claim, so this surface's own claim is not taken for
  // another surface's.
  property bool claiming: false

  // Whether the still left by a dismiss carries the contents it was showing. A surface already
  // on its way down had faded them, and must not bring them back to fade them again.
  property bool stillCarriesBody: false

  function show() {
    win.opening();
    handover = false;
    farewell = false;
    stillCarriesBody = false;
    // Take the island. The ordering, the card and the handover mailbox live in
    // Ui/IslandOrigin.qml; the arguments are the morph the holder rides with this surface.
    claiming = true;
    origin.claim(win.openWidth, win.openHeight, win.openRadius, Theme.morphSurface);
    claiming = false;
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

  // Giving the island up to the surface that claimed it, open or still on its way down. The
  // still is what the eye sees until the taker's first frame lands.
  function dismiss() {
    var w = surface.implicitWidth;
    var h = surface.implicitHeight;
    origin.publish(surface.width, surface.height, surface.surfaceRadius);
    stillCarriesBody = win.open;
    handover = true;
    farewell = true;
    origin.hold(w, h, surface.surfaceRadius);
    open = false;
  }

  // The shape. The still first: hold() seats it on the shape it was wearing before the surface
  // lets go of its open one, which is what starts it from rest; see Ui/IslandOrigin.qml. An
  // open waits for its first frame on screen, so that frame is the shape it grows out of, and
  // the still riding along starts on the same frame, waiting on the same report.
  MorphSpring {
    id: widthSpring

    animate: win.geometryAnimEnabled
    target: origin.held ? origin.heldWidth : win.open && origin.presented ? win.openWidth : origin.originWidth
  }

  MorphSpring {
    id: heightSpring

    animate: win.geometryAnimEnabled
    target: origin.held ? origin.heldHeight : win.open && origin.presented ? win.openHeight : origin.originHeight
  }

  // ---- the window ----
  //
  // Quickshell destroys a layer surface's window when it is hidden and builds a new one on
  // show, and that new window's first frame was 35-216 ms late, which every open paid. So the
  // window outlives the close: parked, a 1 px sliver drawing nothing and taking no input, it
  // costs a strip of buffer, and the next open is a resize, a frame or two.

  readonly property real fullHeight: win.screen ? win.screen.height : 0

  // Down from the moment the surface starts showing; raised a beat after it stops, once the
  // bar's pill has had a frame to land under it.
  property bool parked: true

  // Unparked and the compositor has made the window full height. Nothing is drawn before:
  // a frame committed at the sliver while the resize is pending gets no frame callback from
  // Hyprland, and Qt then holds the first full-size frame for its 100 ms callback timeout.
  readonly property bool tall: !parked && fullHeight > 0 && win.height >= fullHeight - 1

  Timer {
    id: parkDelay

    interval: Theme.surfacePark
    onTriggered: {
      if (win.showing)
        return;
      win.parked = true;
      // The close is off screen; the shape Behaviors are live again for the next open. A held
      // still parks with handover still raised, which keeps its cut to the pill instant.
      win.handover = false;
      win.farewell = false;
      win.stillCarriesBody = false;
      retainTimer.restart();
    }
  }

  // A parked window still holds a render context (~8 MiB of GPU memory each, nine surfaces
  // an output), so one left unused for a while is let go. The next open makes a new window and
  // waits out its first frame with the pill still up, which is slower but never bare.
  property bool retained: false

  Timer {
    id: retainTimer

    interval: Theme.surfaceRetain
    onTriggered: if (win.parked)
      win.retained = false
  }

  screen: modelData
  // Mapped while in use and for a while after, parked; unmapped for the lock, so its snapshot
  // never holds shell UI.
  visible: !Bus.locking && (win.showing || win.retained)
  color: "transparent"

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "quickshell-" + win.key

  anchors {
    top: true
    left: true
    right: true
  }

  implicitHeight: win.parked ? 1 : win.fullHeight

  exclusionMode: ExclusionMode.Ignore

  // Open, the whole window is the surface's input region, and a click off the card hits the
  // dismiss MouseArea below; passThrough narrows it to the card so a spawned picker stays
  // live. Not open (closing, a still, parked), nothing: the shape on its way out must not
  // swallow the clicks of whoever is below.
  mask: !win.open ? emptyMask : win.passThrough ? cardMask : null

  Region {
    id: emptyMask
  }

  Region {
    id: cardMask

    item: surface
  }

  // Hyprland focuses an OnDemand surface when it first maps but not on None -> OnDemand, and
  // this one stays mapped through its close. Exclusive covers it, but would eat all pointers.
  property bool focusPrimed: false

  WlrLayershell.keyboardFocus: win.open && win.keyboard ? (win.focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

  Timer {
    id: focusPrime

    interval: 75
    onTriggered: win.focusPrimed = true
  }

  // A surface that was keyless and wants the keyboard now is primed as a fresh open is.
  onKeyboardChanged: {
    if (open && keyboard) {
      focusPrimed = false;
      focusPrime.restart();
      Qt.callLater(function () {
        if (win.open)
          keys.forceActiveFocus();
      });
    }
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
      parkDelay.stop();
      retainTimer.stop();
      retained = true;
      parked = false;
      Bus.setOwner(win.key, win.screen ? win.screen.name : "");
    } else {
      parkDelay.restart();
      if (win.screen && Bus.ownerOf(win.key) === win.screen.name)
        Bus.setOwner(win.key, "");
    }
  }

  onCoveringChanged: {
    if (covering)
      Bus.setCover(win.key, win.screen ? win.screen.name : "");
    else if (win.screen && Bus.covers[win.key] === win.screen.name)
      Bus.setCover(win.key, "");
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
    // this surface's place, so this one cuts, even on its way down: left to finish its close,
    // it would shrink beside the taker growing out of the pill. On any other output an open
    // one takes its own close and one already closing carries on.
    function onIslandClaimed(screen) {
      if (win.claiming || origin.held)
        return;
      var here = win.screen && screen === win.screen.name;
      if (here && win.showing && !win.parked)
        win.dismiss();
      else if (win.open)
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

  // The surface draws no input of its own, so a click inside it that misses every control
  // would fall through to the dismiss area above. This takes those clicks and does nothing.
  MouseArea {
    anchors.fill: surface
    enabled: win.open
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
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

    // Parked, nothing is drawn, including on the frames before the window is down to its
    // sliver; a still that has finished is already transparent, a close is on the bar's pill.
    visible: win.tall

    // The still fades in two parts: its contents at once, its ground only once the taker has
    // a frame on screen to show through it, so the island's spot is never left bare.
    contentOpacity: win.farewell ? 0 : 1
    backdropOpacity: win.farewell && origin.takerPresented ? 0 : 1

    // Only the fade out is animated; the reset lands off screen in one frame. Guarded on
    // `handover`, not `farewell`: a Behavior's enabled binding is evaluated before farewell changes.
    Behavior on contentOpacity {
      enabled: win.handover

      Morph {
        duration: Theme.morphFarewell
      }
    }

    Behavior on backdropOpacity {
      enabled: win.handover

      Morph {
        duration: Theme.duration(Theme.morphGroundFade)
      }
    }

    x: snap((win.width - width) / 2 + origin.offsetX)
    y: snap(Theme.barMarginTop + origin.offsetY)

    clipContent: true

    implicitWidth: widthSpring.value
    implicitHeight: heightSpring.value

    // Read off the height rather than travelling; see Bar/Island.qml. A still riding a taker's
    // morph asks for the taker's radius, as it does for target shape and duration.
    surfaceRadius: Math.min(height / 2, origin.held ? origin.heldRadius : win.openRadius)

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

    // The complete collapsed pill carried over from the shape this surface grew out of. Up on
    // the first frame of an open out of the island, so that frame matches the pill it covers;
    // a shape from another surface or the drop well had no clock, so none is brought.
    CollapsedPill {
      anchors.fill: parent
      origin: origin
      shown: !origin.held && !(win.open && (origin.presented || origin.handedOver || !origin.fromClock))
    }

    // Everything the surface draws, cross-faded against that clock; nothing inside fades on
    // its own. Out of another panel there is no clip, so contents arrive late and settle a few px.
    // Both wait for the first frame, so a slow one cannot eat the choreography.
    Item {
      id: bodyHolder

      anchors.fill: parent
      opacity: (win.open && origin.presented) || (origin.held && win.stillCarriesBody) ? 1 : 0
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

          Morph {
            duration: win.entering ? Theme.duration(Theme.morphEnter) : Theme.duration(Theme.morphContent)
          }
        }
      }
    }
  }

  // Content that must draw past the card, as a sibling of the surface: the card's clip is a
  // mask on the surface, not the window, so a child here is never trimmed. The window is
  // full-screen, so it can sit anywhere on the output. It carries no input of its own.
  property alias overlay: overlayHolder.data

  Item {
    id: overlayHolder

    anchors.fill: parent
  }
}
