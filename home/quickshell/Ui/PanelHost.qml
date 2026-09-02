import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// Reusing one surface lets geometry animate between panels.
//
// This is a layer-shell PanelWindow rather than a PopupWindow because panels
// are summoned by hotkey as well as by click. An xdg-popup only receives keys
// after a click or hover has routed focus through its parent surface, so
// Escape and arrow keys did nothing on a hotkey-opened panel. A layer surface
// can take keyboard focus on its own; see the focus prime below.
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

  readonly property var barWindow: barItem ? barItem.QsWindow.window : null

  // Distance from the top of the screen to the bottom of the bar. The bar is
  // a top-anchored layer surface, so its own margin is part of the offset.
  readonly property int barStrip: Theme.barMarginTop + Theme.barHeight
  readonly property int cardY: barStrip + Theme.gapsOut

  readonly property int screenWidth: root.screen ? root.screen.width : 0
  readonly property int screenHeight: root.screen ? root.screen.height : 0
  readonly property int screenLimit: screenHeight > 0 ? screenHeight - cardY - Theme.gapsOut : 800

  // Preserve the last geometry while the card fades out.
  property int lastWidth: Theme.panelWidthNarrow
  property int lastHeight: Theme.panelMaxHeight
  property real lastX: 0

  readonly property int cardWidth: current ? current.preferredWidth : lastWidth
  readonly property int cardHeight: current ? Math.min(current.preferredHeight, screenLimit) : lastHeight

  // mapToItem is a one-shot; the watcher is what makes this binding re-run
  // when the bar relayouts underneath the anchor.
  TransformWatcher {
    id: anchorWatcher
    a: root.barWindow ? root.barWindow.contentItem : null
    b: root.current ? root.current.anchorTarget : null
  }

  // Center under the active widget and clamp to the screen margins.
  readonly property real cardX: {
    anchorWatcher.transform;
    if (!current || !current.anchorTarget || !barWindow)
      return lastX;
    var target = current.anchorTarget;
    var point = target.mapToItem(barWindow.contentItem, 0, 0);
    var centred = point.x + target.width / 2 - cardWidth / 2;
    return Math.max(Theme.gapsOut, Math.min(screenWidth - cardWidth - Theme.gapsOut, centred));
  }

  // Push host state because declarative child panels cannot bind back to it.
  function syncPanels() {
    for (var i = 0; i < panelList.length; i++) {
      panelList[i].active = panelList[i].panelName === root.activePanel;
      panelList[i].screenLimit = root.screenLimit;
    }
  }

  onActivePanelChanged: syncPanels()
  onPanelListChanged: syncPanels()
  onScreenLimitChanged: syncPanels()
  Component.onCompleted: syncPanels()

  // Track settled content sizes so closing starts from the visible geometry.
  onCardWidthChanged: if (current)
    lastWidth = cardWidth
  onCardHeightChanged: if (current)
    lastHeight = cardHeight
  onCardXChanged: if (current)
    lastX = cardX

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
    y: root.cardY
    width: root.cardWidth
    height: root.cardHeight
    radius: Theme.cornerRadius
    color: Theme.base
    border.width: 1
    border.color: Theme.overlay
    clip: true

    opacity: root.open ? 1 : 0

    // Avoid opening from the last card's geometry.
    readonly property bool morphing: opacity > 0.01

    Behavior on x {
      enabled: card.morphing
      NumberAnimation {
        duration: Theme.animSlow
        easing.type: Easing.OutCubic
      }
    }
    Behavior on width {
      enabled: card.morphing
      NumberAnimation {
        duration: Theme.animSlow
        easing.type: Easing.OutCubic
      }
    }
    Behavior on height {
      enabled: card.morphing
      NumberAnimation {
        duration: Theme.animSlow
        easing.type: Easing.OutCubic
      }
    }
    Behavior on opacity {
      NumberAnimation {
        duration: Theme.animFast
        easing.type: Easing.InOutQuad
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

      Item {
        id: panelHolder
        anchors.fill: parent
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
