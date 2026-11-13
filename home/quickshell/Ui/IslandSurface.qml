import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// One island panel, opened by the user: a key on the bus toggles it, it takes the keyboard and
// a click off the card closes it. The window, the shape and the handover are
// Ui/IslandSurfaceBase.qml. Caller supplies a key, openWidth/openHeight/openRadius and a body;
// must be the caller's Variants delegate.
//
// A panel can also be asked for: an owner that binds `wanted` (the polkit prompt) has it open
// and closed with the want, as well as from the keyboard; see the notes in the base.
IslandSurfaceBase {
  id: win

  // Some keyboard-first surfaces hide the pointer for their whole mapped window, not just the
  // card. The guard below accepts no buttons and only owns the cursor.
  property bool hideCursor: false
  // Keyboard stays exclusive for as long as the surface is open, rather than handing over to
  // on-demand once the first focus has landed. For a prompt that must not lose its keys.
  property bool exclusiveKeyboard: false
  // A surface that spawns its own toplevel (the Nearby panel's file chooser) must not have
  // the full-screen window swallow input aimed at it. When set, only the card is a target;
  // clicks outside fall through to whatever is below.
  property bool passThrough: false
  // Whether a toggle may open it just now: a panel about something that comes and goes (what is
  // playing) is not opened onto nothing. Open, it still closes.
  property bool openable: true
  // The item that takes the keyboard when the surface opens, where it is not the surface itself:
  // a text field, so typing lands in it. Keys it leaves unaccepted still reach keyPressed.
  property Item focusTarget: null

  // Every key the surface takes, before Escape is considered: those pressed with the surface
  // itself focused, and those a focused content item left unaccepted. Anything left unaccepted
  // falls through to the Escape below, which closes.
  signal keyPressed(var event)

  closesElsewhere: true
  contentKeyTargets: [keys]

  // Open, the whole window is the surface's input region, and a click off the card hits the
  // dismiss MouseArea below; passThrough narrows it to the card so a spawned picker stays
  // live.
  openMask: win.passThrough ? win.cardMask : null

  // ---- where the pointer is, for a surface that goes back to the hover card ----
  //
  // A surface that grew out of the open hover card closes back into it only while the pointer
  // is on the card's place (Ui/IslandSurfaceBase.qml startReturn), and the card it uncovers
  // must then know whether the pointer is still on it. Neither window can simply ask: a
  // compositor sends no enter to a surface that turns up under a pointer at rest, so this
  // window hears nothing until the pointer moves after it opens, and the bar's hears nothing
  // until it moves after the card is back.

  // The hover card's place in this window.
  readonly property rect cardPlace: Qt.rect(surface.snap((win.width - Theme.islandExpandedWidth) / 2 + origin.offsetX), surface.snap(win.cardTop(Theme.islandExpandedHeight)), Theme.islandExpandedWidth, Theme.islandExpandedHeight)

  function onCardPlace(p) {
    return p.x >= cardPlace.x && p.x < cardPlace.x + cardPlace.width && p.y >= cardPlace.y && p.y < cardPlace.y + cardPlace.height;
  }

  // Whether this window has been told where the pointer is since it opened. Until then the
  // pointer is where the card last saw it (IslandOrigin.fromPointer).
  property bool pointerSeen: false

  pointerOnCard: win.pointerSeen ? pointer.hovered && win.onCardPlace(pointer.point.position) : origin.fromPointer

  // From the start of a return until the card knows where the pointer is, this window watches
  // everywhere but the card's place (`idleMask`; whole and drawing nothing once it has
  // parked, `keepsWindow`): the pointer seen there has left the card, however far it went in
  // one move, and the card is told. Seen on the card by the bar's own window, the card ends
  // the wait itself.
  property var watchedCard: null
  readonly property bool pointerWatch: !win.open && !win.pointerLeftCard && (win.returning || (win.watchedCard !== null && win.watchedCard.awaitingPointer === true))

  keepsWindow: win.pointerWatch
  idleMask: win.pointerWatch ? watchMask : null

  onReturningChanged: if (win.returning)
    win.watchedCard = win.returnCard

  // Everything but the card's place.
  Region {
    id: watchMask

    x: win.cardPlace.x
    y: win.cardPlace.y
    width: win.cardPlace.width
    height: win.cardPlace.height
    intersection: Intersection.Xor
  }

  // On the window's own root item, the parent of everything in it, never on an item laid over
  // the rest: hover is delivered to an item and its ancestors only, so a handler on an item on
  // top takes it from every control under it, while one on the root hears it after them all.
  HoverHandler {
    id: pointer

    parent: win.contentItem
    onPointChanged: win.pointerMoved()
    onHoveredChanged: win.pointerMoved()
  }

  function pointerMoved() {
    if (win.open) {
      win.pointerSeen = true;
      return;
    }
    if (!win.pointerWatch || !pointer.hovered || win.onCardPlace(pointer.point.position))
      return;
    // Off the card: the watch is over, and the card hears of it now if it is already back.
    var card = win.watchedCard;
    win.pointerLeftCard = true;
    if (Theme.motionLog)
      console.info("morph ev " + win.key + " pointerLeftCard returning=" + win.returning + " " + Date.now());
    if (card && !win.returning)
      card.pointerLeft();
  }

  // Hyprland focuses an OnDemand surface when it first maps but not on None -> OnDemand, and
  // this one stays mapped through its close. Exclusive covers it, but would eat all pointers.
  property bool focusPrimed: false

  WlrLayershell.keyboardFocus: win.open ? (win.focusPrimed && !win.exclusiveKeyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

  Timer {
    id: focusPrime

    // After the opening has come to rest: the change is a layer-surface commit, on which the compositor
    // reconfigures every layer surface and each of the shell's windows draws a frame the GUI thread
    // waits for, a visible hitch anywhere in the motion.
    interval: Theme.surfaceFocusPrime
    onTriggered: win.focusPrimed = true
  }

  onOpenChanged: {
    if (open) {
      pointerSeen = false;
      focusPrimed = false;
      focusPrime.restart();
      // Layer-shell hands the surface focus, but Qt still needs an active-focus target inside it.
      Qt.callLater(function () {
        if (win.open)
          (win.focusTarget ? win.focusTarget : keys).forceActiveFocus();
      });
    } else {
      focusPrime.stop();
      focusPrimed = false;
    }
  }

  Component.onCompleted: {
    Bus.registerSurface(win.key, false);
    // A panel asked for may be wanted already when its output arrives, with nothing to change.
    win.evaluateSoon();
  }
  Component.onDestruction: Bus.unregisterSurface(win.key, false)

  onShowingChanged: {
    if (showing)
      Bus.setOwner(win.key, win.screenName);
    else if (win.screen && Bus.ownerOf(win.key) === win.screen.name)
      Bus.setOwner(win.key, "");
  }

  onCoveringChanged: {
    if (covering)
      Bus.setCover(win.key, win.screenName);
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
      else if (win.focused && win.openable)
        win.show();
    }

    function onSurfaceClosed(key) {
      if (key === win.key)
        win.hide();
    }
  }

  surfaceData: Item {
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

  // Content that must draw past the card, as a sibling of the surface: the card's clip is a
  // mask on the surface, not the window, so a child here is never trimmed. The window is
  // full-screen, so it can sit anywhere on the output. It carries no input of its own.
  property alias overlay: overlayHolder.data

  // Added after the surface, so the ones that must sit below it say so by z.
  data: [
    // A click anywhere off the surface dismisses. The surface sits on top and takes its own.
    MouseArea {
      z: -2
      anchors.fill: parent
      enabled: win.open
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      // To the pill, whatever the surface grew out of: the click was off the card.
      onClicked: win.hide(true)
    },
    // The surface draws no input of its own, so a click inside it that misses every control
    // would fall through to the dismiss area above. This takes those clicks and does nothing.
    MouseArea {
      z: -1
      anchors.fill: win.surface
      enabled: win.open
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    },
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
    },
    Item {
      id: overlayHolder

      anchors.fill: parent
    }
  ]
}
