import QtQuick
import qs.Commons
import qs.Services
import qs.Ui

// One workspace in the Overview: its number and how many windows it holds above a miniature
// of the output, the wallpaper with each window at its real place on it. It is also a drop
// target for a dragged window.
Item {
  id: root

  required property int wsId
  property real cardW: 340
  property real cardH: 191
  // Card px per output px.
  property real factor: 1

  // The windows on this workspace, on this output.
  property var wins: []
  property bool active: false
  // Where the selection is and the filter's matches (an address map), or null.
  property string selected: ""
  property var hits: null
  property string liftedAddress: ""
  property bool dropTarget: false
  property bool near: false
  property bool capturing: false
  property real pixelRatio: 1
  property Item space: null

  readonly property bool filtering: hits !== null
  readonly property Item bodyItem: body

  readonly property int matchCount: {
    if (!hits)
      return 0;
    var n = 0;
    for (var i = 0; i < wins.length; i++) {
      if (hits[wins[i].address])
        n++;
    }
    return n;
  }
  // The window being lifted out of here no longer counts.
  readonly property int shown: {
    var n = wins.length;
    for (var i = 0; i < wins.length; i++) {
      if (wins[i].address === liftedAddress)
        n--;
    }
    return n;
  }

  // The addresses drawn, reassigned only when the set changes, so a title or a box updating in
  // place does not rebuild every thumbnail (and restart its capture).
  readonly property string key: wins.map(w => w.address).join(",")
  property var addrs: []
  onKeyChanged: addrs = wins.map(w => w.address)
  Component.onCompleted: addrs = wins.map(w => w.address)

  function infoFor(address) {
    for (var i = 0; i < wins.length; i++) {
      if (wins[i].address === address)
        return wins[i];
    }
    return null;
  }

  signal windowClicked(string address)
  signal windowDragStarted(var info, point where, Item body)
  signal windowDragMoved(point where)
  signal windowDragEnded
  signal emptyClicked

  width: cardW
  height: Theme.overviewCardsTop + cardH

  Text {
    x: Theme.overviewLabelInset
    y: Theme.overviewLabelY
    text: root.wsId
    color: root.active ? Theme.accent : Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: Theme.overviewLabelSize
    font.weight: Theme.weightSemi
  }

  Text {
    x: root.cardW - Theme.overviewLabelInset - implicitWidth
    y: Theme.overviewLabelY + 2
    text: {
      if (root.filtering)
        return root.matchCount === 0 ? "No matches" : root.matchCount + (root.matchCount === 1 ? " match" : " matches");
      return root.shown === 0 ? "Empty" : root.shown + (root.shown === 1 ? " window" : " windows");
    }
    color: root.filtering && root.matchCount > 0 ? Theme.accent : Theme.inkTertiary
    font.family: Theme.uiFont
    font.pixelSize: Theme.overviewCountSize
    font.weight: root.filtering && root.matchCount > 0 ? Theme.weightSemi : Theme.weightRegular
  }

  Rectangle {
    id: body

    y: Theme.overviewCardsTop
    width: root.cardW
    height: root.cardH
    radius: Theme.overviewCardRadius
    color: Theme.surfaceSubtle
    clip: true

    Image {
      anchors.fill: parent
      source: Wallpapers.url
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: true
      sourceSize.width: Math.ceil(root.cardW * root.pixelRatio)
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.emptyClicked()
    }

    Repeater {
      model: root.addrs

      OverviewThumb {
        id: thumb

        required property string modelData

        visible: root.infoFor(modelData) !== null
        info: root.infoFor(modelData) || ({
            address: modelData,
            title: "",
            appClass: "",
            appName: "",
            x: 0,
            y: 0,
            w: 0,
            h: 0,
            toplevel: null
          })
        factor: root.factor
        space: root.space
        pixelRatio: root.pixelRatio
        near: root.near
        capturing: root.capturing
        selected: modelData === root.selected
        filtering: root.filtering
        hit: root.hits ? root.hits[modelData] || null : null
        lifted: modelData === root.liftedAddress

        onClicked: root.windowClicked(modelData)
        onDragStarted: where => root.windowDragStarted(thumb.info, where, thumb.body)
        onDragMoved: where => root.windowDragMoved(where)
        onDragEnded: root.windowDragEnded()
      }
    }

    Rectangle {
      anchors.fill: parent
      color: Theme.withAlpha(Theme.accent, Theme.overviewDropWash)
      opacity: root.dropTarget ? 1 : 0
      visible: opacity > 0

      Behavior on opacity {
        Morph {
          duration: Theme.duration(Theme.morphState)
        }
      }
    }
  }

  // The card's edge: 1 px, and 2 px in the active workspace's lighter line. Drawn over the
  // windows so it stays whole, and accent while a window is about to land here.
  Rectangle {
    y: Theme.overviewCardsTop
    width: root.cardW
    height: root.cardH
    radius: Theme.overviewCardRadius
    color: "transparent"
    border.width: root.dropTarget ? Theme.overviewDropRing : root.active ? 2 : 1
    border.color: root.dropTarget ? Theme.accent : root.active ? Theme.highlightHigh : Theme.withAlpha(Theme.separator, Theme.powerTileBorderAlpha)

    Behavior on border.color {
      Tint {}
    }
  }

  // "Move to N", at the top of the card it names.
  Rectangle {
    x: (root.cardW - width) / 2
    y: Theme.overviewCardsTop + Theme.overviewPillTop
    width: pillRow.implicitWidth + 2 * 10
    height: Theme.overviewPillHeight
    radius: height / 2
    color: Theme.accentFill
    opacity: root.dropTarget ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
      Morph {
        duration: Theme.duration(Theme.morphState)
      }
    }

    Row {
      id: pillRow

      x: 10
      anchors.verticalCenter: parent.verticalCenter
      spacing: 6

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "Move to " + root.wsId
        color: Theme.inkOnAccent
        font.family: Theme.uiFont
        font.pixelSize: Theme.overviewPillSize
        font.weight: Theme.weightBold
      }

      StrokeIcon {
        anchors.verticalCenter: parent.verticalCenter
        path: IconPaths.arrowRight
        size: Theme.overviewPillGlyph
        strokeWidth: 2
        color: Theme.inkOnAccent
      }
    }
  }
}
