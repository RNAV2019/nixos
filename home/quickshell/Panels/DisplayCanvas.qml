import QtQuick
import qs.Commons
import qs.Services

// A map of the monitor layout in Hyprland's logical coordinates, fitted to the
// card. Dragging a monitor snaps it flush against its neighbours; nothing
// reaches the compositor until the drag is released.
Item {
  id: root

  property var monitors: []
  property string selected: ""

  // A dragged tile is clamped to the view box, but clip is the backstop that
  // keeps a rectangle from ever painting outside the card.
  clip: true

  signal selectRequested(string name)
  signal moved(string name, int x, int y)

  // Logical rectangles, which is what Hyprland positions outputs by.
  readonly property var rects: {
    var out = [];
    for (var i = 0; i < monitors.length; i++) {
      var m = monitors[i];
      out.push({
        name: m.name,
        x: m.x,
        y: m.y,
        w: Displays.logicalWidth(m),
        h: Displays.logicalHeight(m),
        disabled: m.disabled,
        mirrorOf: m.mirrorOf,
        mode: Displays.formatMode(m)
      });
    }
    return out;
  }

  // Pad the bounding box so a monitor dragged past the edge stays on screen.
  readonly property var view: {
    if (rects.length === 0)
      return {
        x: 0,
        y: 0,
        w: 1,
        h: 1
      };

    var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    for (var i = 0; i < rects.length; i++) {
      var r = rects[i];
      minX = Math.min(minX, r.x);
      minY = Math.min(minY, r.y);
      maxX = Math.max(maxX, r.x + r.w);
      maxY = Math.max(maxY, r.y + r.h);
    }

    var padX = Math.max(1, (maxX - minX) * 0.25);
    var padY = Math.max(1, (maxY - minY) * 0.25);
    return {
      x: minX - padX,
      y: minY - padY,
      w: (maxX - minX) + padX * 2,
      h: (maxY - minY) + padY * 2
    };
  }

  readonly property real factor: Math.min(width / view.w, height / view.h)
  readonly property real offsetX: (width - view.w * factor) / 2
  readonly property real offsetY: (height - view.h * factor) / 2

  readonly property real snapDistance: factor > 0 ? Theme.displaySnapDistance / factor : 0

  function toScreenX(vx) {
    return offsetX + (vx - view.x) * factor;
  }
  function toScreenY(vy) {
    return offsetY + (vy - view.y) * factor;
  }

  // Keep a dragged monitor inside the mapped area. The view box is padded
  // well beyond the monitors themselves, so this only bites at the edge of
  // the card rather than fencing the layout in.
  function _clamp(pos, size, axis) {
    var min = axis === "x" ? view.x : view.y;
    var span = axis === "x" ? view.w : view.h;
    var max = min + span - size;
    if (max < min)
      return min;
    return Math.max(min, Math.min(max, pos));
  }

  // Snap one axis against every edge of every other monitor: butted against
  // it on either side, or aligned with either of its own edges.
  function _snap(name, pos, size, axis) {
    var best = pos;
    var bestDelta = root.snapDistance;

    for (var i = 0; i < rects.length; i++) {
      var o = rects[i];
      if (o.name === name || o.disabled)
        continue;

      var oPos = axis === "x" ? o.x : o.y;
      var oSize = axis === "x" ? o.w : o.h;
      var candidates = [oPos + oSize, oPos - size, oPos, oPos + oSize - size];

      for (var j = 0; j < candidates.length; j++) {
        var delta = Math.abs(candidates[j] - pos);
        if (delta < bestDelta) {
          bestDelta = delta;
          best = candidates[j];
        }
      }
    }

    return Math.round(best);
  }

  Rectangle {
    anchors.fill: parent
    radius: Theme.panelRowRadius
    color: Theme.withAlpha(Theme.overlay, 0.35)
    border.width: 1
    border.color: Theme.withAlpha(Theme.overlay, Theme.borderNormal)
  }

  Repeater {
    model: root.rects

    Rectangle {
      id: tile

      required property var modelData

      // Position while dragging. Reset whenever the model reports new
      // geometry, because the delegate is rebuilt with it.
      property real vx: modelData.x
      property real vy: modelData.y
      property bool dragging: false

      readonly property bool isSelected: root.selected === modelData.name

      x: root.toScreenX(vx)
      y: root.toScreenY(vy)
      width: Math.max(2, modelData.w * root.factor)
      height: Math.max(2, modelData.h * root.factor)

      radius: Theme.displayRadius
      opacity: modelData.disabled ? 0.35 : 1
      z: dragging ? 2 : (isSelected ? 1 : 0)

      color: Theme.rowFill(area.containsMouse, isSelected)
      border.width: 1
      border.color: isSelected ? Theme.withAlpha(Theme.accent, 0.9) : Theme.withAlpha(Theme.text, Theme.borderNormal)

      Behavior on color {
        ColorAnimation {
          duration: Theme.animFast
        }
      }

      Column {
        anchors.centerIn: parent
        width: parent.width - Theme.spacingSm
        spacing: 0

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          text: tile.modelData.name
          color: Theme.text
          // Connector names are identifiers; keep them monospaced.
          font.family: Theme.monoFont
          font.pixelSize: Theme.fontSizeSmall
          font.weight: tile.isSelected ? Theme.weightSemi : Theme.weightRegular
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          visible: tile.height > 34
          text: tile.modelData.mirrorOf !== "" ? "mirrors " + tile.modelData.mirrorOf : tile.modelData.mode
          color: Theme.muted
          font.family: Theme.monoFont
          font.pixelSize: Theme.fontSizeSmall
          elide: Text.ElideRight
        }
      }

      MouseArea {
        id: area

        // Press point and tile origin, both in canvas coordinates. The mouse
        // area travels with the tile, so a delta taken from its own local
        // coordinates is measured against an origin that the previous frame
        // just moved. That feeds back on itself and the drag judders. Mapping
        // every position into the canvas cancels the tile's own motion out.
        property real pressX: 0
        property real pressY: 0
        property real originX: 0
        property real originY: 0
        property bool draggedFar: false

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        onPressed: function (mouse) {
          var p = area.mapToItem(root, mouse.x, mouse.y);
          pressX = p.x;
          pressY = p.y;
          originX = tile.vx;
          originY = tile.vy;
          draggedFar = false;
          root.selectRequested(tile.modelData.name);
        }

        onPositionChanged: function (mouse) {
          if (!pressed || root.factor <= 0)
            return;

          var p = area.mapToItem(root, mouse.x, mouse.y);

          if (!draggedFar && Math.abs(p.x - pressX) + Math.abs(p.y - pressY) < 3)
            return;

          draggedFar = true;
          tile.dragging = true;

          var w = tile.modelData.w;
          var h = tile.modelData.h;

          // Clamp before snapping so a monitor cannot be thrown off the map,
          // and so the snap candidates are still the ones nearest to it.
          var wantX = root._clamp(originX + (p.x - pressX) / root.factor, w, "x");
          var wantY = root._clamp(originY + (p.y - pressY) / root.factor, h, "y");

          tile.vx = root._snap(tile.modelData.name, wantX, w, "x");
          tile.vy = root._snap(tile.modelData.name, wantY, h, "y");
        }

        onReleased: {
          tile.dragging = false;
          if (!draggedFar)
            return;
          if (tile.vx !== tile.modelData.x || tile.vy !== tile.modelData.y)
            root.moved(tile.modelData.name, tile.vx, tile.vy);
        }

        onCanceled: {
          tile.dragging = false;
          tile.vx = tile.modelData.x;
          tile.vy = tile.modelData.y;
        }

        // Let the panel handle the wheel.
        onWheel: function (wheel) {
          wheel.accepted = false;
        }
      }
    }
  }

  Text {
    anchors.centerIn: parent
    visible: root.rects.length === 0
    text: "No displays detected"
    color: Theme.muted
    font.family: Theme.uiFont
    font.pixelSize: Theme.fontSize
  }
}
