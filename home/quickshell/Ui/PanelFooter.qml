import QtQuick
import qs.Commons

// A panel's footer line: the place something is from on the left, the directory dimmed and
// the name not so it reads at a glance, and a hint at the far end. Spans the panel; with no
// name, or only a hint, the rest simply is not drawn.
Item {
  id: root

  // A content-morph anchor (Ui/MorphScan.js): what it is, and what pairs it across panels.
  property string morphRole: "footer"
  property string morphKey: "footer"
  property var morphSlot: undefined

  property string path: ""
  property string name: ""
  property string hint: ""
  // Before the hint and part of it, but what changes from one panel to another (a carousel's "2 / 5"):
  // its own text, so a morph changes that and not the words beside it.
  property string count: ""

  implicitHeight: lead.implicitHeight

  Row {
    id: lead

    x: Theme.panelHeaderInset

    Text {
      objectName: "path"
      text: root.path
      color: Theme.muted
      font.family: Theme.monoFont
      font.pixelSize: Theme.wallpaperMetaSize
    }

    Text {
      objectName: "name"
      text: root.name
      color: Theme.subtle
      font.family: Theme.monoFont
      font.pixelSize: Theme.wallpaperMetaSize
      font.weight: Theme.weightSemi
    }
  }

  Text {
    objectName: "count"
    x: root.width - Theme.panelHeaderInset - hintText.width - width
    text: root.count
    color: Theme.muted
    font.family: Theme.uiFont
    font.pixelSize: Theme.wallpaperMetaSize
  }

  Text {
    id: hintText

    objectName: "hint"
    x: root.width - Theme.panelHeaderInset - width
    text: root.hint
    color: Theme.muted
    font.family: Theme.uiFont
    font.pixelSize: Theme.wallpaperMetaSize
  }
}
