import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The control centre, and the island in its third shape.
//
// Like the launcher it is not a panel. It starts at the pill's exact size,
// radius and centre line and grows down into the same 520 px column, and the
// bar stands its island down for as long as this surface is on screen, so what
// the eye follows is one shape changing rather than one surface replacing
// another.
//
// The open was measured against the source recording frame by frame at 60 fps
// between 6:19 and 6:21. The shape travels for about 295 ms, and its width and
// height ride one curve: a joint fit of both tracks to within 2.2% of their
// travel, where fitting them apart lands on 300 and 278 ms. The curve is
// Theme.morphCurve, the same underdamped response every other surface uses -
// it passes its target and settles back rather than stopping dead.
//
// The panel is clipped and its contents are laid out at their final metrics
// from the first frame, so the open is a reveal rather than a fade. That is
// what the recording shows: three frames in, the tile grid is already at full
// size and cut off by the panel's right edge, with the pill's clock still
// drawn over it and fading.
//
// Sub-views push in from the right rather than replacing the contents, and the
// surface's height travels with them, so the panel is seen to resize into the
// shape the new view needs.
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

    // What the sub-view loader is holding. It outlives `view` by one slide, so
    // the view being left is still drawn while it travels off the right edge.
    property string loadedView: ""

    // Raised for the length of the open and the close, when the height is
    // riding the shape's own curve rather than a sub-view's slide.
    property bool morphing: false

    // Raised while the island is being handed to another surface. While the
    // handover's still is held, this surface's shape rides the taker's own
    // morph; handover is also what keeps the final cut to the pill - once
    // the still is taken down, covered by the taker - instant. See
    // Ui/IslandOrigin.qml.
    // The shape this surface grows out of, and the handover protocol it
    // follows when another surface takes the island: adopt the island's
    // card, claim, take the shape the holder was wearing. One of these for
    // each of the six surfaces that stand in for the island. The status chip
    // is why the card half exists: the chip lives on the card, so it can only
    // be pressed with the card already open, and a panel that started from
    // the pill would have the card drop shut and the panel grow out of what
    // was left - the one shape in the shell going backwards before it goes
    // forwards. The card is the same 520 px column at the same radius the
    // panel settles at, so growing out of it is a change of height and
    // nothing else.
    readonly property var subView: subLoader.item

    readonly property int contentHeight: {
      if (view !== "" && subView)
        return subView.contentHeight;
      return home.contentHeight;
    }

    onOpening: {
      view = "";
      // Take the island. The ordering, the card, the handover mailbox and
      // the still the holder leaves behind all live in Ui/IslandOrigin.qml;
      // the four arguments are the morph this surface is about to travel,
      // which the holder rides with it.
      // Nothing pushes a colour-temperature change, so the tile is only as
      // right as the last time something asked. Ask now, while it is about to
      // be looked at.
      NightLight.refresh();
    }

    // Back goes one step: out of a sub-view if there is one, out of the panel
    // if there is not.
    function back() {
      if (view !== "")
        view = "";
      else
        hide();
    }

    // Same focus prime as the launcher: Hyprland focuses an OnDemand surface
    // when it first maps, but not when an already-mapped one goes None ->
    // OnDemand, and this surface stays mapped through its close animation.
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

          // The recorder's picker takes the island from here. Asking the bus
          // is the whole of it: the picker claims the island through the
          // shared protocol, and the claim is what stands this panel down -
          // dismiss() runs inside the claim and publishes this panel's live
          // shape, so the picker contracts out of it on its own curve rather
          // than jumping back to the pill first.
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

    // The progress bar is the only thing in the shell that needs MPRIS to be
    // polled, so the poll is tied to this surface being on screen.
    Binding {
      target: Media
      property: "trackPosition"
      value: true
      when: win.showing
      restoreMode: Binding.RestoreBindingOrValue
    }
  }
}
