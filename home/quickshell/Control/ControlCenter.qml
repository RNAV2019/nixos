import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Ui

// The control centre: the island in another shape, starting at the pill's size, radius and
// centre and growing into a 520 px column; clipped, so the open is a reveal; sub-views push in.
Variants {
  id: root

  model: Quickshell.screens

  IslandSurface {
    id: win

    key: "control"
    openWidth: Theme.panelWidth(modelData, Theme.controlWidth)
    openHeight: win.contentHeight
    openRadius: Theme.controlRadius

    // "" is the root view; anything else is the name of a sub-view.
    property string view: ""

    // What the loader holds; it outlives `view` by one slide so the view being left stays drawn.
    property string loadedView: ""

    readonly property var subView: subLoader.item

    // The sub-view is built off the frame clock, so the push waits for it rather than sliding
    // an empty pane in and hitching when the view lands mid-travel.
    readonly property bool subShown: view !== "" && loadedView === view && subLoader.status === Loader.Ready

    readonly property int contentHeight: {
      if (subShown && subView)
        return subView.contentHeight;
      return home.contentHeight;
    }

    // Set when the Record tile hands the island to the picker, so backing out of the picker
    // lands on the tile it left from rather than on the first one.
    property bool recorderOut: false

    // Only the tile raises it, and only while this panel is open: the request that follows
    // is marked as this output's for that turn of the event loop, so the picker can tell a
    // tile press from a shortcut arriving while this panel is still on its way out.
    onRecorderOutChanged: {
      if (!recorderOut || !win.open || !win.screen)
        return;
      var name = win.screen.name;
      Bus.recorderFrom = name;
      Qt.callLater(function () {
        if (Bus.recorderFrom === name)
          Bus.recorderFrom = "";
      });
    }

    onOpening: {
      view = "";
      home.keyboardIndex = recorderOut && Bus.ownerOf("recorder") !== "" ? 7 : 0;
      recorderOut = false;
      // Nothing pushes a colour-temperature change, so ask now, while it is about to be seen.
      NightLight.refresh();
    }

    Connections {
      target: Bus

      function onOwnersChanged() {
        if (win.recorderOut && Bus.ownerOf("recorder") === "" && !win.open)
          win.recorderOut = false;
      }
    }

    // The view being left stays drawn until the slide has settled back home, which parks it
    // past the card's right edge; a fixed timer cut it off mid-travel whenever the spring ran
    // long. Only once progress is back at 0: a `view` change can reach here before the spring
    // has taken its new target, while it still reads settled at the sub-view.
    function unloadIfParked() {
      if (view === "" && loadedView !== "" && slide.settled && slide.progress === 0)
        loadedView = "";
    }

    function focusSubView() {
      if (win.open && win.subShown && win.subView)
        win.subView.forceActiveFocus();
    }

    onShowingChanged: {
      if (!win.showing) {
        view = "";
        loadedView = "";
      }
    }

    onViewChanged: {
      if (view !== "") {
        loadedView = view;
        Qt.callLater(win.focusSubView);
      } else {
        unloadIfParked();
      }
    }

    onSubShownChanged: if (subShown)
      Qt.callLater(win.focusSubView)

    // A sub-view's own panel takes Escape and Backspace to step back out. On the home view Escape
    // falls through to close, and Backspace does what its Back button does.
    onKeyPressed: function (event) {
      switch (event.key) {
      case Qt.Key_Backspace:
        // Already taken if a sub-view's panel stepped out on it.
        if (win.view !== "" || event.accepted)
          return;
        win.hide();
        break;
      case Qt.Key_Left:
      case Qt.Key_Up:
        if (win.view === "")
          home.keyboardMove(-1);
        else
          return;
        break;
      case Qt.Key_Right:
      case Qt.Key_Down:
        if (win.view === "")
          home.keyboardMove(1);
        else
          return;
        break;
      case Qt.Key_Tab:
        if (win.view === "")
          home.keyboardMove(event.modifiers & Qt.ShiftModifier ? -1 : 1);
        else
          return;
        break;
      case Qt.Key_Backtab:
        if (win.view === "")
          home.keyboardMove(-1);
        else
          return;
        break;
      case Qt.Key_Return:
      case Qt.Key_Enter:
      case Qt.Key_Space:
        if (win.view === "")
          home.keyboardActivate();
        else
          return;
        break;
      default:
        return;
      }
      event.accepted = true;
    }

    // No fade of its own: IslandSurfaceBase's bodyHolder carries every panel's open, close and
    // handover fade, and a second one inside it compounded into a faster, deeper dissolve.
    Item {
      id: body

      anchors.fill: parent
      enabled: win.open

      // The push is one per-frame spring at the island's pace (Ui/SubviewSlide.qml); it waits for
      // the sub-view to be built, so the home view holds still rather than sliding out to nothing.
      SubviewSlide {
        id: slide

        anchors.fill: parent
        home: home
        sub: subLoader
        name: "control"
        travel: win.openWidth
        subShown: win.view !== "" && win.loadedView === win.view
        subReady: subLoader.status === Loader.Ready
        onSettledChanged: win.unloadIfParked()
        // With reduced motion the spring never runs, so progress is all that tells it.
        onProgressChanged: win.unloadIfParked()
      }

      HomeView {
        id: home

        y: 0
        width: win.openWidth
        height: contentHeight

        onClosed: win.hide()
        onOpened: function (name) {
          win.view = name;
        }

        // The picker claims the island through the shared protocol, which stands this panel
        // down: dismiss() publishes this panel's live shape so the picker contracts out of it.
        onRecorderRequested: {
          win.recorderOut = true;
          Bus.recorderRequested();
        }
      }

      Loader {
        id: subLoader

        y: 0
        width: win.openWidth
        height: item ? item.contentHeight : 0
        active: win.loadedView !== ""
        asynchronous: true

        sourceComponent: {
          switch (win.loadedView) {
          case "wifi":
            return wifiView;
          case "audio":
            return audioView;
          case "bluetooth":
            return bluetoothView;
          case "displays":
            return displaysView;
          }
          return null;
        }
      }

      Component {
        id: wifiView

        WifiView {
          surface: win
          active: win.open && win.view === "wifi"
          onBacked: win.view = ""
        }
      }

      Component {
        id: audioView

        AudioView {
          surface: win
          active: win.open && win.view === "audio"
          onBacked: win.view = ""
        }
      }

      Component {
        id: bluetoothView

        BluetoothView {
          surface: win
          active: win.open && win.view === "bluetooth"
          onBacked: win.view = ""
        }
      }

      Component {
        id: displaysView

        DisplaysView {
          surface: win
          active: win.open && win.view === "displays"
          hostScreen: modelData.name
          onBacked: win.view = ""
        }
      }
    }

    // The progress bar is the only thing needing MPRIS polled, so the poll is tied to this surface.
    Binding {
      target: Media
      property: "trackPosition"
      value: true
      when: win.showing
      restoreMode: Binding.RestoreBindingOrValue
    }
  }
}
