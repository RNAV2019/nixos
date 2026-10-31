import QtQuick
import qs.Commons

// A panel's footer line: the place something is from on the left, the directory dimmed and
// the name not so it reads at a glance, and a hint at the far end. Spans the panel; with no
// name, or only a hint, the rest simply is not drawn.
Item {
  id: root

  property string path: ""
  property string name: ""
  property string hint: ""

  implicitHeight: lead.implicitHeight

  Row {
    id: lead

    x: Theme.panelHeaderInset

    Text {
      text: root.path
      color: Theme.muted
      font.family: Theme.monoFont
      font.pixelSize: Theme.wallpaperMetaSize
    }

    Text {
      text: root.name
      color: Theme.subtle
      font.family: Theme.monoFont
      font.pixelSize: Theme.wallpaperMetaSize
      font.weight: Theme.weightSemi
    }
  }

  Text {
    x: root.width - Theme.panelHeaderInset - width
    text: root.hint
    color: Theme.muted
    font.family: Theme.uiFont
    font.pixelSize: Theme.wallpaperMetaSize
  }
}
