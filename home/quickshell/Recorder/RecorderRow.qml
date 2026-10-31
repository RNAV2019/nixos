import QtQuick
import qs.Commons

// One row under the capture tiles: a quiet pill with the label at the near end and, at the
// far end, whatever control the row carries (a switch, the frame-rate segments). A click
// anywhere else on the row is the row's own, for the toggle or the cycle.
Item {
  id: root

  property string label: ""
  // A toggle that is off reads muted.
  property bool lit: true

  default property alias trailing: holder.data

  signal clicked

  x: Theme.recorderInset
  width: parent.width - Theme.recorderInset * 2
  height: Theme.recorderRowHeight

  Rectangle {
    anchors.fill: parent
    radius: Theme.recorderRowRadius
    color: Theme.withAlpha(Theme.highlightLow, Theme.powerTileFillAlpha)
  }

  Text {
    x: Theme.recorderRowTextLeft
    y: (parent.height - height) / 2
    text: root.label
    color: root.lit ? Theme.text : Theme.muted
    font.family: Theme.uiFont
    font.pixelSize: Theme.recorderRowLabelSize
    font.weight: Theme.weightMedium
  }

  Item {
    id: holder

    x: parent.width - width - Theme.recorderRowTextLeft
    y: (parent.height - height) / 2
    width: childrenRect.width
    height: childrenRect.height
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
    z: -1
  }
}
