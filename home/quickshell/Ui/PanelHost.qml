import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services

// Reusing one surface lets geometry animate between panels.
//
// This is a layer-shell PanelWindow rather than a PopupWindow because panels
// are summoned by hotkey as well as by click. An xdg-popup only receives keys
// after a click or hover has routed focus through its parent surface, so
// Escape and arrow keys did nothing on a hotkey-opened panel. A layer surface
// can take keyboard focus on its own; see the focus prime below.
//
// The card's motion is the island's own. Measured off the source recording at
// 60 fps, every surface in that shell changes shape on one critically damped
// spring - it leaves slowly, accelerates, arrives and stops, with no fade
// carrying it - and a panel that snapped in below the bar on an OutCubic and
// an opacity ramp was the one surface in this shell that moved on a different
// physics. The card now grows out of the island pill's own rect on the
// measured curve, holds its contents laid out while the shape uncovers them,
// and melts back into the pill on the way down, exactly as the launcher and
// the control centre do.
PanelWindow {
  id: root

  required property Item barItem
  property string activePanel: ""

  default property alias panels: panelHolder.data

  readonly property bool open: current !== null

  readonly property var panelList: {
    var out = [];
    for (var i = 0; i < panelHolder.children.length; i++) {
      var c = panelHolder.children[i];
      if (c.panelName !== undefined && c.panelName !== "")
        out.push(c);
    }
    return out;
  }

  readonly property var current: {
    for (var i = 0; i < panelList.length; i++) {
      if (panelList[i].panelName === root.activePanel)
        return panelList[i];
    }
    return null;
  }

  // The panel that is on its way out. It stays active for the length of the
  // close morph, so its contents are still there to be clipped away as the
  // card shrinks into the pill, which is what the source's own close does -
  // content that vanished on the first frame would leave an empty box
  // sliding shut. Cleared once the morph has finished.
  property string closingPanel: ""

  readonly property var barWindow: barItem ? barItem.QsWindow.window : null

  // The island pill's collapsed footprint, which is what the card grows out
  // of and back into. The card is a separate layer surface from the bar, and
  // the island keeps drawing underneath, so a card that starts and ends
  // exactly on the pill hands the island back without a visible cut.
  readonly property int pillWidth: Theme.islandCollapsedWidth(Media.active, Recorder.recording)
  readonly property int pillHeight: Theme.barHeight
  readonly property int pillY: Theme.barMarginTop

  // Distance from the top of the screen to the bottom of the bar. The bar is
  // a top-anchored layer surface, so its own margin is part of the offset.
  readonly property int barStrip: Theme.barMarginTop + Theme.barHeight
  readonly property int cardY: barStrip + Theme.gapsOut

  readonly property int screenWidth: root.screen ? root.screen.width : 0
  readonly property int screenHeight: root.screen ? root.screen.height : 0
  readonly property int screenLimit: screenHeight > 0 ? screenHeight - cardY - Theme.gapsOut : 800

  readonly property int cardWidth: current ? current.preferredWidth : pillWidth
  readonly property int cardHeight: current ? Math.min(current.preferredHeight, screenLimit) : pillHeight

  // The settled size of the panel the card is holding or last held. The
  // contents are laid out at this size no matter what the card is doing, so
  // a morph uncovers or covers fixed content instead of squishing it - the
  // launcher's rows do not reflow while the shape grows over them either.
  property int heldWidth: Theme.panelWidthNarrow
  property int heldHeight: Theme.panelMaxHeight
  onCardWidthChanged: if (current)
    heldWidth = cardWidth
  onCardHeightChanged: if (current)
    heldHeight = cardHeight

  // mapToItem is a one-shot; the watcher is what makes this binding re-run
  // when the bar relayouts underneath the anchor.
  TransformWatcher {
    id: anchorWatcher
    a: root.barWindow ? root.barWindow.contentItem : null
    b: root.restAnchor
  }

  // Every panel in this host anchors to the island, so the island is also the
  // anchor while the card is shut: the pill the card grows out of sits on the
  // island's own centre line, wherever the bar currently puts it.
  readonly property var restAnchor: current && current.anchorTarget ? current.anchorTarget : (panelList.length > 0 ? panelList[0].anchorTarget : null)

  // Centre over the island pill when shut and over the active widget when
  // open, clamped to the screen margins.
  readonly property real cardX: {
    anchorWatcher.transform;
    if (!barWindow)
      return 0;
    var target = restAnchor;
    if (!target)
      return screenWidth / 2;
    var point = target.mapToItem(barWindow.contentItem, 0, 0);
    var centre = point.x + target.width / 2;
    if (!current)
      return centre - pillWidth / 2;
    var x = centre - cardWidth / 2;
    return Math.max(Theme.gapsOut, Math.min(screenWidth - cardWidth - Theme.gapsOut, x));
  }

  // Push host state because declarative child panels cannot bind back to it.
  function syncPanels() {
    for (var i = 0; i < panelList.length; i++) {
      panelList[i].active = panelList[i].panelName === root.activePanel || panelList[i].panelName === root.closingPanel;
      panelList[i].screenLimit = root.screenLimit;
    }
  }

  // Holds the outgoing panel active for the length of the close morph.
  Timer {
    id: closeHold

    interval: Theme.morphPanel + 40
    onTriggered: {
      root.closingPanel = "";
      root.syncPanels();
    }
  }

  // The panel that was open before the current one, so a close can hold it
  // active for the length of the shrink.
  property string lastPanel: ""

  onActivePanelChanged: {
    if (activePanel === "") {
      // A close. The panel that was open keeps drawing until the shrink has
      // clipped it back into the pill, which is what the source's own close
      // does - content that vanished on the first frame would leave an empty
      // box sliding shut.
      if (lastPanel !== "") {
        closingPanel = lastPanel;
        closeHold.restart();
      }
    } else {
      closingPanel = "";
      closeHold.stop();
    }
    lastPanel = activePanel;
    syncPanels();
  }
  onPanelListChanged: syncPanels()
  onScreenLimitChanged: syncPanels()
  onClosingPanelChanged: syncPanels()
  Component.onCompleted: syncPanels()

  signal dismissed

  screen: root.barWindow ? root.barWindow.screen : null
  visible: open || card.opacity > 0
  color: "transparent"

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "quickshell-panel"

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  exclusionMode: ExclusionMode.Ignore

  // Prime with Exclusive on every open, then settle to OnDemand. Hyprland
  // focuses OnDemand when a surface first maps, but not when an already-mapped
  // fade-out surface goes None -> OnDemand; Exclusive covers that, and also
  // wins focus back when the previous app had the pointer constrained.
  // Staying Exclusive is not an option: it makes Hyprland route every pointer
  // event to this surface regardless of which output the cursor is over,
  // which would leave the dismissal twins below unable to see a click.
  property bool focusPrimed: false

  readonly property int focusPrimeDuration: 75

  // Bound to `open`, never `visible`. The window stays mapped through the
  // fade-out so the opacity animation has something to animate, but key and
  // click ownership must release the moment the logical close fires.
  WlrLayershell.keyboardFocus: root.open ? (root.focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

  Timer {
    id: focusPrime
    interval: root.focusPrimeDuration
    onTriggered: root.focusPrimed = true
  }

  onOpenChanged: {
    if (open) {
      focusPrimed = false;
      focusPrime.restart();
      // Layer-shell grants the surface focus, but Qt still needs an
      // active-focus target inside it before Keys handlers fire. Defer so the
      // surface is mapped and children have laid out.
      Qt.callLater(function () {
        if (root.open)
          keys.forceActiveFocus();
      });
    } else {
      focusPrime.stop();
      focusPrimed = false;
    }
  }

  // Outside-click dismissal. Clicks landing in the bar strip are replayed onto
  // the bar widget underneath instead, so clicking a different bar icon
  // switches panels in one click rather than merely closing this one.
  MouseArea {
    id: dismissArea

    anchors.fill: parent
    enabled: root.open
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    hoverEnabled: true

    property bool overBar: false

    cursorShape: overBar ? Qt.PointingHandCursor : Qt.ArrowCursor

    function inBarRegion(y) {
      return y <= root.barStrip;
    }

    function targetAt(x, y) {
      if (!root.barWindow || !root.barWindow.contentItem)
        return null;
      var targets = root.barItem.clickTargets;
      if (!targets)
        return null;
      for (var i = targets.length - 1; i >= 0; i--) {
        var t = targets[i];
        if (!t || !t.triggerPress || !t.visible || t.opacity === 0)
          continue;
        var pos = t.mapToItem(root.barWindow.contentItem, 0, 0);
        // The bar surface sits barMarginTop below the top of the screen.
        var top = pos.y + Theme.barMarginTop;
        if (x >= pos.x && x <= pos.x + t.width && y >= top && y <= top + t.height)
          return t;
      }
      return null;
    }

    onPositionChanged: function (mouse) {
      overBar = inBarRegion(mouse.y) && targetAt(mouse.x, mouse.y) !== null;
    }

    onExited: overBar = false

    onClicked: function (mouse) {
      // While Exclusive is priming, Hyprland may route a click from another
      // output here with translated coordinates. Never read that as a click
      // on this output's bar.
      if (root.focusPrimed && inBarRegion(mouse.y)) {
        var t = targetAt(mouse.x, mouse.y);
        if (t) {
          t.triggerPress(mouse.button);
          return;
        }
      }
      root.dismissed();
    }
  }

  Rectangle {
    id: card

    x: root.cardX
    y: root.open ? root.cardY : root.pillY
    width: root.cardWidth
    height: root.cardHeight
    radius: root.open ? Theme.cornerRadius : Theme.islandRadius
    color: Theme.base
    border.width: 1
    border.color: Theme.overlay
    clip: true

    // Opaque while the shape is bigger than the pill, whatever is happening:
    // the open and the switches are reveals, and the close shrinks the full
    // card into the island before letting go. Only once the card is back on
    // the pill's own rect does it fade, and by then the island underneath is
    // drawing the same pixels.
    opacity: root.open || card.width > root.pillWidth + 0.5 || card.height > root.pillHeight + 0.5 ? 1 : 0

    // True from the first frame of a morph to the last: the geometry
    // Behaviors must own every change while the card is on screen, including
    // the close, and must not own the shut-state's idle re-targeting to the
    // island pill (which happens invisibly).
    readonly property bool morphing: root.open || opacity > 0.01

    Behavior on x {
      enabled: card.morphing
      Morph {
        duration: Theme.morphPanel
      }
    }
    Behavior on y {
      enabled: card.morphing
      Morph {
        duration: Theme.morphPanel
      }
    }
    Behavior on width {
      enabled: card.morphing
      Morph {
        duration: Theme.morphPanel
      }
    }
    Behavior on height {
      enabled: card.morphing
      Morph {
        duration: Theme.morphPanel
      }
    }
    Behavior on radius {
      enabled: card.morphing
      Morph {
        duration: Theme.morphPanel
      }
    }
    Behavior on opacity {
      Morph {
        duration: Theme.morphContent
      }
    }

    PanelKeyCatcher {
      id: keys

      anchors.fill: parent
      blocked: root.current ? root.current.editing : false

      onCloseRequested: root.dismissed()
      onMoveRequested: function (dx, dy) {
        if (root.current && root.current.navigate)
          root.current.navigate(dx, dy);
      }
      onActivateRequested: {
        if (root.current && root.current.activate)
          root.current.activate();
      }

      // Sized at the panel's settled metrics and hung from the top centre of
      // the card, so the growing or shrinking shape reveals and covers it
      // rather than reflowing it.
      Item {
        id: panelHolder

        x: (parent.width - width) / 2
        y: 0
        width: root.heldWidth
        height: root.heldHeight
      }
    }
  }

  // The panel surface spans only its own screen and the compositor hit-tests
  // pointer input per output, so dismissArea can never see a click on another
  // monitor. Give every other output a transparent catcher whose only job is
  // to notice that click. Keyboard focus is None so merely crossing onto one
  // does not take focus away from the card.
  Variants {
    model: root.open ? Quickshell.screens : []

    PanelWindow {
      required property var modelData

      screen: modelData
      // Compare by name: the host's own output must never be covered.
      visible: root.open && root.screen !== null && modelData.name !== root.screen.name
      color: "transparent"

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "quickshell-panel-dismiss"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      exclusionMode: ExclusionMode.Ignore

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: root.dismissed()
      }
    }
  }
}
