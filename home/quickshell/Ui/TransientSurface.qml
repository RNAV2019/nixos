import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services

// One transient island surface: the OSD, a notification toast, the sharing pill, the dictation
// pill. They come and go on their own, so nothing toggles them: the owner binds `wanted`, and
// the window grows out of the island, hands it over and comes back by itself. The window, the
// still and the presentation handshake follow Ui/IslandSurface.qml; see the notes there.
//
// They take turns by `rank` (Bus.transientWants): OSD 4, dictation 3, a sharing request 2, a
// toast 1, sharing progress 0. The highest wanting an output has the island, and one outranked
// waits rather than being knocked out. When the higher one lets go, the waiting one takes over
// from it as a handover, growing out of the shape it leaves, rather than the first shrinking to
// the pill and the second growing back out of it.
PanelWindow {
  id: win

  required property var modelData

  // Identity on the bus and in the layer-shell namespace: "osd", "notify", "sharing", "dictation".
  property string key: ""
  property string layerNamespace: "quickshell-" + win.key
  property int rank: 0

  // Bound by the owner: this surface wants the island on this output, other transients aside.
  property bool wanted: false

  // The shape this surface settles at. Any of the three may be a live binding.
  property real openWidth: 0
  property real openHeight: 0
  property real openRadius: Theme.controlRadius

  // Whether the card takes the pointer while open. Off, the window is click-through throughout.
  property bool cardInput: true

  // Whether the card takes the keyboard. Never by default; a card with a field in it asks to
  // have it on demand, which is the compositor handing it focus when the field is clicked.
  property int keyboardFocus: WlrKeyboardFocus.None

  // The card swiped aside and faded, for a surface that can be dismissed by hand.
  property real cardOffset: 0
  property real cardOpacity: 1

  property bool open: false
  property alias origin: origin
  property alias surface: surface

  // Everything the surface draws, laid out at its final metrics and uncovered by the shape.
  default property alias content: bodyHolder.data

  // Raised inside show(), before the island is claimed, so the owner can latch what its open
  // shape is computed from.
  signal opening

  // Raised when another surface took the island from this one.
  signal dismissed

  readonly property bool focused: Monitors.isFocused(win.screen)
  readonly property string screenName: win.screen ? win.screen.name : ""

  readonly property bool outranked: Bus.transientOutranked(win.key, win.screenName, win.rank)
  readonly property bool wantsOpen: win.wanted && !win.outranked

  IslandOrigin {
    id: origin

    window: win
    frameItem: surface
    presentable: !Bus.locking && win.tall
  }

  property bool handover: false
  property bool farewell: false
  property bool claiming: false
  property bool stillCarriesBody: false
  property real enterTravel: 0

  readonly property bool entering: win.open && origin.handedOver

  readonly property bool morphRunning: widthSpring.running || heightSpring.running
  // Read off the spring, never the snapped size: snapping depends on the window it would flip.
  readonly property bool showing: open || origin.held || morphRunning || Math.abs(widthSpring.value - origin.collapsedWidth) > 0.5 || Math.abs(heightSpring.value - Theme.barHeight) > 0.5

  // From this surface's first frame on screen, never before, the bar keeps its pill hidden.
  readonly property bool covering: showing && (origin.presented || !open)

  readonly property bool geometryAnimEnabled: !Theme.reduceMotion && !origin.snapping && !win.parked && (!win.handover || origin.held)

  // ---- turns ----

  property string wantScreen: ""

  function syncWant() {
    if (win.wantScreen !== "" && win.wantScreen !== win.screenName)
      Bus.setTransientWant(win.key, win.wantScreen, -1);
    win.wantScreen = win.screenName;
    Bus.setTransientWant(win.key, win.screenName, win.wanted ? win.rank : -1);
  }

  onWantedChanged: syncWant()
  onRankChanged: syncWant()
  onScreenNameChanged: syncWant()
  Component.onCompleted: syncWant()
  Component.onDestruction: Bus.setTransientWant(win.key, win.wantScreen, -1)

  // Decided a turn later, never inside the change that prompted it: a want often moves in the
  // middle of another surface's claim (a panel cutting the OSD short frees the island for a
  // toast before that panel has registered as its owner), and a claim made from in there would
  // race the claim it is nested in.
  onWantsOpenChanged: evaluateLater.restart()

  Timer {
    id: evaluateLater

    interval: 0
    onTriggered: win.evaluate()
  }

  function evaluate() {
    if (Bus.locking)
      return;
    if (win.wantsOpen && !win.open) {
      win.show();
    } else if (!win.wantsOpen && win.open) {
      // Outranked, the surface that outranks this one claims the island in its own turn, and
      // the claim hands over from here. Shrinking first would put the pill between the two.
      if (win.wanted && win.outranked)
        yieldLater.restart();
      else
        win.hide();
    }
  }

  Timer {
    id: yieldLater

    interval: 0
    onTriggered: if (win.open && !win.wantsOpen)
      win.hide()
  }

  function show() {
    win.opening();
    handover = false;
    farewell = false;
    stillCarriesBody = false;
    claiming = true;
    origin.claim(win.openWidth, win.openHeight, win.openRadius, Theme.morphSurface);
    claiming = false;
    enterTravel = origin.handedOver ? (win.openHeight >= origin.fromHeight ? -Theme.morphEnterTravel : Theme.morphEnterTravel) : 0;
    open = true;
  }

  function hide() {
    origin.release();
    enterTravel = 0;
    open = false;
  }

  // Giving the island up to the surface that claimed it, open or on the way down. Still wanted,
  // this one comes back once the island is free again; see evaluate().
  function dismiss() {
    var w = surface.implicitWidth;
    var h = surface.implicitHeight;
    origin.publish(surface.width, surface.height, surface.surfaceRadius);
    stillCarriesBody = win.open;
    handover = true;
    farewell = true;
    origin.hold(w, h, surface.surfaceRadius);
    open = false;
    win.dismissed();
    // Whoever claimed registers itself in the same turn; if nothing did, the island is free.
    evaluateLater.restart();
  }

  // The still first, so hold() seats it from rest; an open waits for its first frame.
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
  // Full height while in use, so a still can ride any taker's shape, and a 1 px sliver drawing
  // nothing once parked, kept mapped a while so the next arrival is a resize, not a new window.

  readonly property real fullHeight: win.screen ? win.screen.height : 0

  property bool parked: true

  readonly property bool tall: !parked && fullHeight > 0 && win.height >= fullHeight - 1

  Timer {
    id: parkDelay

    interval: Theme.surfacePark
    onTriggered: {
      if (win.showing)
        return;
      win.parked = true;
      win.handover = false;
      win.farewell = false;
      win.stillCarriesBody = false;
      retainTimer.restart();
    }
  }

  property bool retained: false

  Timer {
    id: retainTimer

    interval: Theme.surfaceRetain
    onTriggered: if (win.parked)
      win.retained = false
  }

  screen: modelData
  visible: !Bus.locking && (win.showing || win.retained)
  color: "transparent"

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: win.layerNamespace
  WlrLayershell.keyboardFocus: win.keyboardFocus

  anchors {
    top: true
    left: true
    right: true
  }

  implicitHeight: win.parked ? 1 : win.fullHeight

  exclusionMode: ExclusionMode.Ignore

  // Only the open card is ever a target, and only for a surface with something to press. A
  // still, a close and the parked sliver take nothing, so the island underneath keeps its clicks.
  mask: win.open && win.cardInput ? cardMask : emptyMask

  Region {
    id: emptyMask
  }

  Region {
    id: cardMask

    item: surface
  }

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

  onCoveringChanged: {
    if (covering)
      Bus.setTransientScreen(win.key, win.screenName);
    else if (win.screenName !== "" && Bus.transientScreen(win.key) === win.screenName)
      Bus.setTransientScreen(win.key, "");
  }

  Connections {
    target: Bus

    function onSurfacesClosingForLock() {
      win.open = false;
      origin.release();
    }

    function onLockingChanged() {
      if (!Bus.locking)
        evaluateLater.restart();
    }

    // Another surface taking the island on this output grows in this one's place, so this one
    // cuts to a still, even on its way down; left to finish, it would shrink beside the taker.
    function onIslandClaimed(screen) {
      if (win.claiming || origin.held || screen !== win.screenName)
        return;
      if (win.showing && !win.parked)
        win.dismiss();
    }
  }

  FrostedSurface {
    id: surface

    visible: win.tall

    // The still fades in two parts: its contents at once, its ground only once the taker has a
    // frame on screen to show through it.
    contentOpacity: win.farewell ? 0 : 1
    backdropOpacity: win.farewell && origin.takerPresented ? 0 : 1

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

    x: snap((win.width - width) / 2 + origin.offsetX + win.cardOffset)
    opacity: win.cardOpacity
    y: snap(Theme.barMarginTop + origin.offsetY)

    clipContent: true

    implicitWidth: widthSpring.value
    implicitHeight: heightSpring.value

    // Read off the height rather than travelling; see Bar/Island.qml.
    surfaceRadius: Math.min(height / 2, origin.held ? origin.heldRadius : win.openRadius)

    // The collapsed pill carried over from the island, up until the first frame of an open
    // lands so that frame matches the pill it covers.
    CollapsedPill {
      anchors.fill: parent
      origin: origin
      shown: !origin.held && !(win.open && (origin.presented || origin.handedOver || !origin.fromClock))
    }

    Item {
      id: bodyHolder

      anchors.fill: parent
      opacity: (win.open && origin.presented) || (origin.held && win.stillCarriesBody) ? 1 : 0
      visible: opacity > 0

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
}
