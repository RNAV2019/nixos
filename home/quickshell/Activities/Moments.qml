import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Ui

// The moments (Penpot "Ariadne / Moment"): a charger plugged in, a network asking for a sign-in.
// Each grows out of the shut pill at the screen's centre, holds, and melts back; the queue
// and what a moment is are in Services/Activities.qml. One surface per output, shown on the
// focused one, taking turns with the OSD, the toasts and sharing by rank like each of them: an
// attention moment ranks with a notification (1), an informational one with sharing progress (0).
// A user-opened panel owns the island, so a moment waits for it.
Variants {
  model: Quickshell.screens

  TransientSurface {
    id: win

    key: "moment"
    layerNamespace: "quickshell-moment"
    rank: win.shown !== null && win.shown.attention ? 1 : 0

    // The moment at the head of the queue, and the last one there: the shape and the contents
    // are the latter's while the island melts back, so they do not blink out with the queue.
    readonly property var head: Activities.moment
    property var shown: null

    Binding {
      target: win
      property: "shown"
      value: win.head
      when: win.head !== null
      restoreMode: Binding.RestoreNone
    }

    wanted: win.head !== null && win.focused && !Bus.islandOpenFor(win.screenName)

    openWidth: win.shown ? win.shown.width : Theme.momentWidth
    openHeight: win.shown ? win.shown.height : Theme.momentHeight
    openRadius: win.shown ? win.shown.radius : Theme.momentRadius

    // What is drawn: `shown` once the island is showing it. A second moment arriving while one
    // is up crossfades, the shape springing to its size meanwhile.
    property var drawn: null
    readonly property bool visibleNow: win.open && origin.presented

    onOpening: win.drawn = win.shown

    onShownChanged: {
      if (win.drawn === null || !win.open || win.drawn === win.shown)
        return;
      // The moment before turns into this one (Ui/MorphLayer.qml); with nothing on screen to turn
      // from, the stage fades instead.
      if (win.swapBegin()) {
        win.drawn = win.shown;
        win.swapEnd();
      } else {
        win.swapping = true;
      }
    }

    // The stage fades out, the contents change under it, and it fades back in: one spring that
    // a moment arriving mid-swap simply retargets (down again if it was coming back up), with
    // whatever speed it has. The swap lands once the stage is as good as clear (a spring only
    // reaches 0 in the limit), and it takes the newest moment, whichever arrived meanwhile.
    property bool swapping: false

    ProgressSpring {
      id: fade

      target: win.swapping ? 0 : 1
      omega: Theme.momentFadeOmega
      label: "moment.stage"

      onValueChanged: {
        if (win.swapping && value <= Theme.momentSwapOpacity) {
          win.drawn = win.shown;
          win.swapping = false;
        }
      }
    }

    onOpenChanged: {
      if (!win.open)
        win.swapping = false;
    }

    // ---- dwell ----
    //
    // Counted down in steps, only while it is on screen and the pointer is away, so a hover
    // holds it and a moment waiting behind the OSD has not begun to run out. 0 stays until acted on.

    property int left: 0
    property int leftFor: -1

    onHeadChanged: {
      if (win.head !== null && win.head.id !== win.leftFor) {
        win.leftFor = win.head.id;
        win.left = win.head.dwell;
      }
    }

    Timer {
      interval: 100
      repeat: true
      running: win.visibleNow && win.head !== null && win.head.dwell > 0 && !hover.hovered
      onTriggered: {
        win.left -= 100;
        if (win.left <= 0)
          Activities.dismissMoment(win.head.id);
      }
    }

    function act(button) {
      if (button.action)
        button.action();
      if (button.keep !== true && win.drawn !== null)
        Activities.dismissMoment(win.drawn.id);
    }

    // Laid out at the moment's final size and centred, so the growing shape uncovers it.
    Item {
      id: stage

      opacity: fade.value

      x: win.surface.snap((parent.width - width) / 2)
      y: (parent.height - height) / 2
      width: win.drawn ? win.drawn.width : Theme.momentWidth
      height: win.drawn ? win.drawn.height : Theme.momentHeight

      HoverHandler {
        id: hover
      }

      // Under the buttons: a click anywhere else sends the moment away, the only way out of one
      // that stays until acted on (a sign-in page) short of its button.
      TapHandler {
        enabled: win.open && win.drawn !== null
        onTapped: Activities.dismissMoment(win.drawn.id)
      }

      Loader {
        id: body

        anchors.fill: parent
        sourceComponent: win.drawn !== null && win.drawn.body !== null ? win.drawn.body : row

        onLoaded: {
          item.moment = Qt.binding(() => win.drawn);
          if (item.shown !== undefined)
            item.shown = Qt.binding(() => win.visibleNow);
        }
      }

      Component {
        id: row

        MomentRow {
          onActed: button => win.act(button)
        }
      }
    }
  }
}
