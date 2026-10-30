import QtQuick
import qs.Commons

// The caption laid on a thumbnail: the window's title and the app it belongs to, on an opaque
// pill. Characters of the title the filter matched are drawn in the match colour.
Rectangle {
  id: root

  property string title: ""
  property string app: ""
  property color dot: Theme.accent
  property bool emphasis: false
  // Indices into the title the filter matched.
  property var positions: []
  // The widest the plate may be, the thumbnail's width less its insets.
  property real maxWidth: 1000

  readonly property real chrome: Theme.overviewPlatePad * 2 + Theme.overviewPlateDot + 6
  readonly property real appWidth: appText.implicitWidth + 6
  // The app name goes first when the thumbnail is too small for both.
  readonly property bool appFits: maxWidth - chrome - appWidth >= 24

  // The title in styled text, so the match colour can pick out single characters and the
  // whole can still elide.
  readonly property string markup: {
    var hit = {};
    for (var i = 0; i < positions.length; i++)
      hit[positions[i]] = true;
    var out = "";
    for (var j = 0; j < title.length; j++) {
      var c = title.charAt(j).replace(/&/g, "&amp;").replace(/</g, "&lt;");
      out += hit[j] ? "<font color=\"" + Theme.launcherMatchColor + "\"><b>" + c + "</b></font>" : c;
    }
    return out;
  }

  width: Math.min(maxWidth, chrome + titleText.implicitWidth + (appFits ? appWidth : 0))
  height: Theme.overviewPlateHeight
  radius: height / 2
  color: Theme.surface

  Rectangle {
    x: Theme.overviewPlatePad
    anchors.verticalCenter: parent.verticalCenter
    width: Theme.overviewPlateDot
    height: width
    radius: width / 2
    color: root.dot
  }

  Text {
    id: titleText

    x: Theme.overviewPlatePad + Theme.overviewPlateDot + 6
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(implicitWidth, Math.max(0, root.maxWidth - root.chrome - (root.appFits ? root.appWidth : 0)))
    textFormat: Text.StyledText
    text: root.markup
    elide: Text.ElideRight
    color: root.emphasis ? Theme.inkPrimary : Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: Theme.overviewPlateSize
    font.weight: Theme.weightSemi
  }

  Text {
    id: appText

    x: titleText.x + titleText.width + 6
    anchors.verticalCenter: parent.verticalCenter
    visible: root.appFits
    text: root.app
    color: Theme.inkTertiary
    font.family: Theme.uiFont
    font.pixelSize: Theme.overviewPlateSize
  }
}
