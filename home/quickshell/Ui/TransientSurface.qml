import QtQuick
import Quickshell.Wayland
import qs.Commons

// One transient island surface: the OSD, a notification toast, the sharing pill, the dictation
// pill. They come and go on their own, so nothing toggles them: the owner binds `wanted`, and
// the window grows out of the island, hands it over and comes back by itself. The window, the
// still and the presentation handshake are Ui/IslandSurfaceBase.qml; see the notes there.
//
// They take turns by `rank` (Bus.transientWants): OSD 4, dictation 3, a sharing request 2, a
// toast 1, sharing progress, the rebuild and a failed recording 0. The highest wanting an output
// has the island, and one outranked waits rather than being knocked out. When the higher one lets
// go, the waiting one takes over from it as a handover, growing out of the shape it leaves,
// rather than the first shrinking to the pill and the second growing back out of it.
IslandSurfaceBase {
  id: win

  property int rank: 0

  // Whether the card takes the pointer while open. Off, the window is click-through throughout.
  property bool cardInput: true

  readonly property bool outranked: Bus.transientOutranked(win.key, win.screenName, win.rank)

  waiting: win.outranked
  centred: true

  // Only the open card is ever a target, and only for a surface with something to press. A
  // still, a close and the parked sliver take nothing, so the island underneath keeps its clicks.
  openMask: win.cardInput ? win.cardMask : win.emptyMask

  // A transient never takes the keyboard.
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

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
  Component.onCompleted: {
    Bus.registerSurface(win.key, true);
    syncWant();
  }
  Component.onDestruction: {
    Bus.setTransientWant(win.key, win.wantScreen, -1);
    Bus.unregisterSurface(win.key, true);
  }

  onCoveringChanged: {
    if (covering) {
      Bus.setTransientScreen(win.key, win.screenName);
      Bus.setTransientSurface(win.screenName, surface);
    } else {
      if (win.screenName !== "" && Bus.transientScreen(win.key) === win.screenName)
        Bus.setTransientScreen(win.key, "");
      Bus.clearTransientSurface(win.screenName, surface);
    }
  }

  Connections {
    target: Bus

    function onSurfacesClosingForLock() {
      win.open = false;
      win.origin.release();
    }

    function onLockingChanged() {
      if (!Bus.locking)
        win.evaluateSoon();
    }
  }
}
