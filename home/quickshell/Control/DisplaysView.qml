import QtQuick
import qs.Commons
import qs.Control
import qs.Services
import qs.Ui
import "../Ui/Motion.js" as Motion

// The monitors drawn to scale. The laptop panel is the anchor; the external monitor is
// dragged around it, follows the pointer 1:1, and on release springs flush to the nearest
// edge. The placement is remembered for that monitor; see Services/Displays.qml.
ControlSubView {
  id: root

  title: "Displays"
  accessibleName: "Display arrangement"

  readonly property var panel: Displays.internal
  readonly property var external: Displays.external

  // The output this panel is open on, which the list marks with a dot.
  property string hostScreen: ""

  // Workspace 5 belongs to an external monitor while one is connected; see desktop.nix.
  function workspacesFor(m) {
    if (!root.external)
      return "Workspaces 1–9";
    return Displays.isInternal(m) ? "Workspaces 1–4, 6–9" : "Workspace 5";
  }

  function nameOf(m) {
    return Displays.isInternal(m) ? "Built-in display" : Displays.makeOf(m) + " " + Displays.modelOf(m);
  }

  function detailsOf(m) {
    return m.name + " · " + m.width + " × " + m.height + " · " + Math.round(Displays.refreshRate(m)) + " Hz · " + Math.round(m.scale * 100) + "%";
  }

  headerTrailing: [
    Button {
      visible: root.external !== null
      kind: Button.Icon
      icon: Icons.restore
      enabled: root.active
      accessibleName: "Reset arrangement"

      onClicked: {
        canvas.pending = null;
        Displays.reset(root.external);
      }
    }
  ]

  SectionLabel {
    width: parent.width
    title: "Arrangement"
  }

  Rectangle {
    id: canvas

    width: parent.width
    height: Theme.displaysCanvasHeight
    radius: Theme.displaysCanvasRadius
    color: Theme.lift(Theme.liftTile)
    border.width: 1
    border.color: activeFocus ? Theme.focusRing : Theme.lift(Theme.liftEdge)
    clip: true

    activeFocusOnTab: root.external !== null
    Accessible.role: Accessible.Pane
    Accessible.name: "Arrangement. Arrow keys move the external display to that side."
    Accessible.focusable: activeFocusOnTab

    Behavior on border.color {
      Tint {}
    }

    readonly property var panelRect: root.panel ? Displays.layoutRect(root.panel) : null
    readonly property var screenRect: root.external ? Displays.layoutRect(root.external) : null

    // Where the external monitor was dropped, held until Hyprland reports it there.
    property var pending: null

    readonly property var screenAt: {
      if (!screenRect)
        return null;
      if (!pending)
        return screenRect;
      return {
        x: pending.x,
        y: pending.y,
        w: screenRect.w,
        h: screenRect.h
      };
    }

    onScreenRectChanged: {
      if (pending && screenRect && screenRect.x === pending.x && screenRect.y === pending.y)
        pending = null;
    }

    Timer {
      // A placement Hyprland refused would otherwise hold the tile where it was dropped.
      running: canvas.pending !== null
      interval: 2000
      onTriggered: canvas.pending = null
    }

    // With the laptop alone, the caption needs room under its tile.
    readonly property int captionRoom: root.external ? 0 : caption.height + 14

    // Fitted to the committed layout, not the drag, so the canvas holds still under the
    // pointer and zooms to fit once the drop has landed.
    readonly property var bounds: {
      if (!panelRect)
        return null;
      var b = {
        x0: panelRect.x,
        y0: panelRect.y,
        x1: panelRect.x + panelRect.w,
        y1: panelRect.y + panelRect.h
      };
      if (screenAt) {
        b.x0 = Math.min(b.x0, screenAt.x);
        b.y0 = Math.min(b.y0, screenAt.y);
        b.x1 = Math.max(b.x1, screenAt.x + screenAt.w);
        b.y1 = Math.max(b.y1, screenAt.y + screenAt.h);
      }
      return b;
    }

    readonly property real fit: {
      if (!bounds)
        return 1;
      var w = width - Theme.displaysCanvasPadX * 2, h = height - Theme.displaysCanvasPadY * 2 - captionRoom;
      return Math.min(w / (bounds.x1 - bounds.x0), h / (bounds.y1 - bounds.y0));
    }

    readonly property real originX: bounds ? (width - (bounds.x1 - bounds.x0) * fit) / 2 - bounds.x0 * fit : 0
    readonly property real originY: bounds ? (height - captionRoom - (bounds.y1 - bounds.y0) * fit) / 2 - bounds.y0 * fit : 0

    property bool dragging: false
    property real dragX: 0
    property real dragY: 0

    function toLayoutX(cx) {
      return (cx - originX) / fit;
    }

    function toLayoutY(cy) {
      return (cy - originY) / fit;
    }

    // The nearest placement flush against one of the panel's edges, keeping some overlap
    // along it, and pulled onto a start, centre or end alignment when the drop is close.
    function snap(lx, ly) {
      var p = panelRect, e = screenRect;
      var reach = Theme.displaysSnapDistance / fit;
      var overlapY = Math.min(p.h, e.h) * Theme.displaysMinOverlap;
      var overlapX = Math.min(p.w, e.w) * Theme.displaysMinOverlap;

      // Monitors of similar size put all three marks within a few hundred pixels of each
      // other, so the closest one wins, not the first in range; centre is listed first so
      // it takes a tie.
      function along(v, start, length, size, overlap) {
        v = Math.max(start - size + overlap, Math.min(start + length - overlap, v));
        var marks = [start + (length - size) / 2, start, start + length - size];
        var best = v, bestDistance = reach;
        for (var i = 0; i < marks.length; i++) {
          var d = Math.abs(v - marks[i]);
          if (d <= bestDistance) {
            best = marks[i];
            bestDistance = d - 0.001;
          }
        }
        return best;
      }

      var y = along(ly, p.y, p.h, e.h, overlapY);
      var x = along(lx, p.x, p.w, e.w, overlapX);
      var options = [
        {
          x: p.x + p.w,
          y: y
        },
        {
          x: p.x - e.w,
          y: y
        },
        {
          x: x,
          y: p.y - e.h
        },
        {
          x: x,
          y: p.y + p.h
        }
      ];
      var best = options[0], bestDistance = Infinity;
      for (var j = 0; j < options.length; j++) {
        var d = Math.hypot(options[j].x - lx, options[j].y - ly);
        if (d < bestDistance) {
          best = options[j];
          bestDistance = d;
        }
      }
      return {
        x: Math.round(best.x),
        y: Math.round(best.y)
      };
    }

    function commit(spot) {
      pending = spot;
      Displays.place(root.external, spot.x, spot.y);
    }

    // Which of the panel's edges the monitor is against.
    readonly property string side: {
      if (!panelRect || !screenAt)
        return "";
      var p = panelRect, e = screenAt;
      if (Math.abs(e.x - (p.x + p.w)) <= 1)
        return "right";
      if (Math.abs(e.x + e.w - p.x) <= 1)
        return "left";
      if (Math.abs(e.y - (p.y + p.h)) <= 1)
        return "below";
      if (Math.abs(e.y + e.h - p.y) <= 1)
        return "above";
      return "";
    }

    // Where an edge or the centre lands for "start", "centre" or "end" along a side.
    function alignedAt(mark, start, length, size) {
      if (mark === "start")
        return start;
      if (mark === "end")
        return start + length - size;
      return Math.round(start + (length - size) / 2);
    }

    // Each control sets one axis of where the monitor sits against the panel.
    // Horizontal: "start" left of it, "centre" over or under it, "end" right of it.
    // Vertical: "start" above it, or beside it with top edges level; "centre" beside it,
    // centred; "end" below it, or beside it with bottom edges level.
    // "" when the current placement is not one of those, e.g. dragged above, off centre.
    function alignment(horizontal) {
      if (!screenAt)
        return "";
      var p = panelRect, e = screenAt;
      var beside = side === "left" || side === "right";
      var stacked = side === "above" || side === "below";
      if (horizontal) {
        if (beside)
          return side === "left" ? "start" : "end";
        return stacked && Math.abs(e.x - alignedAt("centre", p.x, p.w, e.w)) <= 1 ? "centre" : "";
      }
      if (stacked)
        return side === "above" ? "start" : "end";
      if (!beside)
        return "";
      var marks = ["start", "centre", "end"];
      for (var i = 0; i < marks.length; i++)
        if (Math.abs(e.y - alignedAt(marks[i], p.y, p.h, e.h)) <= 1)
          return marks[i];
      return "";
    }

    function placementFor(h, v) {
      var p = panelRect, e = screenAt;
      if (h === "centre")
        return {
          x: alignedAt("centre", p.x, p.w, e.w),
          y: v === "end" ? p.y + p.h : p.y - e.h
        };
      return {
        x: h === "start" ? p.x - e.w : p.x + p.w,
        y: alignedAt(v || "start", p.y, p.h, e.h)
      };
    }

    // The pressed axis changes and the other keeps its choice, so presses chain: Centre then
    // Top is centred above. Centre on both axes would overlap the panel, so the axis not
    // pressed gives way, to the side the monitor already leans towards.
    function align(horizontal, mark) {
      if (!panelRect || !screenAt)
        return;
      var p = panelRect, e = screenAt;
      var h = alignment(true), v = alignment(false);
      if (horizontal)
        h = mark;
      else
        v = mark;
      if (h === "")
        h = side === "left" ? "start" : side === "right" ? "end" : "centre";
      if (v === "")
        v = side === "below" ? "end" : "start";
      if (h === "centre" && v === "centre") {
        if (horizontal)
          v = e.y + e.h / 2 > p.y + p.h / 2 ? "end" : "start";
        else
          h = e.x + e.w / 2 < p.x + p.w / 2 ? "start" : "end";
      }
      commit(placementFor(h, v));
    }

    // Arrow keys put the monitor on that side of the panel, top or left edges level.
    Keys.onPressed: function (event) {
      if (!panelRect || !screenRect)
        return;
      var p = panelRect, e = screenRect;
      switch (event.key) {
      case Qt.Key_Right:
        commit({
          x: p.x + p.w,
          y: p.y
        });
        break;
      case Qt.Key_Left:
        commit({
          x: p.x - e.w,
          y: p.y
        });
        break;
      case Qt.Key_Up:
        commit({
          x: p.x,
          y: p.y - e.h
        });
        break;
      case Qt.Key_Down:
        commit({
          x: p.x,
          y: p.y + p.h
        });
        break;
      default:
        return;
      }
      event.accepted = true;
    }

    DisplayTile {
      id: panelTile

      visible: canvas.panelRect !== null
      label: "Built-in"
      area: canvas
      rect: canvas.panelRect
    }

    DisplayTile {
      id: screenTile

      visible: canvas.screenAt !== null
      label: root.external ? Displays.modelOf(root.external) : ""
      rect: canvas.screenAt
      selected: true
      draggable: true
      area: canvas
    }

    Text {
      id: caption

      anchors.horizontalCenter: parent.horizontalCenter
      y: panelTile.y + panelTile.height + 14
      visible: root.external === null
      text: "Connect a display to arrange it"
      color: Theme.muted
      font.family: Theme.uiFont
      font.pixelSize: Theme.controlTileSubSize
    }
  }

  // Two segmented controls, one per axis; see canvas.align() for what each press does.
  Item {
    width: parent.width
    height: Theme.nearbyTrackHeight
    visible: root.external !== null

    Repeater {
      model: [
        {
          horizontal: true,
          name: "Horizontal position",
          marks: [
            {
              mark: "start",
              glyph: Icons.alignLeft,
              name: "Left of the built-in display"
            },
            {
              mark: "centre",
              glyph: Icons.alignCentre,
              name: "Centred over or under it"
            },
            {
              mark: "end",
              glyph: Icons.alignRight,
              name: "Right of the built-in display"
            }
          ]
        },
        {
          horizontal: false,
          name: "Vertical position",
          marks: [
            {
              mark: "start",
              glyph: Icons.alignTop,
              name: "Above it, or beside it with top edges level"
            },
            {
              mark: "centre",
              glyph: Icons.alignMiddle,
              name: "Beside it, centred"
            },
            {
              mark: "end",
              glyph: Icons.alignBottom,
              name: "Below it, or beside it with bottom edges level"
            }
          ]
        }
      ]

      Segmented {
        id: group

        required property var modelData
        required property int index

        x: index === 0 ? 0 : parent.width - width
        width: (parent.width - Theme.controlTileGap) / 2
        height: parent.height
        accessibleName: modelData.name
        currentIndex: modelData.marks.findIndex(m => m.mark === canvas.alignment(modelData.horizontal))
        segments: modelData.marks.map(m => ({
              "icon": m.glyph,
              "name": m.name
            }))
        onChosen: function (i) {
          canvas.align(modelData.horizontal, modelData.marks[i].mark);
        }
      }
    }
  }

  SectionLabel {
    width: parent.width
    title: "Displays"
  }

  // One group: square seams between rows, rounded only at its outer corners. The rows only
  // report, so they take no hover, press or pointer; a dot marks the screen showing the panel.
  Column {
    width: parent.width
    spacing: Theme.controlRowGroupGap

    Repeater {
      id: rows

      model: [root.panel, root.external].filter(m => m !== null)

      ListRow {
        required property var modelData
        required property int index

        width: parent.width
        groupPosition: rows.count === 1 ? "only" : index === 0 ? "first" : index === rows.count - 1 ? "last" : "middle"
        interactive: false
        glyph: Displays.isInternal(modelData) ? Icons.laptop : Icons.monitor
        label: root.nameOf(modelData)
        sublabel: root.detailsOf(modelData)
        accessibleName: label + (modelData.name === root.hostScreen ? ", showing this panel" : "")

        // The slot runs right to left: the dot sits at the far end, the workspaces before it.
        trailing: [
          Rectangle {
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            width: Theme.displaysHereDot
            height: width
            radius: width / 2
            color: modelData.name === root.hostScreen ? Theme.accent : "transparent"
          },
          Text {
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            rightPadding: 4
            text: root.workspacesFor(modelData)
            color: Theme.subtle
            font.family: Theme.uiFont
            font.pixelSize: 12
            font.weight: Theme.weightMedium
          }
        ]
      }
    }
  }

  // One monitor on the canvas: the wallpaper cropped to its shape under a light veil, a
  // name plate in the corner, and the accent ring when it is the one being arranged.
  component DisplayTile: Item {
    id: tile

    property string label: ""
    property var rect: null
    property bool selected: false
    property bool draggable: false
    // Inline components cannot see the file's ids, so the canvas is handed in.
    property var area: null

    // The label as the motion log can carry it.
    readonly property string tag: label.replace(/\s+/g, "_")
    readonly property bool held: draggable && area !== null && area.dragging

    x: xSpring.value
    y: ySpring.value
    width: wSpring.value
    height: hSpring.value
    z: selected ? 1 : 0

    // Hands a spring that was following the pointer on to its place, from `from` (where the
    // pointer let go: letting go can land the spring on a target before it is free to travel)
    // at the pointer's speed `v`. The speed is held to what lands without passing the place, and
    // one heading the other way is dropped.
    function thrown(spring, from, v) {
      if (Theme.reduceMotion || !spring.animate)
        return;
      spring.value = from;
      if (spring.value !== spring.target)
        spring.kick(Motion.seedVelocity(from, spring.target, v, spring.omega));
    }

    // Four springs on one omega, so a tile's edges arrive together. Labels carry the monitor name.
    MorphSpring {
      id: xSpring

      target: tile.rect ? tile.rect.x * tile.area.fit + tile.area.originX + (tile.held ? tile.area.dragX : 0) : 0
      omega: Theme.microOmega
      animate: !tile.held
      label: "disp." + tile.tag + ".x"
    }

    MorphSpring {
      id: ySpring

      target: tile.rect ? tile.rect.y * tile.area.fit + tile.area.originY + (tile.held ? tile.area.dragY : 0) : 0
      omega: Theme.microOmega
      animate: !tile.held
      label: "disp." + tile.tag + ".y"
    }

    MorphSpring {
      id: wSpring

      target: tile.rect ? tile.rect.w * tile.area.fit : 0
      omega: Theme.microOmega
      label: "disp." + tile.tag + ".w"
    }

    MorphSpring {
      id: hSpring

      target: tile.rect ? tile.rect.h * tile.area.fit : 0
      omega: Theme.microOmega
      label: "disp." + tile.tag + ".h"
    }

    RoundedClip {
      anchors.fill: parent
      radius: Theme.displaysTileRadius

      Rectangle {
        anchors.fill: parent
        color: Theme.base
      }

      Image {
        anchors.fill: parent
        source: Wallpapers.url
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 480
        asynchronous: true
        cache: true
        visible: status === Image.Ready
      }

      Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.surface, Theme.displaysTileVeil)
      }
    }

    Rectangle {
      anchors.fill: parent
      radius: Theme.displaysTileRadius
      color: "transparent"
      border.width: tile.selected ? 2 : 1
      border.color: tile.selected ? Theme.accent : Theme.withAlpha("white", 0.1)
    }

    Rectangle {
      x: Theme.displaysPlateInset
      y: parent.height - height - Theme.displaysPlateInset
      width: plateText.implicitWidth + 20
      height: Theme.displaysPlateHeight
      radius: height / 2
      color: Theme.withAlpha(Theme.surface, Theme.displaysPlateAlpha)

      Text {
        id: plateText

        anchors.centerIn: parent
        text: tile.label
        color: Theme.text
        font.family: Theme.uiFont
        font.pixelSize: Theme.controlTileSubSize
        font.weight: Theme.weightSemi
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: !tile.draggable ? Qt.ForbiddenCursor : tile.area.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
      hoverEnabled: true
      // The panel is the anchor: it shows the forbidden pointer and lets clicks through.
      acceptedButtons: tile.draggable ? Qt.LeftButton : Qt.NoButton
      preventStealing: true

      property point start
      // The pointer's recent speed along each axis, for the release.
      readonly property var speedX: Motion.tracker()
      readonly property var speedY: Motion.tracker()

      onPressed: function (mouse) {
        start = mapToItem(tile.area, mouse.x, mouse.y);
        tile.area.dragX = 0;
        tile.area.dragY = 0;
        speedX.reset();
        speedY.reset();
        tile.area.dragging = true;
      }

      onPositionChanged: function (mouse) {
        var p = mapToItem(tile.area, mouse.x, mouse.y);
        tile.area.dragX = p.x - start.x;
        tile.area.dragY = p.y - start.y;
        var now = Date.now();
        speedX.push(now, p.x);
        speedY.push(now, p.y);
      }

      onReleased: {
        var moved = Math.abs(tile.area.dragX) + Math.abs(tile.area.dragY) > 2;
        var spot = moved ? tile.area.snap(tile.area.toLayoutX(tile.x), tile.area.toLayoutY(tile.y)) : null;
        var now = Date.now();
        var px = tile.x, py = tile.y;
        // The spring takes over from where the pointer let go.
        tile.area.dragging = false;
        if (spot)
          tile.area.commit(spot);
        // And at the pointer's speed, so the tile glides into its place rather than stopping
        // dead and then setting off.
        tile.thrown(xSpring, px, speedX.velocity(now));
        tile.thrown(ySpring, py, speedY.velocity(now));
      }

      onCanceled: tile.area.dragging = false
    }
  }
}
