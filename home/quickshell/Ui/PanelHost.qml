import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons

// Reusing one popup lets geometry animate between panels.
PopupWindow {
  id: root

  required property Item barItem
  property string activePanel: ""

  default property alias panels: panelHolder.data

  // Only the host containing activePanel may acquire focus.
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

  readonly property var popupScreen: (barItem && barItem.QsWindow.window) ? barItem.QsWindow.window.screen : null
  readonly property int screenLimit: popupScreen ? popupScreen.height - Theme.barHeight - Theme.barMarginTop - Theme.gapsOut * 2 : 800

  // Preserve the last geometry while the card fades out.
  property int lastWidth: Theme.panelWidthNarrow
  property int lastHeight: Theme.panelMaxHeight
  property real lastX: 0

  readonly property int cardWidth: current ? current.preferredWidth : lastWidth
  readonly property int cardHeight: current ? Math.min(current.preferredHeight, screenLimit) : lastHeight

  // Center under the active widget and clamp to screen margins.
  readonly property real cardX: {
    if (!current || !current.anchorTarget || !barItem)
      return lastX;
    // Referenced so the binding re-runs when the bar relayouts under it.
    var w = barItem.width;
    var tw = current.anchorTarget.width;
    var point = current.anchorTarget.mapToItem(barItem, 0, 0);
    var centred = point.x + tw / 2 - cardWidth / 2;
    return Math.max(Theme.gapsOut, Math.min(w - cardWidth - Theme.gapsOut, centred));
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

  visible: open || card.opacity > 0
  color: "transparent"

  implicitWidth: barItem ? barItem.width : 1
  // Reserve the maximum card height; the input mask excludes unused space.
  implicitHeight: Math.min(Theme.panelMaxHeight, screenLimit)

  anchor {
    item: root.barItem
    edges: Edges.Top | Edges.Left
    gravity: Edges.Bottom | Edges.Right
    adjustment: PopupAdjustment.None
    rect.width: 1
    rect.height: 1

    onAnchoring: {
      if (!root.barItem)
        return;
      root.anchor.rect.x = 0;
      root.anchor.rect.y = root.barItem.height + Theme.gapsOut;
    }
  }

  // Restrict input to the card so the bar-wide window does not swallow clicks.
  mask: Region {
    item: card
  }

  HyprlandFocusGrab {
    active: root.open
    windows: root.barItem ? [root, root.barItem.QsWindow.window] : [root]
    // Ignore the clear caused by deactivating the grab during close.
    onCleared: if (root.open)
      root.dismissed()
  }

  Rectangle {
    id: card

    x: root.cardX
    y: 0
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

    Item {
      id: panelHolder
      anchors.fill: parent
    }

    Keys.onEscapePressed: root.dismissed()
    focus: root.open
  }
}
