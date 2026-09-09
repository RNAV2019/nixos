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
// between 6:19 and 6:21. The shape travels for 295 ms and stops dead, and its
// width and height ride one curve: a joint fit of both tracks to within 2.2% of
// their travel, where fitting them apart lands on 300 and 278 ms. The curve is
// Theme.morphCurve, the same critically damped response every other surface
// uses.
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

  PanelWindow {
    id: win

    required property var modelData

    property bool open: false

    // "" is the root view; anything else is the name of a sub-view.
    property string view: ""

    // What the sub-view loader is holding. It outlives `view` by one slide, so
    // the view being left is still drawn while it travels off the right edge.
    property string loadedView: ""

    // Raised for the length of the open and the close, when the height is
    // riding the shape's own curve rather than a sub-view's slide.
    property bool morphing: false

    // Raised while the island is being handed to the launcher, which is the one
    // close that does not animate. See dismiss().
    property bool handover: false

    // The shape the surface grows out of, when that is not the pill. Zero is
    // the pill.
    //
    // The status chip is why this exists. The chip lives on the card, so it
    // can only be pressed with the card already open, and a panel that started
    // from the pill would have the card drop shut and the panel grow out of
    // what was left - the one shape in the shell going backwards before it
    // goes forwards. The card is the same 520 px column at the same 26 px
    // radius the panel settles at, so growing out of it is a change of height
    // and nothing else.
    property real fromWidth: 0
    property real fromHeight: 0
    property real fromRadius: 0

    readonly property bool fromCard: fromHeight > 0

    // Raised for the one assignment that puts the surface on the card's shape,
    // so it arrives there rather than travelling there.
    property bool snapping: false

    readonly property real originWidth: fromCard ? fromWidth : collapsedWidth
    readonly property real originHeight: fromCard ? fromHeight : Theme.barHeight
    readonly property real originRadius: fromCard ? fromRadius : Theme.islandRadius

    // How far open the card was when it handed over, on the island's own scale
    // where 0 is the pill and 1 the card. The clock this surface carries over
    // is drawn where the island had it at exactly that point, so the two are
    // the same clock across the hand-over even when the chip is pressed with
    // the card still growing.
    readonly property real fromOpenness: {
      var span = Theme.islandExpandedHeight - Theme.barHeight;
      if (!win.fromCard || span <= 0)
        return 0;
      return Math.max(0, Math.min(1, (win.fromHeight - Theme.barHeight) / span));
    }

    readonly property bool focused: Monitors.isFocused(win.screen)

    readonly property int collapsedWidth: Media.active ? Theme.islandPlayingWidth : Theme.islandIdleWidth

    readonly property var subView: subLoader.item

    readonly property int openHeight: {
      if (view !== "" && subView)
        return subView.contentHeight;
      return home.contentHeight;
    }

    // True from the moment the shape starts growing until it is back to pill
    // size, which is the whole time the bar must keep its island hidden.
    readonly property bool showing: open || surface.width > collapsedWidth + 0.5

    // Take the shape of the card already standing open on this output, if
    // there is one. Its measurements are read first and read into locals,
    // because claiming the island is what shuts the card.
    function adopt() {
      var card = Bus.islandCard;
      if (!card || !card.win || !card.win.screen || !win.screen)
        return;
      if (card.win.screen.name !== win.screen.name)
        return;

      var w = card.width;
      var h = card.height;
      var r = card.surfaceRadius;

      snapping = true;
      fromWidth = w;
      fromHeight = h;
      fromRadius = r;
      snapping = false;
    }

    // Back to growing out of the pill, which is what the island is again by
    // the time this surface has finished closing over it.
    function release() {
      fromWidth = 0;
      fromHeight = 0;
      fromRadius = 0;
    }

    function show() {
      view = "";
      adopt();
      // The launcher and the control centre are the same island. Claiming it
      // is what makes the other let go, and it lets go without animating.
      handover = false;
      Bus.islandClaimed();
      Bus.closePanels();
      // Nothing pushes a colour-temperature change, so the tile is only as
      // right as the last time something asked. Ask now, while it is about to
      // be looked at.
      NightLight.refresh();
      open = true;
    }

    function hide() {
      release();
      open = false;
    }

    // Giving the island up to the launcher. There is no shrink back to the
    // pill: the surface taking over is already growing in this one's place and
    // starts from the same pill, so this one has only to stop being drawn.
    function dismiss() {
      release();
      handover = true;
      open = false;
    }

    // Back goes one step: out of a sub-view if there is one, out of the panel
    // if there is not.
    function back() {
      if (view !== "")
        view = "";
      else
        hide();
    }

    screen: modelData
    visible: showing
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-control"

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    exclusionMode: ExclusionMode.Ignore

    // Same focus prime as the launcher and Ui/PanelHost.qml: Hyprland focuses
    // an OnDemand surface when it first maps, but not when an already-mapped
    // one goes None -> OnDemand, and this surface stays mapped through its
    // close animation.
    property bool focusPrimed: false

    WlrLayershell.keyboardFocus: win.open ? (win.focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

    Timer {
      id: focusPrime

      interval: 75
      onTriggered: win.focusPrimed = true
    }

    Timer {
      id: settle

      interval: Theme.morphControl + 30
      onTriggered: win.morphing = false
    }

    // The view being left has to stay drawn until it has finished travelling.
    Timer {
      id: unload

      interval: Theme.morphSubView + 40
      onTriggered: if (win.view === "")
        win.loadedView = ""
    }

    onOpenChanged: {
      morphing = true;
      settle.restart();

      if (open) {
        focusPrimed = false;
        focusPrime.restart();
        Qt.callLater(function () {
          if (win.open)
            keys.forceActiveFocus();
        });
      } else {
        focusPrime.stop();
        focusPrimed = false;
      }
    }

    onViewChanged: {
      if (view !== "") {
        loadedView = view;
        unload.stop();
      } else {
        unload.restart();
      }
    }

    onShowingChanged: {
      if (showing)
        Bus.controlScreen = win.screen ? win.screen.name : "";
      else if (win.screen && Bus.controlScreen === win.screen.name)
        Bus.controlScreen = "";
    }

    Connections {
      target: Bus

      function onControlToggled() {
        if (win.open)
          win.hide();
        else if (win.focused)
          win.show();
      }

      function onControlClosed() {
        win.hide();
      }

      // The launcher taking the island takes it from here.
      function onIslandClaimed() {
        if (win.open)
          win.dismiss();
      }
    }

    // A click anywhere off the surface dismisses. The surface sits on top of
    // this and takes its own clicks.
    MouseArea {
      anchors.fill: parent
      enabled: win.open
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      onClicked: win.hide()
    }

    FrostedSurface {
      id: surface

      x: (win.width - width) / 2
      y: Theme.barMarginTop

      clipContent: true

      implicitWidth: win.open ? Theme.controlWidth : win.originWidth
      implicitHeight: win.open ? win.openHeight : win.originHeight
      surfaceRadius: win.open ? Theme.controlRadius : win.originRadius

      Behavior on implicitWidth {
        enabled: !win.handover && !win.snapping

        Morph {
          duration: Theme.morphControl
        }
      }

      // The one property two different motions share. Opening and closing, the
      // height rides the shape's own curve; once the panel is open and standing
      // still, a change of view is the sub-view's slide instead, and the height
      // travels with it.
      Behavior on implicitHeight {
        enabled: !win.handover && !win.snapping

        Morph {
          duration: win.morphing ? Theme.morphControl : Theme.morphSubView
        }
      }

      Behavior on surfaceRadius {
        enabled: !win.handover && !win.snapping

        Morph {
          duration: Theme.morphControl
        }
      }

      Item {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onPressed: function (event) {
          switch (event.key) {
          case Qt.Key_Escape:
          case Qt.Key_Backspace:
            win.back();
            break;
          default:
            return;
          }
          event.accepted = true;
        }
      }

      SystemClock {
        id: clock

        precision: SystemClock.Minutes
      }

      // The clock belongs to neither state. It is what the island was showing
      // at the moment it handed over, and it stays in the growing box until
      // the panel has taken over.
      //
      // Out of the pill that is a small clock on the box's centre. Out of the
      // card it is the card's own: larger, and held 8 px above the centre the
      // card had rather than the centre this box is growing into, so the panel
      // grows past it instead of carrying it down. Either way the clock does
      // not move on the frame the hand-over happens, which is the only frame
      // where the two surfaces are the same shape and the eye could catch it.
      Text {
        x: (surface.width - width) / 2
        y: win.fromCard ? win.fromHeight / 2 - 8 * win.fromOpenness - height / 2 : (surface.height - height) / 2
        text: Qt.formatDateTime(clock.date, "HH:mm")
        color: Theme.text
        font.family: Theme.uiFont
        font.pixelSize: Theme.islandClockSize + win.fromOpenness * (Theme.islandDisplaySize - Theme.islandClockSize)
        font.weight: Font.DemiBold
        opacity: win.open ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
          Morph {
            duration: Theme.morphContent
          }
        }
      }

      // Everything the panel draws, cross-faded against the clock on the same
      // short clock the island uses for its own contents. Nothing inside fades
      // on its own; the growing shape uncovers it.
      Item {
        id: body

        anchors.fill: parent
        opacity: win.open ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
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

          Behavior on x {
            Morph {
              duration: Theme.morphSubView
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
              duration: Theme.morphSubView
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
