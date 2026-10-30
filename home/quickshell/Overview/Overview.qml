import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui
import "../Commons/Fuzzy.js" as Fuzzy

// The Overview: the workspaces pill grows out of its own top-left corner into a card per
// workspace holding live thumbnails of its windows. One per output, opened on the focused one.
// Type to filter (fuzzy, over title and app), arrows or Tab to move the selection, Return to
// go to the window, drag a window onto another card to move it there.
//
// Not an IslandSurface: that grows from the island pill, centred. It keeps that surface's
// window handling, though (a parked window so an open is a resize and not a new window, the
// first presented frame before the morph starts, the focus priming), because they were all
// learnt the hard way; see Ui/IslandSurface.qml.
Variants {
  id: root

  model: Quickshell.screens

  PanelWindow {
    id: win

    required property var modelData

    readonly property string key: "overview"
    readonly property string screenName: win.screen ? win.screen.name : ""

    property bool open: false
    property string query: ""
    // The selected window's address.
    property string selected: ""
    // Set while a window is lifted: its address, where the pointer is, and what is under it.
    property string dragAddress: ""
    property var dragInfo: null
    property real dragX: 0
    property real dragY: 0
    // The workspace under the pointer, 0 for the "New" strip, -1 for neither.
    property int dropWs: -1

    readonly property bool focused: Monitors.isFocused(win.screen)

    // ---- what is shown ----

    readonly property var ids: WindowList.idsFor(win.screenName)
    readonly property var outSize: WindowList.outputSize(win.screenName)
    readonly property real dpr: win.devicePixelRatio > 0 ? win.devicePixelRatio : 1

    // Reading order: workspace, then left to right, then top to bottom.
    readonly property var mine: {
      var out = [];
      var all = WindowList.windows;
      for (var i = 0; i < all.length; i++) {
        if (all[i].output === win.screenName && win.ids.indexOf(all[i].ws) >= 0)
          out.push(all[i]);
      }
      out.sort(function (a, b) {
        return a.ws - b.ws || a.x - b.x || a.y - b.y;
      });
      return out;
    }

    // The filter's matches, address to { score, positions }, or null while the field is empty.
    // Title and the app's name both count; only the title is marked.
    readonly property var hits: {
      var q = win.query.trim();
      if (q === "")
        return null;
      var map = {};
      for (var i = 0; i < win.mine.length; i++) {
        var w = win.mine[i];
        var t = Fuzzy.match(q, w.title);
        var a = Fuzzy.match(q, w.appName);
        if (!t && !a)
          continue;
        map[w.address] = {
          score: Math.max(t ? t.score : 0, a ? a.score : 0),
          positions: t ? t.positions : []
        };
      }
      return map;
    }

    // What the selection moves through: every window, or only the matches.
    readonly property var nav: {
      if (!win.hits)
        return win.mine;
      return win.mine.filter(function (w) {
        return win.hits[w.address] !== undefined;
      });
    }
    readonly property int matchTotal: win.nav.length

    // ---- geometry ----

    readonly property real openWidth: win.screen ? win.screen.width - 2 * Theme.overviewMargin : 0
    readonly property int count: Math.max(1, win.ids.length)
    // Sized for at least the five persistent workspaces, so an output holding fewer (the second
    // monitor, with one) does not blow a lone card up to the width of the whole surface.
    readonly property int slots: Math.max(WindowList.persistent, win.count)
    readonly property real cardW: Math.max(Theme.overviewCardMin, Math.floor((win.openWidth - 2 * Theme.overviewInset - Theme.overviewStripWidth - win.slots * Theme.overviewCardGap) / win.slots))
    readonly property real cardH: Math.round(win.cardW * win.outSize.height / win.outSize.width)
    readonly property real openHeight: Theme.overviewCardsTop + win.cardH + Theme.overviewBottom
    readonly property real factor: win.cardW / win.outSize.width

    // The row's viewport, which runs out to the "New" strip; a row wider than it scrolls.
    readonly property real viewWidth: win.openWidth - 2 * Theme.overviewInset - Theme.overviewStripWidth
    readonly property real rowWidth: win.count * (win.cardW + Theme.overviewCardGap)
    readonly property real rowMax: Math.max(0, win.rowWidth - win.viewWidth)
    readonly property int selectedIndex: {
      for (var i = 0; i < win.mine.length; i++) {
        if (win.mine[i].address === win.selected)
          return win.ids.indexOf(win.mine[i].ws);
      }
      return Math.max(0, win.ids.indexOf(Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1));
    }
    readonly property real rowOffset: Math.max(0, Math.min(win.rowMax, (win.selectedIndex + 0.5) * (win.cardW + Theme.overviewCardGap) - win.viewWidth / 2))

    // The pill it grows out of, which is the workspaces pill's exact place and size.
    readonly property real pillX: Theme.overviewMargin + Bus.workspacesOffsetX
    readonly property real pillY: Theme.barMarginTop + Bus.workspacesOffsetY
    readonly property real pillWidth: WindowList.pillWidth

    // ---- opening and closing ----

    // The same hold the island surfaces use: the window is only the sliver it parks as until
    // the shape is wanted, and the spring waits for the first frame at full size.
    readonly property bool morphRunning: widthSpring.running || heightSpring.running
    readonly property bool showing: win.open || win.morphRunning || Math.abs(widthSpring.value - win.pillWidth) > 0.5 || Math.abs(heightSpring.value - Theme.barHeight) > 0.5

    readonly property real fullHeight: win.screen ? win.screen.height : 0
    property bool parked: true
    readonly property bool tall: !win.parked && win.fullHeight > 0 && win.height >= win.fullHeight - 1
    property bool retained: false

    // 0 at the pill, 1 once grown; what the ground and the contents fade on.
    readonly property real grown: win.openWidth > win.pillWidth ? Theme.clamp01((widthSpring.value - win.pillWidth) / (win.openWidth - win.pillWidth)) : 0

    function show() {
      field.text = "";
      win.cancelDrag();
      WindowList.refresh();
      win.selectFocused();
      // Everything else the island holds gives way; the Overview is the whole top of the screen.
      for (var i = 0; i < Bus.islandKeys.length; i++) {
        if (Bus.islandKeys[i] !== win.key)
          Bus.closeSurface(Bus.islandKeys[i]);
      }
      win.open = true;
    }

    function hide() {
      win.cancelDrag();
      win.open = false;
    }

    // Opens on the focused window of this output, else the first one.
    function selectFocused() {
      var pick = "";
      for (var i = 0; i < win.mine.length; i++) {
        if (win.mine[i].focused) {
          pick = win.mine[i].address;
          break;
        }
      }
      win.selected = pick !== "" ? pick : win.mine.length > 0 ? win.mine[0].address : "";
    }

    onNavChanged: {
      if (win.nav.length === 0)
        win.selected = "";
      else if (!win.nav.some(w => w.address === win.selected))
        win.selected = win.nav[0].address;
    }

    onQueryChanged: {
      // A new filter selects its first match, wherever the selection was.
      if (win.query.trim() !== "" && win.nav.length > 0)
        win.selected = win.nav[0].address;
    }

    // ---- the selection ----

    function indexOfSelected() {
      for (var i = 0; i < win.nav.length; i++) {
        if (win.nav[i].address === win.selected)
          return i;
      }
      return -1;
    }

    // One window on in reading order, wrapping from the last workspace round to the first.
    function step(dir) {
      var n = win.nav.length;
      if (n === 0)
        return;
      var i = win.indexOfSelected();
      win.selected = win.nav[(i + dir + n) % n].address;
    }

    function jump(last) {
      if (win.nav.length > 0)
        win.selected = win.nav[last ? win.nav.length - 1 : 0].address;
    }

    // The first window of the previous or next workspace that has one.
    function stepWorkspace(dir) {
      var i = win.indexOfSelected();
      if (i < 0)
        return;
      var here = win.nav[i].ws;
      var order = win.ids;
      var from = order.indexOf(here);
      for (var k = from + dir; k >= 0 && k < order.length; k += dir) {
        for (var j = 0; j < win.nav.length; j++) {
          if (win.nav[j].ws === order[k]) {
            win.selected = win.nav[j].address;
            return;
          }
        }
      }
    }

    function selectedInfo() {
      var i = win.indexOfSelected();
      return i >= 0 ? win.nav[i] : null;
    }

    function activate() {
      var w = win.selectedInfo();
      if (w)
        WindowList.focusWindow(w.address);
      win.hide();
    }

    function focusWindow(address) {
      WindowList.focusWindow(address);
      win.hide();
    }

    // The keyboard's drag: the selected window to the next or previous workspace.
    function shiftWorkspace(dir) {
      var w = win.selectedInfo();
      if (!w)
        return;
      var to = win.ids.indexOf(w.ws) + dir;
      if (to >= 0 && to < win.ids.length)
        WindowList.moveWindow(w.address, win.ids[to]);
    }

    function closeSelected() {
      var w = win.selectedInfo();
      if (w)
        WindowList.closeWindow(w.address);
    }

    function goTo(ws) {
      WindowList.goTo(ws);
      win.hide();
    }

    function newWorkspace() {
      win.goTo(WindowList.lowestEmpty());
    }

    // ---- dragging a window onto a card ----

    function cancelDrag() {
      win.dragAddress = "";
      win.dragInfo = null;
      win.dropWs = -1;
    }

    // Which card (or the strip) is under a point in the surface's coordinates.
    function targetAt(px, py) {
      for (var i = 0; i < cards.count; i++) {
        var card = cards.itemAt(i);
        if (!card)
          continue;
        var p = card.bodyItem.mapToItem(surface, 0, 0);
        if (px >= p.x && px < p.x + card.cardW && py >= p.y && py < p.y + card.cardH)
          return card.wsId;
      }
      var s = strip.mapToItem(surface, 0, 0);
      if (px >= s.x && px < s.x + strip.width && py >= s.y && py < s.y + strip.height)
        return 0;
      return -1;
    }

    function dragMoved(where) {
      win.dragX = where.x;
      win.dragY = where.y;
      var ws = win.targetAt(where.x, where.y);
      // Back over its own card is no move.
      win.dropWs = win.dragInfo && ws === win.dragInfo.ws ? -1 : ws;
    }

    function dragEnded() {
      var info = win.dragInfo;
      var to = win.dropWs;
      win.cancelDrag();
      if (!info || to < 0)
        return;
      WindowList.moveWindow(info.address, to === 0 ? WindowList.lowestEmpty() : to);
      win.selected = info.address;
    }

    // ---- the window ----

    screen: modelData
    visible: !Bus.locking && (win.showing || win.retained)
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-" + win.key

    anchors {
      top: true
      left: true
      right: true
    }

    implicitHeight: win.parked ? 1 : win.fullHeight
    exclusionMode: ExclusionMode.Ignore

    // Open, the whole window takes the pointer, so a click off the surface dismisses; not
    // open, nothing, so the shape on its way down does not swallow the clicks below it.
    mask: win.open ? null : emptyMask

    Region {
      id: emptyMask
    }

    property bool focusPrimed: false

    WlrLayershell.keyboardFocus: win.open ? (win.focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

    Timer {
      id: focusPrime

      interval: 75
      onTriggered: win.focusPrimed = true
    }

    onOpenChanged: {
      WindowList.watch(open);
      if (open) {
        focusPrimed = false;
        focusPrime.restart();
        Qt.callLater(function () {
          if (win.open)
            field.forceActiveFocus();
        });
      } else {
        focusPrime.stop();
        focusPrimed = false;
      }
    }

    onShowingChanged: {
      if (showing) {
        parkDelay.stop();
        retainTimer.stop();
        retained = true;
        parked = false;
        Bus.setOwner(win.key, win.screenName);
      } else {
        parkDelay.restart();
        if (Bus.ownerOf(win.key) === win.screenName)
          Bus.setOwner(win.key, "");
      }
    }

    Timer {
      id: parkDelay

      interval: Theme.surfacePark
      onTriggered: {
        if (win.showing)
          return;
        win.parked = true;
        retainTimer.restart();
      }
    }

    // A parked window holds a render context; one left unused for a while is let go.
    Timer {
      id: retainTimer

      interval: Theme.surfaceRetain
      onTriggered: if (win.parked)
        win.retained = false
    }

    Connections {
      target: Bus

      function onSurfaceToggled(key) {
        if (key !== win.key)
          return;
        if (win.open)
          win.hide();
        else if (win.focused)
          win.show();
      }

      function onSurfaceClosed(key) {
        if (key === win.key)
          win.hide();
      }

      // Another surface taking the island on this output takes the top of the screen from us.
      function onIslandClaimed(screen) {
        if (win.open && screen === win.screenName)
          win.hide();
      }
    }

    // The first frame at full size, before the shape moves: the same protocol the island
    // surfaces use, so the pill is never left behind a window that has not drawn yet.
    IslandOrigin {
      id: origin

      window: win
      frameItem: surface
      presentable: !Bus.locking && win.tall
    }

    MorphSpring {
      id: widthSpring

      animate: !Theme.reduceMotion && !win.parked
      target: win.open && origin.presented ? win.openWidth : win.pillWidth
    }

    MorphSpring {
      id: heightSpring

      animate: !Theme.reduceMotion && !win.parked
      target: win.open && origin.presented ? win.openHeight : Theme.barHeight
    }

    // A click anywhere off the surface dismisses.
    MouseArea {
      anchors.fill: parent
      enabled: win.open
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      onClicked: win.hide()
    }

    FrostedSurface {
      id: surface

      visible: win.tall
      clipContent: true
      // The ground comes in as the shape leaves the pill, which shows through until then.
      backdropOpacity: Theme.clamp01(win.grown * 6)

      x: snap(win.pillX)
      y: snap(win.pillY)
      implicitWidth: widthSpring.value
      implicitHeight: heightSpring.value
      surfaceRadius: Math.min(height / 2, Theme.panelRadius)

      // Takes the clicks that miss every control, which would otherwise dismiss.
      MouseArea {
        anchors.fill: parent
        enabled: win.open
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      }

      // Everything the surface draws is laid out at its final size and uncovered by the
      // growing shape; it fades in as the shape lands.
      Item {
        id: bodyHolder

        readonly property real shownOpacity: win.open && origin.presented ? 1 : 0

        width: win.openWidth
        height: win.openHeight
        opacity: shownOpacity
        visible: opacity > 0

        Behavior on opacity {
          Morph {
            duration: bodyHolder.shownOpacity > 0 ? Theme.duration(Theme.morphEnter) : Theme.duration(Theme.morphContent)
          }
        }

        // Search row, as the launcher's.
        Text {
          x: Theme.launcherGlyphLeft
          y: Theme.overviewSearchHeight / 2 - height / 2
          text: Icons.search
          color: Theme.muted
          font.family: Theme.iconFont
          font.pixelSize: Theme.launcherGlyphSize
        }

        TextInput {
          id: field

          x: Theme.launcherTextLeft
          y: Theme.overviewSearchHeight / 2 - height / 2
          width: win.openWidth - x - 220
          color: Theme.text
          font.family: Theme.uiFont
          font.pixelSize: Theme.launcherSearchSize
          selectByMouse: true
          selectionColor: Theme.withAlpha(Theme.accent, Theme.fillSelected)
          clip: true
          onTextChanged: win.query = text

          cursorDelegate: Rectangle {
            width: 1.5
            height: 20
            radius: 0.75
            color: Theme.accent
          }

          Text {
            text: "Filter windows…"
            color: Theme.muted
            font: field.font
            visible: field.text.length === 0
          }

          Keys.onPressed: function (event) {
            var shift = (event.modifiers & Qt.ShiftModifier) !== 0;
            var ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
            switch (event.key) {
            case Qt.Key_Escape:
              // Clears the filter first, then closes.
              if (field.text !== "")
                field.text = "";
              else
                win.hide();
              break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
              win.activate();
              break;
            case Qt.Key_Left:
              if (shift)
                win.shiftWorkspace(-1);
              else
                win.step(-1);
              break;
            case Qt.Key_Right:
              if (shift)
                win.shiftWorkspace(1);
              else
                win.step(1);
              break;
            case Qt.Key_Up:
              win.stepWorkspace(-1);
              break;
            case Qt.Key_Down:
              win.stepWorkspace(1);
              break;
            case Qt.Key_Tab:
              win.step(1);
              break;
            case Qt.Key_Backtab:
              win.step(-1);
              break;
            case Qt.Key_Home:
              win.jump(false);
              break;
            case Qt.Key_End:
              win.jump(true);
              break;
            case Qt.Key_W:
              if (!ctrl)
                return;
              win.closeSelected();
              break;
            default:
              return;
            }
            event.accepted = true;
          }
        }

        // The count, or what the filter found.
        Text {
          x: win.openWidth - Theme.overviewMetaRight - implicitWidth
          y: Theme.overviewSearchHeight / 2 - height / 2
          text: {
            if (win.hits)
              return win.matchTotal + (win.matchTotal === 1 ? " match" : " matches");
            var n = win.mine.length;
            return win.ids.length + (win.ids.length === 1 ? " workspace" : " workspaces") + " · " + n + (n === 1 ? " window" : " windows");
          }
          color: win.hits && win.matchTotal > 0 ? Theme.accent : Theme.inkTertiary
          font.family: Theme.uiFont
          font.pixelSize: Theme.overviewMetaSize
        }

        Rectangle {
          x: Theme.launcherInset
          y: Theme.overviewSearchHeight
          width: win.openWidth - 2 * Theme.launcherInset
          height: 1
          color: Theme.withAlpha(Theme.separator, 0.6)
        }

        // The cards, in a viewport that scrolls only when they do not all fit.
        Item {
          id: viewport

          x: Theme.overviewInset
          width: win.viewWidth
          height: win.openHeight
          clip: win.rowMax > 0

          Item {
            id: row

            x: -win.rowOffset

            Behavior on x {
              enabled: !Theme.reduceMotion

              MicroSpring {}
            }

            Repeater {
              id: cards

              model: win.showing ? win.ids : []

              OverviewCard {
                required property int modelData
                required property int index

                wsId: modelData
                x: index * (win.cardW + Theme.overviewCardGap)
                cardW: win.cardW
                cardH: win.cardH
                factor: win.factor
                pixelRatio: win.dpr
                space: surface
                active: {
                  var ws = WindowList.workspaceFor(modelData);
                  return ws !== null && ws.active;
                }
                wins: win.mine.filter(w => w.ws === modelData)
                selected: win.selected
                hits: win.hits
                liftedAddress: win.dragAddress
                dropTarget: win.dragAddress !== "" && win.dropWs === modelData
                near: win.selectedInfo() !== null && win.selectedInfo().ws === modelData
                capturing: win.open && origin.presented && x + cardW > win.rowOffset && x < win.rowOffset + win.viewWidth

                onWindowClicked: address => win.focusWindow(address)
                onEmptyClicked: win.goTo(modelData)
                onWindowDragStarted: (info, where, body) => {
                  win.dragInfo = info;
                  win.dragAddress = info.address;
                  win.selected = info.address;
                  lift.grab(body, where);
                }
                onWindowDragMoved: where => win.dragMoved(where)
                onWindowDragEnded: win.dragEnded()
              }
            }
          }
        }

        // "New": a window dropped here goes to the lowest workspace with nothing on it.
        Item {
          id: strip

          x: win.openWidth - Theme.overviewInset - Theme.overviewStripWidth
          y: Theme.overviewCardsTop
          width: Theme.overviewStripWidth
          height: win.cardH

          readonly property bool lit: win.dragAddress !== ""
          readonly property color ink: lit ? Theme.accent : Theme.inkTertiary

          Text {
            x: (parent.width - implicitWidth) / 2
            y: Theme.overviewLabelY + 2 - Theme.overviewCardsTop
            text: "New"
            color: strip.ink
            font.family: Theme.uiFont
            font.pixelSize: Theme.overviewCountSize
            font.weight: win.dragAddress !== "" && win.dropWs === 0 ? Theme.weightSemi : Theme.weightRegular
          }

          Rectangle {
            anchors.fill: parent
            radius: Theme.overviewCardRadius
            color: Theme.withAlpha(Theme.accent, Theme.overviewDropWash)
            opacity: win.dragAddress !== "" && win.dropWs === 0 ? 1 : 0
          }

          DashedOutline {
            anchors.fill: parent
            cornerRadius: Theme.overviewCardRadius
            strokeColor: strip.lit ? Theme.accent : Theme.separator
          }

          StrokeIcon {
            anchors.centerIn: parent
            path: IconPaths.plus
            size: Theme.overviewStripGlyph
            strokeWidth: 1.75
            color: strip.ink
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: win.newWorkspace()
          }
        }

        // The window in the hand: a copy of its thumbnail, a little smaller and tilted, that
        // follows the pointer on the compositor drag pile's spring, so it trails and swings
        // the way the pile does.
        Item {
          id: lift

          property Item source: null
          property real posX: 0
          property real posY: 0
          property real velX: 0
          property real velY: 0

          readonly property bool carrying: win.dragAddress !== "" && source !== null
          readonly property real w: source ? source.width * Theme.overviewLiftScale : 0
          readonly property real h: source ? source.height * Theme.overviewLiftScale : 0
          readonly property real targetX: win.dragX - w / 2
          readonly property real targetY: win.dragY - h / 2

          function grab(body, where) {
            source = body;
            var p = body.mapToItem(surface, 0, 0);
            posX = p.x;
            posY = p.y;
            velX = 0;
            velY = 0;
          }

          function step(dt) {
            var k = Theme.overviewLiftStiffness;
            var c = 2 * Theme.overviewLiftDamping * Math.sqrt(k);
            // Fixed 4 ms sub-steps keep it stable through a dropped frame.
            var left = Math.min(dt, 0.1);
            while (left > 0) {
              var h = Math.min(0.004, left);
              velX += (k * (targetX - posX) - c * velX) * h;
              velY += (k * (targetY - posY) - c * velY) * h;
              posX += velX * h;
              posY += velY * h;
              left -= h;
            }
          }

          FrameAnimation {
            running: lift.carrying && !Theme.reduceMotion
            onTriggered: lift.step(frameTime)
          }

          Binding {
            when: Theme.reduceMotion && lift.carrying
            lift.posX: lift.targetX
            lift.posY: lift.targetY
          }

          // Sits above every card; no input, so the pointer still finds the card under it.
          z: 100
          visible: carrying
          x: posX
          y: posY
          width: w
          height: h
          rotation: Theme.overviewLiftTilt

          ShaderEffectSource {
            anchors.fill: parent
            sourceItem: lift.source
            live: true
          }

          Rectangle {
            anchors.fill: parent
            radius: Theme.overviewWindowRadius
            color: "transparent"
            border.width: 2
            border.color: Theme.accent
          }
        }
      }
    }
  }
}
