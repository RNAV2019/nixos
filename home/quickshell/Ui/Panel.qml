import QtQuick
import qs.Commons

// The scaffold a panel's contents sit in, inside an IslandSurface: an optional header, the
// body, an optional footer, and the keys every panel shares. It lays out against the
// surface's real width (the clamped one, not the token), so content positions off `width`.
//
// Back is Escape or Backspace, and only where `backKeys` says there is something to go back
// to: Escape elsewhere falls through to the surface, which closes, and Backspace does nothing.
// Arrows and hjkl move, Tab steps, Return, Enter and Space activate, each only if the panel
// says it takes them; the rest reaches `keyPressed`, whose handler accepts what it uses. A
// panel that scrolls puts a ScrollView in its body.
Item {
  id: root

  required property IslandSurface surface

  property string title: ""
  property string meta: ""
  property bool hasBack: false
  // Whether Escape and Backspace go back: where the header shows a button, or where there is a
  // step back with none to press (an armed tile that stands down).
  property bool backKeys: hasBack
  property int titleWeight: Theme.weightMedium
  // For a panel whose design seats its title lower than the header's own centre line.
  property real headerTop: 0

  property bool footerShown: false
  property real footerTop: Theme.panelFooterTop

  property bool takesMove: false
  property bool takesTab: false
  property bool takesActivate: false

  default property alias content: body.data
  property alias header: panelHeader
  property alias footer: panelFooter
  property alias headerActions: panelHeader.actions

  // One step back: the header's button, or Escape or Backspace.
  signal backed
  // An arrow or h, j, k, l: -1 or 1 along an axis, 0 on the other.
  signal moved(int dx, int dy)
  signal stepped(int delta)
  signal activated
  signal keyPressed(var event)

  width: surface.openWidth
  height: surface.openHeight

  function take(event) {
    var taken = true;
    switch (event.key) {
    case Qt.Key_Escape:
    case Qt.Key_Backspace:
      if (root.backKeys)
        root.backed();
      else
        taken = false;
      break;
    case Qt.Key_Left:
    case Qt.Key_H:
      taken = root.takesMove;
      if (taken)
        root.moved(-1, 0);
      break;
    case Qt.Key_Right:
    case Qt.Key_L:
      taken = root.takesMove;
      if (taken)
        root.moved(1, 0);
      break;
    case Qt.Key_Up:
    case Qt.Key_K:
      taken = root.takesMove;
      if (taken)
        root.moved(0, -1);
      break;
    case Qt.Key_Down:
    case Qt.Key_J:
      taken = root.takesMove;
      if (taken)
        root.moved(0, 1);
      break;
    case Qt.Key_Tab:
      taken = root.takesTab;
      if (taken)
        root.stepped(event.modifiers & Qt.ShiftModifier ? -1 : 1);
      break;
    case Qt.Key_Backtab:
      taken = root.takesTab;
      if (taken)
        root.stepped(-1);
      break;
    case Qt.Key_Return:
    case Qt.Key_Enter:
    case Qt.Key_Space:
      taken = root.takesActivate;
      if (taken)
        root.activated();
      break;
    default:
      taken = false;
    }
    if (taken)
      event.accepted = true;
    else
      root.keyPressed(event);
  }

  Connections {
    target: root.surface
    enabled: root.enabled

    function onKeyPressed(event) {
      root.take(event);
    }
  }

  Item {
    id: body

    anchors.fill: parent
  }

  PanelHeader {
    id: panelHeader

    y: root.headerTop
    width: parent.width
    visible: root.title !== "" || root.hasBack
    title: root.title
    meta: root.meta
    hasBack: root.hasBack
    titleWeight: root.titleWeight
    onBacked: root.backed()
  }

  PanelFooter {
    id: panelFooter

    y: root.footerTop
    width: parent.width
    visible: root.footerShown
  }
}
