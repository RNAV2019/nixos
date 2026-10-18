import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services
import qs.Ui

// The Sharing Panel's file picker (boards 16b, 16c): yazi-style, driven from the keyboard. The
// parent folder on the left, the current folder in the middle, a preview of the focused entry
// on the right. j/k move, h leaves for the parent, l enters a folder, space marks and moves on,
// enter sends what is marked - or, with nothing marked, the focused file or folder. Escape
// backs out to the panel. The mouse works too: click focuses, double-click enters or marks.
Item {
  id: root

  implicitWidth: Theme.pickerWidth
  implicitHeight: Theme.pickerHeight

  // Where the picker opens; it remembers the last folder for the next open.
  property string dir: ""
  property int focusIndex: 0
  property bool showHidden: false

  // Marked paths, in the order they were marked, plus a lookup. Marks survive moving between
  // folders, so files can be picked from several at once.
  property var marked: []
  property var markedSet: ({})

  // The finished choice: absolute paths, folders included (the panel expands those).
  signal accepted(var paths)
  signal cancelled

  readonly property string home: Quickshell.env("HOME")
  readonly property var entries: current.entries
  readonly property var focused: focusIndex >= 0 && focusIndex < entries.length ? entries[focusIndex] : null

  // The columns end on a whole row, never a sliver of the next one.
  readonly property real columnsHeight: Math.floor((height - Theme.pickerColumnsTop - Theme.pickerColumnsBottom + Theme.pickerRowPitch - Theme.pickerRowHeight) / Theme.pickerRowPitch) * Theme.pickerRowPitch - (Theme.pickerRowPitch - Theme.pickerRowHeight)

  // The child to re-focus once the listing we are moving into lands (going up lands on the
  // folder we came out of).
  property string pendingFocus: ""

  function open(startDir) {
    marked = [];
    markedSet = {};
    if (dir === "")
      dir = startDir !== undefined && startDir !== "" ? startDir : home + "/Downloads";
    else
      current.reload();
    pendingFocus = "";
  }

  function parentOf(p) {
    if (p === "/" || p === "")
      return "";
    var i = p.lastIndexOf("/");
    return i <= 0 ? "/" : p.substring(0, i);
  }

  function enter(path) {
    pendingFocus = "";
    focusIndex = 0;
    dir = path;
  }

  function goUp() {
    var up = parentOf(dir);
    if (up === "")
      return;
    pendingFocus = Nearby.baseName(dir);
    focusIndex = 0;
    dir = up;
  }

  function move(delta) {
    if (entries.length === 0)
      return;
    focusIndex = Math.max(0, Math.min(entries.length - 1, focusIndex + delta));
  }

  function toggleMark(entry) {
    if (!entry)
      return;
    var set = Object.assign({}, markedSet);
    var list = marked.slice();
    if (set[entry.path]) {
      delete set[entry.path];
      list.splice(list.indexOf(entry.path), 1);
    } else {
      set[entry.path] = true;
      list.push(entry.path);
    }
    markedSet = set;
    marked = list;
  }

  function finish() {
    if (marked.length > 0)
      accepted(marked.slice());
    else if (focused)
      accepted([focused.path]);
  }

  function handleKey(event) {
    var k = event.key;
    var t = event.text;
    if (k === Qt.Key_Escape || t === "q") {
      cancelled();
    } else if (k === Qt.Key_Down || t === "j") {
      move(1);
    } else if (k === Qt.Key_Up || t === "k") {
      move(-1);
    } else if (k === Qt.Key_Left || t === "h" || k === Qt.Key_Backspace) {
      goUp();
    } else if (k === Qt.Key_Right || t === "l") {
      if (focused && focused.dir)
        enter(focused.path);
    } else if (k === Qt.Key_Space) {
      toggleMark(focused);
      move(1);
    } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
      finish();
    } else if (t === "g") {
      focusIndex = 0;
    } else if (t === "G") {
      focusIndex = Math.max(0, entries.length - 1);
    } else if (k === Qt.Key_PageDown) {
      move(10);
    } else if (k === Qt.Key_PageUp) {
      move(-10);
    } else if (t === ".") {
      showHidden = !showHidden;
    } else if (t === "~") {
      enter(home);
    } else {
      return;
    }
    event.accepted = true;
  }

  // ---- listings ----

  DirLister {
    id: current

    path: root.dir
    showHidden: root.showHidden
    onLoaded: {
      if (root.pendingFocus !== "") {
        for (var i = 0; i < entries.length; i++) {
          if (entries[i].name === root.pendingFocus) {
            root.focusIndex = i;
            break;
          }
        }
        root.pendingFocus = "";
      }
      root.focusIndex = Math.max(0, Math.min(root.focusIndex, entries.length - 1));
    }
  }

  DirLister {
    id: parentList

    path: root.parentOf(root.dir)
    dirsOnly: true
    showHidden: root.showHidden
  }

  DirLister {
    id: previewList

    path: root.focused && root.focused.dir ? root.focused.path : ""
    showHidden: root.showHidden
  }

  // ---- header: the folder's path and the marked counter ----

  StrokeIcon {
    x: 24
    y: 20
    size: 16
    strokeWidth: 1.75
    path: IconPaths.folder
    color: Theme.accentFill
  }

  Row {
    x: 48
    y: 20
    height: 16
    width: chip.x - 48 - 16

    readonly property string prefix: {
      var p = root.parentOf(root.dir);
      if (p === "")
        return "";
      if (p === root.home)
        return "~/";
      if (p.indexOf(root.home + "/") === 0)
        return "~/" + p.substring(root.home.length + 1) + "/";
      return p === "/" ? "/" : p + "/";
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(implicitWidth, parent.width * 0.6)
      elide: Text.ElideLeft
      text: parent.prefix
      color: Theme.inkTertiary
      font.family: Theme.uiFont
      font.pixelSize: 13
      font.weight: Theme.weightMedium
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(implicitWidth, parent.width - x)
      elide: Text.ElideRight
      text: root.dir === root.home ? "~" : root.dir === "/" ? "/" : Nearby.baseName(root.dir)
      color: Theme.inkPrimary
      font.family: Theme.uiFont
      font.pixelSize: 13
      font.weight: Theme.weightSemi
    }
  }

  // "0 marked" sits outlined and quiet; once something is marked it fills with the accent.
  Rectangle {
    id: chip

    readonly property bool any: root.marked.length > 0

    x: root.width - 20 - width
    y: 15
    width: chipRow.implicitWidth + 24
    height: Theme.pickerChipHeight
    radius: height / 2
    color: any ? Theme.withAlpha(Theme.accentFill, 0.14) : "transparent"
    border.width: any ? 0 : 1
    border.color: Theme.withAlpha(Theme.separator, 0.7)

    Behavior on color {
      Tint {}
    }

    Row {
      id: chipRow

      anchors.centerIn: parent
      spacing: 6

      StrokeIcon {
        anchors.verticalCenter: parent.verticalCenter
        size: Theme.pickerChipGlyph
        strokeWidth: 1.75
        path: IconPaths.listChecks
        color: chip.any ? Theme.accentFill : Theme.inkTertiary
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.marked.length + " marked"
        color: chip.any ? Theme.accentFill : Theme.inkTertiary
        font.family: Theme.uiFont
        font.pixelSize: Theme.nearbyChipSize
        font.weight: Theme.weightSemi
      }
    }

    MouseArea {
      anchors.fill: parent
      enabled: chip.any
      cursorShape: chip.any ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: root.finish()
    }
  }

  Rectangle {
    x: Theme.pickerSide
    y: Theme.pickerHeaderHeight
    width: root.width - Theme.pickerSide * 2
    height: 1
    color: Theme.withAlpha(Theme.separator, 0.6)
  }

  Rectangle {
    x: Theme.pickerRuleOneX
    y: Theme.pickerColumnsTop
    width: 1
    height: root.height - Theme.pickerColumnsTop - Theme.pickerColumnsBottom
    color: Theme.withAlpha(Theme.separator, 0.45)
  }

  Rectangle {
    x: Theme.pickerRuleTwoX
    y: Theme.pickerColumnsTop
    width: 1
    height: root.height - Theme.pickerColumnsTop - Theme.pickerColumnsBottom
    color: Theme.withAlpha(Theme.separator, 0.45)
  }

  // One picker row: a glyph, a name, and the size or folder count. `state` styles it.
  component PickerRow: Item {
    id: row

    property var entry: null
    property bool current: false
    property bool focusedRow: false
    property bool markedRow: false
    property bool showMeta: true
    property bool quiet: false

    signal clicked
    signal doubleClicked

    height: Theme.pickerRowHeight

    readonly property string kind: entry ? (entry.dir ? "dir" : Nearby.fileKind(entry.name)) : "file"

    Rectangle {
      anchors.fill: parent
      radius: Theme.pickerRowRadius
      color: row.markedRow ? Theme.withAlpha(Theme.accentFill, row.focusedRow ? 0.16 : 0.09) : row.focusedRow || row.current ? Theme.withAlpha(Theme.inkPrimary, 0.06) : "transparent"

      Behavior on color {
        Tint {}
      }
    }

    Rectangle {
      visible: row.focusedRow
      x: 0
      y: (parent.height - height) / 2
      width: Theme.pickerFocusMarkWidth
      height: Theme.pickerFocusMarkHeight
      radius: width / 2
      color: Theme.accentFill
    }

    StrokeIcon {
      x: Theme.pickerGlyphLeft
      y: (parent.height - size) / 2
      size: Theme.pickerGlyph
      strokeWidth: 1.75
      path: Nearby.glyphFor(row.kind)
      color: Nearby.inkFor(row.kind)
    }

    Text {
      x: Theme.pickerTextLeft
      y: (parent.height - height) / 2
      width: meta.x - x - 10
      elide: Text.ElideRight
      text: row.entry ? row.entry.name : ""
      color: row.markedRow ? Theme.accentFill : row.quiet && !row.current ? Theme.inkSecondary : Theme.inkPrimary
      font.family: Theme.uiFont
      font.pixelSize: Theme.pickerNameSize
      font.weight: row.focusedRow || row.current ? Theme.weightSemi : Theme.weightRegular
    }

    StrokeIcon {
      visible: row.markedRow
      x: row.width - Theme.pickerMetaRight - size
      y: (parent.height - size) / 2
      size: Theme.pickerMarkSize
      strokeWidth: 1.9
      path: IconPaths.check
      color: Theme.accentFill
    }

    Text {
      id: meta

      visible: row.showMeta
      x: row.width - Theme.pickerMetaRight - (row.markedRow ? Theme.pickerMarkSize + 8 : 0) - width
      y: (parent.height - height) / 2
      text: !row.entry ? "" : row.entry.dir ? String(row.entry.size) : Nearby.sizeLabel(row.entry.size)
      color: Theme.inkTertiary
      font.family: Theme.uiFont
      font.pixelSize: Theme.pickerMetaSize
      font.weight: Theme.weightMedium
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: row.clicked()
      onDoubleClicked: row.doubleClicked()
    }
  }

  // A column of rows on the 32 px pitch, kept scrolled so the focused row stays in view.
  component Column_: ListView {
    clip: true
    spacing: Theme.pickerRowPitch - Theme.pickerRowHeight
    boundsBehavior: Flickable.StopAtBounds
    highlightFollowsCurrentItem: false
    interactive: contentHeight > height
  }

  Column_ {
    id: parentColumn

    x: Theme.pickerParentX
    y: Theme.pickerColumnsTop
    width: Theme.pickerParentWidth
    height: root.columnsHeight
    model: parentList.entries
    currentIndex: {
      for (var i = 0; i < parentList.entries.length; i++) {
        if (parentList.entries[i].path === root.dir)
          return i;
      }
      return -1;
    }
    onCurrentIndexChanged: if (currentIndex >= 0)
      positionViewAtIndex(currentIndex, ListView.Contain)

    delegate: PickerRow {
      required property var modelData
      required property int index

      width: parentColumn.width
      entry: modelData
      current: modelData.path === root.dir
      showMeta: false
      quiet: true
      onClicked: root.enter(modelData.path)
    }
  }

  Column_ {
    id: currentColumn

    x: Theme.pickerCurrentX
    y: Theme.pickerColumnsTop
    width: Theme.pickerCurrentWidth
    height: root.columnsHeight
    model: current.entries
    currentIndex: root.focusIndex
    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
    onCountChanged: positionViewAtIndex(currentIndex, ListView.Contain)

    delegate: PickerRow {
      required property var modelData
      required property int index

      width: currentColumn.width
      entry: modelData
      focusedRow: index === root.focusIndex
      markedRow: root.markedSet[modelData.path] === true
      onClicked: root.focusIndex = index
      onDoubleClicked: {
        root.focusIndex = index;
        if (modelData.dir)
          root.enter(modelData.path);
        else
          root.toggleMark(modelData);
      }
    }

    WheelHandler {
      onWheel: function (event) {
        root.move(event.angleDelta.y > 0 ? -1 : 1);
      }
    }
  }

  Text {
    visible: !current.loading && current.entries.length === 0
    x: Theme.pickerCurrentX + Theme.pickerTextLeft
    y: Theme.pickerColumnsTop + 8
    text: current.error !== "" ? current.error : "Empty folder"
    color: Theme.inkTertiary
    font.family: Theme.uiFont
    font.pixelSize: Theme.pickerNameSize
  }

  // ---- preview ----

  Item {
    id: preview

    x: Theme.pickerPreviewX
    y: Theme.pickerColumnsTop
    width: Theme.pickerPreviewWidth
    height: root.columnsHeight

    readonly property var entry: root.focused
    readonly property string kind: entry ? (entry.dir ? "dir" : Nearby.fileKind(entry.name)) : ""
    readonly property bool showsImage: entry !== null && !entry.dir && Nearby.isPreviewableImage(entry.name)

    // A folder previews as the column it would become.
    ListView {
      visible: preview.kind === "dir"
      anchors.fill: parent
      clip: true
      interactive: false
      spacing: Theme.pickerRowPitch - Theme.pickerRowHeight
      model: previewList.entries

      delegate: PickerRow {
        required property var modelData

        width: preview.width
        entry: modelData
        markedRow: root.markedSet[modelData.path] === true
      }
    }

    Text {
      visible: preview.kind === "dir" && !previewList.loading && previewList.entries.length === 0
      x: Theme.pickerTextLeft
      y: 8
      text: previewList.error !== "" ? previewList.error : "Empty folder"
      color: Theme.inkTertiary
      font.family: Theme.uiFont
      font.pixelSize: Theme.pickerNameSize
    }

    // A file previews as its picture, or a tile with its glyph (and, for text, its first lines).
    Item {
      id: tile

      visible: preview.entry !== null && preview.kind !== "dir"
      width: parent.width
      height: Theme.pickerPreviewImageHeight
      layer.enabled: true
      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: tileMask
      }

      Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.surfaceSubtle, 0.85)
      }

      Image {
        id: pic

        anchors.fill: parent
        visible: preview.showsImage && status === Image.Ready
        source: preview.showsImage ? "file://" + preview.entry.path : ""
        asynchronous: true
        cache: false
        fillMode: Image.PreserveAspectCrop
        // Decoded at the tile's size, not the photo's: a 12 MP JPEG decoded whole stalls.
        sourceSize.width: Theme.pickerPreviewWidth * 2
      }

      Text {
        visible: preview.kind === "text" && textPeek.text !== ""
        x: 16
        y: 14
        width: parent.width - 32
        height: parent.height - 28
        clip: true
        text: textPeek.text
        color: Theme.inkSecondary
        font.family: Theme.monoFont
        font.pixelSize: Theme.nearbyIncomingMetaSize
        lineHeight: 1.15
        wrapMode: Text.NoWrap
        elide: Text.ElideRight
      }

      StrokeIcon {
        visible: !pic.visible && !(preview.kind === "text" && textPeek.text !== "")
        anchors.centerIn: parent
        size: 48
        strokeWidth: 2
        path: Nearby.glyphFor(preview.kind)
        color: Nearby.inkFor(preview.kind)
      }
    }

    Item {
      id: tileMask

      width: tile.width
      height: tile.height
      visible: false
      layer.enabled: true

      Rectangle {
        anchors.fill: parent
        radius: Theme.pickerPreviewRadius
        color: "black"
      }
    }

    // The first lines of a small text file, read only when one is focused.
    Process {
      id: textPeek

      property string text: ""
      readonly property string target: preview.kind === "text" && preview.entry && preview.entry.size < 512 * 1024 ? preview.entry.path : ""

      command: ["head", "-n", "24", "-c", "4096", "--", target]
      onTargetChanged: {
        text = "";
        running = false;
        if (target !== "")
          running = true;
      }

      stdout: StdioCollector {
        onStreamFinished: textPeek.text = text.replace(/\t/g, "  ")
      }
    }

    Text {
      visible: tile.visible
      y: Theme.pickerPreviewImageHeight + 14
      width: parent.width
      elide: Text.ElideMiddle
      text: preview.entry ? preview.entry.name : ""
      color: Theme.inkPrimary
      font.family: Theme.uiFont
      font.pixelSize: 13
      font.weight: Theme.weightSemi
    }

    Text {
      visible: tile.visible
      y: Theme.pickerPreviewImageHeight + 34
      width: parent.width
      elide: Text.ElideRight
      text: {
        if (!preview.entry)
          return "";
        var parts = [Nearby.sizeLabel(preview.entry.size)];
        if (preview.showsImage && origSize.w > 0)
          parts.push(origSize.w + " × " + origSize.h);
        var ext = Nearby.extOf(preview.entry.name);
        if (ext !== "")
          parts.push(ext === "jpg" ? "JPEG" : ext.toUpperCase());
        return parts.filter(function (p) {
          return p !== "";
        }).join(" · ");
      }
      color: Theme.inkSecondary
      font.family: Theme.uiFont
      font.pixelSize: 11
    }

    // `identify` would need ImageMagick; the file header is enough for JPEG/PNG, so read the
    // dimensions with `file`, which every system has.
    Process {
      id: origProbe

      readonly property string target: preview.showsImage ? preview.entry.path : ""

      command: ["file", "-bL", "--", target]
      onTargetChanged: {
        origSize.w = 0;
        origSize.h = 0;
        running = false;
        if (target !== "")
          running = true;
      }

      stdout: StdioCollector {
        onStreamFinished: {
          var m = text.match(/(\d+)\s*x\s*(\d+)/g);
          if (!m || m.length === 0)
            return;
          var last = m[m.length - 1].match(/(\d+)\s*x\s*(\d+)/);
          origSize.w = parseInt(last[1], 10);
          origSize.h = parseInt(last[2], 10);
        }
      }
    }

    QtObject {
      id: origSize

      property int w: 0
      property int h: 0
    }
  }
}
