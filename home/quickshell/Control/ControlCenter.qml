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
      home.resetNotifications();
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

    // Back goes one step: out of a sub-view if there is one, out of the panel if not.
    function back() {
      if (view !== "")
        view = "";
      else
        hide();
    }

    // The view being left stays drawn until it is wholly past the card's right edge, which
    // the clip hides; a fixed timer cut it off mid-travel whenever the spring ran long.
    function unloadIfParked() {
      if (view === "" && loadedView !== "" && subLoader.x >= openWidth - 0.5)
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

    onKeyPressed: function (event) {
      switch (event.key) {
      case Qt.Key_Escape:
      case Qt.Key_Backspace:
        win.back();
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

    // No fade of its own: IslandSurface's bodyHolder carries every panel's open, close and
    // handover fade, and a second one inside it compounded into a faster, deeper dissolve.
    Item {
      id: body

      anchors.fill: parent
      enabled: win.open

      // The push travels a full column, so it rides the shape's own spring (half-pixel rest)
      // rather than MicroSpring, whose unit-scale epsilon kept a 520 px slide alive for ~1.5 s.
      HomeView {
        id: home

        x: win.subShown ? -win.openWidth : 0
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

        Behavior on x {
          enabled: !Theme.reduceMotion

          SurfaceSpring {}
        }
      }

      Loader {
        id: subLoader

        x: win.subShown ? 0 : win.openWidth
        y: 0
        width: win.openWidth
        height: item ? item.contentHeight : 0
        active: win.loadedView !== ""
        asynchronous: true

        onXChanged: win.unloadIfParked()

        Behavior on x {
          enabled: !Theme.reduceMotion

          SurfaceSpring {}
        }

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
          active: win.open && win.view === "wifi"
          onBacked: win.view = ""
        }
      }

      Component {
        id: audioView

        AudioView {
          active: win.open && win.view === "audio"
          onBacked: win.view = ""
        }
      }

      Component {
        id: bluetoothView

        BluetoothView {
          active: win.open && win.view === "bluetooth"
          onBacked: win.view = ""
        }
      }

      Component {
        id: displaysView

        DisplaysView {
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
