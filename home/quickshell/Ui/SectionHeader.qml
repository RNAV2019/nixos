import QtQuick
import qs.Commons

Text {
  property string title: ""

  text: title.toUpperCase()
  color: Theme.muted
  font.family: Theme.fontFamily
  font.pixelSize: Theme.fontSizeSmall
  font.letterSpacing: 0.8
  font.bold: true
}
