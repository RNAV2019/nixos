import QtQuick
import qs.Commons

// A panel's header: an optional Back button, the title, an optional meta line at the far end,
// and a row of controls (Buttons, a Switch) that children drop into. 70 px tall, all of
// it on one centre line; a panel whose design draws the title lower places the header lower.
Item {
  id: root

  property string title: ""
  property string meta: ""
  property bool hasBack: false
  property int titleWeight: Theme.weightMedium

  // For a title that arrives with the contents under it, like the calendar's month.
  property real titleOpacity: 1
  property real titleShift: 0

  default property alias actions: slot.data

  signal backed

  implicitHeight: Theme.panelHeaderHeight

  Button {
    id: back

    x: Theme.panelHeaderBackInset
    y: (parent.height - height) / 2
    visible: root.hasBack
    kind: Button.Disc
    icon: Icons.back
    accessibleName: "Back"
    onClicked: root.backed()
  }

  Text {
    x: root.hasBack ? back.x + back.width + 12 : Theme.panelHeaderInset
    y: (parent.height - height) / 2
    width: Math.max(0, Math.min(slot.x, root.meta !== "" ? metaText.x : root.width) - x - 12)
    text: root.title
    color: Theme.text
    font.family: Theme.uiFont
    font.pixelSize: Theme.panelTitleSize
    font.weight: root.titleWeight
    elide: Text.ElideRight
    opacity: root.titleOpacity

    transform: Translate {
      x: root.titleShift
    }
  }

  Text {
    id: metaText

    x: root.width - Theme.panelHeaderInset - width
    y: Theme.panelHeaderMetaTop
    width: 160
    visible: root.meta !== ""
    horizontalAlignment: Text.AlignRight
    text: root.meta
    color: Theme.subtle
    font.family: Theme.uiFont
    font.pixelSize: Theme.wallpaperMetaSize
    elide: Text.ElideRight
  }

  Row {
    id: slot

    x: root.width - (root.hasBack ? Theme.panelHeaderTrailInset : Theme.panelHeaderInset) - width
    anchors.verticalCenter: parent.verticalCenter
    spacing: Theme.panelHeaderGap
  }
}
