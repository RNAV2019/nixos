import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Ui

// The moments (Penpot "Ariadne / Moment"): a timer ringing, a phase changing, a charger plugged
// in. Each grows out of the shut pill at the screen's centre, holds, and melts back; the queue
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
      swap.restart();
    }

    SequentialAnimation {
      id: swap

      NumberAnimation {
        target: stage
        property: "opacity"
        to: 0
        duration: Theme.morphContent
      }

      ScriptAction {
        script: win.drawn = win.shown
      }

      NumberAnimation {
        target: stage
        property: "opacity"
        to: 1
        duration: Theme.morphEnter
      }
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

      x: (win.surface.width - width) / 2
      y: (win.surface.height - height) / 2
      width: win.drawn ? win.drawn.width : Theme.momentWidth
      height: win.drawn ? win.drawn.height : Theme.momentHeight

      HoverHandler {
        id: hover
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
