import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The control centre: the island in another shape rather than a panel. It starts at the
// pill's exact size, radius and centre line and grows down into a 520 px column, and the
// bar stands its island down for as long as it is on screen.
//
// The panel is clipped and its contents are laid out at their final metrics from the
// first frame, so the open is a reveal rather than a fade.
//
// Sub-views push in from the right rather than replacing the contents, and the surface's
// height travels with them.
Variants {
  id: root

  model: Quickshell.screens

  IslandSurface {
    id: win

    key: "control"
    openWidth: Theme.controlWidth
    openHeight: win.contentHeight
    openRadius: Theme.controlRadius

    // "" is the root view; anything else is the name of a sub-view.
    property string view: ""

    // What the sub-view loader is holding. It outlives `view` by one slide, so the view
    // being left is still drawn while it travels off the right edge.
    property string loadedView: ""

    // Raised for the open and the close, when the height rides the shape's own curve
    // rather than a sub-view's slide.
    property bool morphing: false

    readonly property var subView: subLoader.item

    readonly property int contentHeight: {
      if (view !== "" && subView)
        return subView.contentHeight;
      return home.contentHeight;
    }

    onOpening: {
      view = "";
      // Nothing pushes a colour-temperature change, so ask now, while it is about to be seen.
      NightLight.refresh();
    }

    // Back goes one step: out of a sub-view if there is one, out of the panel if not.
    function back() {
      if (view !== "")
        view = "";
      else
        hide();
    }

    // The same focus prime the launcher needs; see Launcher/Launcher.qml.
    Timer {
      id: settle

      interval: Theme.morphSurface + 30
      onTriggered: win.morphing = false
    }

    // The view being left has to stay drawn until it has finished travelling.
    Timer {
      id: unload

      interval: Theme.morphSurface + 40
      onTriggered: if (win.view === "")
        win.loadedView = ""
    }

    onOpenChanged: {
      morphing = true;
      settle.restart();
    }

    onViewChanged: {
      if (view !== "") {
        loadedView = view;
        unload.stop();
      } else {
        unload.restart();
      }
    }

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

    Item {
      id: body

      anchors.fill: parent
      opacity: win.open || win.origin.held ? 1 : 0
      visible: opacity > 0

      Behavior on opacity {
        enabled: !win.origin.held

        Morph {
          duration: Theme.morphContent
        }
        }

        HomeView {
          id: home

          x: win.view === "" ? 0 : -Theme.controlWidth
          y: 0
          width: Theme.controlWidth
          height: contentHeight

          onClosed: win.hide()
          onOpened: function (name) {
            win.view = name;
          }

          // The picker claims the island through the shared protocol, and the claim is what
          // stands this panel down: dismiss() runs inside it and publishes this panel's live
          // shape, so the picker contracts out of it rather than jumping back to the pill.
          onRecorderRequested: Bus.recorderRequested()

          Behavior on x {
            Morph {
              duration: Theme.morphSurface
            }
          }
        }

        Loader {
          id: subLoader

          x: win.view === "" ? Theme.controlWidth : 0
          y: 0
          width: Theme.controlWidth
          height: item ? item.contentHeight : 0
          active: win.loadedView !== ""

          Behavior on x {
            Morph {
              duration: Theme.morphSurface
            }
          }

          sourceComponent: {
            switch (win.loadedView) {
            case "wifi":
              return wifiView;
            case "audio":
              return audioView;
            case "bluetooth":
              return bluetoothView;
            }
            return null;
          }
        }

        Component {
          id: wifiView

          WifiView {
            active: win.view === "wifi"
            onBacked: win.view = ""
          }
        }

        Component {
          id: audioView

          AudioView {
            active: win.view === "audio"
            onBacked: win.view = ""
          }
        }

        Component {
          id: bluetoothView

          BluetoothView {
            active: win.view === "bluetooth"
            onBacked: win.view = ""
          }
        }
      }

    // The progress bar is the only thing that needs MPRIS polled, so the poll is tied to
    // this surface being on screen.
    Binding {
      target: Media
      property: "trackPosition"
      value: true
      when: win.showing
      restoreMode: Binding.RestoreBindingOrValue
    }
  }
}
