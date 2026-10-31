import QtQuick
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

  // Every key the surface takes, before Escape is considered. Anything left unaccepted falls
  // through to the Escape below, which closes.
  signal keyPressed(var event)

  closesElsewhere: true

  // Open, the whole window is the surface's input region, and a click off the card hits the
  // dismiss MouseArea below; passThrough narrows it to the card so a spawned picker stays
  // live.
  openMask: win.passThrough ? win.cardMask : null

  // Hyprland focuses an OnDemand surface when it first maps but not on None -> OnDemand, and
  // this one stays mapped through its close. Exclusive covers it, but would eat all pointers.
  property bool focusPrimed: false

  WlrLayershell.keyboardFocus: win.open ? (win.focusPrimed && !win.exclusiveKeyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

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
      else if (win.focused)
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
      onClicked: win.hide()
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
