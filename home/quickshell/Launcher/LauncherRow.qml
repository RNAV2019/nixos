import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property string name: ""
  property string description: ""
  property string iconSource: ""
  // A computed answer draws a glyph or a colour swatch in place of an app icon.
  property string glyph: ""
  // A Lucide stroke glyph (Commons/IconPaths.qml) in place of the font one, tinted by `tone`
  // ("love" for something destructive; the accent otherwise).
  property string glyphPath: ""
  property string tone: ""
  property string swatch: ""
  // An emoji is drawn as itself, in colour, on a neutral tile.
  property string emoji: ""
  // Indices into `name` the query matched, drawn in the match colour.
  property var matches: []
  property bool current: false

  signal activated(int modifiers)

  // The name as styled text: escaped, with each run of matched characters wrapped once.
  readonly property string styledName: {
    var hit = {};
    for (var k = 0; k < matches.length; k++)
      hit[matches[k]] = true;
    var esc = {
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      "\"": "&quot;"
    };
    var out = "";
    var open = false;
    for (var i = 0; i < name.length; i++) {
      if (hit[i] && !open)
        out += "<font color=\"" + Theme.launcherMatchColor + "\">";
      else if (!hit[i] && open)
        out += "</font>";
      open = hit[i] === true;
      var c = name.charAt(i);
      out += esc[c] || c;
    }
    return open ? out + "</font>" : out;
  }

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: root.name
  Accessible.description: root.description
  Accessible.focusable: true
  Accessible.focused: root.activeFocus
  Accessible.onPressAction: root.activated(Qt.NoModifier)

  readonly property color toneColor: tone === "love" ? Theme.love : Theme.accent

  readonly property bool twoLine: description.length > 0

  // No themed icon: fall back to an initial, tinted off the name so it stays stable.
  readonly property var tintPalette: [Theme.foam, Theme.gold, Theme.iris, Theme.pine, Theme.rose, Theme.love, Theme.subtle]

  readonly property color tint: {
    var h = 0;
    for (var i = 0; i < name.length; i++)
      h = (h * 31 + name.charCodeAt(i)) % 9973;
    return tintPalette[h % tintPalette.length];
  }

  Rectangle {
    id: tile

    x: Theme.launcherIconLeft - Theme.launcherInset
    y: (parent.height - height) / 2
    width: Theme.launcherIconSize
    height: width
    radius: Theme.launcherIconRadius
    color: root.swatch ? root.swatch : root.emoji ? Theme.launcherEmojiTile : root.glyph || root.glyphPath ? Theme.withAlpha(root.toneColor, 0.18) : Theme.withAlpha(root.tint, 0.22)
    // A hairline keeps a swatch near the surface colour from vanishing into it.
    border.width: root.swatch ? 1 : 0
    border.color: Theme.withAlpha(Theme.text, 0.18)
    visible: !icon.visible

    Text {
      anchors.centerIn: parent
      visible: !root.swatch && !root.emoji && !root.glyphPath
      text: root.glyph ? root.glyph : root.name.length > 0 ? root.name.charAt(0).toUpperCase() : "?"
      color: root.glyph ? root.toneColor : root.tint
      font.family: root.glyph ? Theme.iconFont : Theme.uiFont
      font.pixelSize: Theme.fontSizeLarge
      font.weight: Theme.weightBold
    }

    StrokeIcon {
      anchors.centerIn: parent
      visible: root.glyphPath !== ""
      size: 14
      strokeWidth: 1.75
      path: root.glyphPath
      color: root.toneColor
    }

    Text {
      anchors.centerIn: parent
      visible: root.emoji.length > 0
      text: root.emoji
      font.family: Theme.emojiFont
      font.pixelSize: Theme.launcherEmojiSize
    }
  }

  // Ask for a size no theme keeps, so it returns its largest variant and downsamples
  // cleanly. Loaded synchronously: async shows a blank frame.
  Image {
    id: icon

    x: tile.x
    y: tile.y
    width: tile.width
    height: tile.height
    source: root.iconSource
    sourceSize.width: Theme.launcherIconSize * 4
    sourceSize.height: Theme.launcherIconSize * 4
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
    visible: source !== "" && status === Image.Ready
  }

  Text {
    id: title

    x: Theme.launcherTextLeft - Theme.launcherInset
    y: root.twoLine ? 5 : (parent.height - height) / 2
    width: parent.width - x - Theme.launcherInset
    text: root.styledName
    textFormat: Text.StyledText
    color: Theme.inkPrimary
    elide: Text.ElideRight
    font.family: Theme.uiFont
    font.pixelSize: Theme.launcherNameSize
    font.weight: Theme.weightSemi
  }

  Text {
    x: title.x
    y: 24
    width: title.width
    text: root.description
    color: Theme.inkTertiary
    elide: Text.ElideRight
    visible: root.twoLine
    font.family: Theme.uiFont
    font.pixelSize: Theme.launcherDescSize
  }

  // A click still launches, but hover never moves the selection: the cursor is hidden.
  MouseArea {
    anchors.fill: parent
    activeFocusOnTab: true
    onPressed: root.forceActiveFocus()
    onClicked: function (mouse) {
      root.activated(mouse.modifiers);
    }
  }

  Keys.onPressed: function (event) {
    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.activated(event.modifiers);
      event.accepted = true;
    }
  }
}
