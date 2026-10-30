import QtQuick
import QtQuick.Effects
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// One window in a workspace card: a live capture of it at its real place and size, scaled to
// the card, with a ring and a plate naming it while it is the selection (or a match, or under
// the pointer). The capture is a still taken every so often, never a live stream, and only
// while the Overview is up.
Item {
  id: root

  // The window, as Services/WindowList.qml describes it.
  required property var info
  // Card px per output px.
  property real factor: 1
  // Where drag points are reported, so the card need know nothing of the surface above it.
  property Item space: null

  property bool selected: false
  // Matched by the filter; null while nothing is being filtered.
  property var hit: null
  property bool filtering: false
  // On the selected workspace, so captured more often than the rest.
  property bool near: false
  property bool capturing: false
  // Raised when the compositor ends a capture (the window went), so nothing asks it for more.
  property bool gone: false
  // Lifted by a drag: its slot stays, dimmed, where it was.
  property bool lifted: false
  // The dpr of the window it is drawn in, so the capture is no bigger than it needs to be.
  property real pixelRatio: 1

  readonly property bool hovered: mouse.containsMouse
  readonly property bool showPlate: selected || hovered || (filtering && hit !== null)
  // The capture's own item, which a drag lifts a copy of.
  readonly property Item body: face

  signal clicked
  signal dragStarted(point where)
  signal dragMoved(point where)
  signal dragEnded

  x: info.x * factor
  y: info.y * factor
  width: Math.max(4, info.w * factor)
  height: Math.max(4, info.h * factor)
  opacity: lifted ? 0.3 : filtering && hit === null ? Theme.overviewDim : 1

  Behavior on opacity {
    Morph {
      duration: Theme.duration(Theme.morphState)
    }
  }

  Item {
    id: face

    anchors.fill: parent
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: mask
    }

    Rectangle {
      anchors.fill: parent
      color: Theme.surfaceSubtle
    }

    // Until a frame arrives, the app's own colour and initial, so a slot is never bare.
    Text {
      anchors.centerIn: parent
      visible: !view.hasContent
      text: root.info.appName.charAt(0).toUpperCase()
      color: Theme.stableAccent(root.info.appClass)
      font.family: Theme.uiFont
      font.pixelSize: Math.max(10, Math.min(root.width, root.height) * 0.3)
      font.weight: Theme.weightSemi
    }

    ScreencopyView {
      id: view

      anchors.fill: parent
      captureSource: root.capturing && !root.gone ? root.info.toplevel : null
      live: false
      paintCursor: false
      constraintSize: Qt.size(Math.ceil(root.width * root.pixelRatio), Math.ceil(root.height * root.pixelRatio))

      onStopped: root.gone = true
    }

    Timer {
      running: root.capturing && view.captureSource !== null
      repeat: true
      triggeredOnStart: true
      interval: root.near ? Theme.overviewCaptureNear : Theme.overviewCaptureFar
      onTriggered: view.captureFrame()
    }
  }

  Item {
    id: mask

    anchors.fill: parent
    visible: false
    layer.enabled: true

    Rectangle {
      anchors.fill: parent
      radius: Theme.overviewWindowRadius
      color: "black"
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: Theme.overviewWindowRadius
    color: "transparent"
    border.width: Theme.overviewActiveRing
    border.color: Theme.accent
    opacity: root.selected && !root.lifted ? 1 : 0

    Behavior on opacity {
      Morph {
        duration: Theme.duration(Theme.morphState)
      }
    }
  }

  OverviewPlate {
    x: Theme.overviewPlateInset
    y: root.height - height - Theme.overviewPlateInset
    maxWidth: root.width - 2 * Theme.overviewPlateInset
    title: root.info.title
    app: root.info.appName
    dot: Theme.stableAccent(root.info.appClass)
    emphasis: root.selected
    positions: root.hit ? root.hit.positions : []
    opacity: root.showPlate && !root.lifted ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
      Morph {
        duration: Theme.duration(Theme.morphState)
      }
    }
  }

  MouseArea {
    id: mouse

    property point start
    property bool dragging: false

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    function where(m) {
      return root.space ? mapToItem(root.space, m.x, m.y) : Qt.point(m.x, m.y);
    }

    onPressed: function (m) {
      start = Qt.point(m.x, m.y);
      dragging = false;
    }

    onPositionChanged: function (m) {
      if (!pressed)
        return;
      if (!dragging && Math.hypot(m.x - start.x, m.y - start.y) > Theme.overviewDragSlop) {
        dragging = true;
        root.dragStarted(where(m));
      }
      if (dragging)
        root.dragMoved(where(m));
    }

    onReleased: {
      if (dragging)
        root.dragEnded();
      else if (containsMouse)
        root.clicked();
      dragging = false;
    }
  }
}
