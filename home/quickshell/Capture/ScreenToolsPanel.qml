import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Ui
import "Colour.js" as Colour

// Screen tools: a row of six (region, window and screen grabs, text, QR code, colour) that
// grows out of the island. A tool closes the surface and runs, and the answer of the last three
// comes back as a card of the same surface: the text read, the code found, the colour picked.
Variants {
  id: root

  model: Quickshell.screens

  IslandSurface {
    id: win

    key: "screentools"

    // "tools", then the answers: "text", "qr", "colour", and "none" when a grab found nothing.
    property string view: "tools"
    readonly property bool results: win.view !== "tools"

    openWidth: win.view === "tools" ? Theme.panelWidth(modelData, tiles.contentWidth) : win.view === "colour" ? Theme.colourWidth : Theme.resultWidth
    openHeight: {
      if (win.view === "tools")
        return tiles.implicitHeight;
      if (win.view === "colour")
        return Theme.colourHeight;
      if (win.view === "none")
        return Theme.resultHeaderHeight;
      return Theme.resultBlockTop + win.blockHeight + Theme.resultActionGap + Theme.notifActionHeight + Theme.resultInset;
    }
    openRadius: Theme.panelRadius

    // An answer that arrives unasked does not hold the keyboard until the pointer is on it.
    keyboard: !win.results || win.view === "colour" || resultHover.hovered
    property bool arriving: false

    // ---- the tool row ----

    property int selected: 0

    onOpening: {
      launchPending = false;
      settleCap.stop();
      if (win.arriving) {
        win.arriving = false;
        win.remaining = Theme.resultDwell;
        win.copiedRow = -1;
        win.row = 0;
        win.area = "rows";
        win.histIndex = 0;
      } else {
        win.view = "tools";
        win.selected = ScreenTools.last;
      }
    }

    function step(delta) {
      var n = ScreenTools.tools.length;
      win.selected = ((win.selected + delta) % n + n) % n;
    }

    // Closing first, because slurp and the picker cannot draw over a surface that holds the
    // keyboard; the tool then waits for the close to be over and the window parked, so the
    // capture does not catch its tail. See Recorder/RecorderPicker.qml.
    property string pendingTool: ""
    property bool launchPending: false

    function activate(i) {
      win.selected = i;
      ScreenTools.last = i;
      win.pendingTool = ScreenTools.tools[i].key;
      win.hide();
      launchPending = true;
      settleCap.restart();
      Qt.callLater(win.launchIfSettled);
    }

    function launchIfSettled() {
      if (!launchPending || win.open || win.showing || !win.parked)
        return;
      launchPending = false;
      settleCap.stop();
      ScreenTools.run(win.pendingTool);
    }

    onParkedChanged: if (parked)
      Qt.callLater(win.launchIfSettled)

    // A backstop only: if the window never parks (a lock mid-close), run anyway.
    Timer {
      id: settleCap

      interval: 2000
      onTriggered: {
        if (!win.launchPending)
          return;
        win.launchPending = false;
        ScreenTools.run(win.pendingTool);
      }
    }

    // The answer: come back, in the result's own shape.
    Connections {
      target: ScreenTools

      function onResulted(kind) {
        if (!win.focused)
          return;
        win.view = kind;
        win.arriving = true;
        if (win.open)
          win.arriving = false;
        else
          win.show();
      }
    }

    // ---- results ----

    // Dismisses itself after a while, like a toast; hovering holds it, and the colour card, which
    // is worked in, stays until it is closed.
    property int remaining: Theme.resultDwell

    Timer {
      running: win.open && win.results && win.view !== "colour" && !resultHover.hovered
      interval: 100
      repeat: true
      onTriggered: {
        win.remaining -= interval;
        if (win.remaining <= 0)
          win.hide();
      }
    }

    HoverHandler {
      id: resultHover

      enabled: win.open && win.results
    }

    readonly property int textLines: Math.max(1, Math.min(Theme.resultTextLinesMax, textMeasure.lineCount))
    readonly property int qrLines: Math.max(1, Math.min(Theme.resultQrLines, qrMeasure.lineCount))
    readonly property int blockHeight: Theme.resultBlockPad * 2 + Theme.resultTextLeading * (win.view === "qr" ? win.qrLines : win.textLines)

    // Hidden copies of the two blocks' text, to count the lines they would wrap to.
    Text {
      id: textMeasure

      visible: false
      width: Theme.resultWidth - Theme.resultInset * 2 - Theme.resultBlockPad * 2
      text: ScreenTools.text
      wrapMode: Text.WordWrap
      lineHeightMode: Text.FixedHeight
      lineHeight: Theme.resultTextLeading
      font.family: Theme.uiFont
      font.pixelSize: Theme.launcherChatBodySize
    }

    Text {
      id: qrMeasure

      visible: false
      width: Theme.resultWidth - Theme.resultInset * 2 - Theme.resultBlockPad * 2
      text: ScreenTools.code
      wrapMode: Text.WrapAnywhere
      lineHeightMode: Text.FixedHeight
      lineHeight: Theme.resultTextLeading
      font.family: Theme.monoFont
      font.pixelSize: Theme.resultQrSize
    }

    // The colour card's cursor: which format row, and the history when Tab has moved there.
    property int row: 0
    property string area: "rows"
    property int histIndex: 0
    property int copiedRow: -1

    function copyRow(i) {
      var f = ScreenTools.formats[i];
      if (!f)
        return;
      ScreenTools.copy(f.value);
      win.copiedRow = i;
      copiedReset.restart();
    }

    Timer {
      id: copiedReset

      interval: Theme.nearbySentDwell
      onTriggered: win.copiedRow = -1
    }

    function walkHistory(delta) {
      var n = ScreenTools.history.length;
      if (n === 0)
        return;
      win.area = "history";
      win.histIndex = ((win.histIndex + delta) % n + n) % n;
    }

    // ---- keys ----

    onKeyPressed: function (event) {
      if (win.view === "tools")
        win.toolKey(event);
      else if (win.view === "text")
        win.textKey(event);
      else if (win.view === "qr")
        win.qrKey(event);
      else if (win.view === "colour")
        win.colourKey(event);
      else if (event.key === Qt.Key_Backspace)
        win.hide();
      else
        return;
      event.accepted = true;
    }

    function toolKey(event) {
      switch (event.key) {
      case Qt.Key_Left:
      case Qt.Key_H:
      case Qt.Key_Backtab:
        win.step(-1);
        return;
      case Qt.Key_Right:
      case Qt.Key_L:
      case Qt.Key_Tab:
        win.step(1);
        return;
      case Qt.Key_Return:
      case Qt.Key_Enter:
        win.activate(win.selected);
        return;
      case Qt.Key_Escape:
      case Qt.Key_Backspace:
        win.hide();
        return;
      }
      // A tool's letter jumps to it and fires it.
      var tools = ScreenTools.tools;
      for (var i = 0; i < tools.length; i++) {
        if (event.text.toUpperCase() === tools[i].keycap && event.text !== "" && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
          win.activate(i);
          return;
        }
      }
      event.accepted = false;
    }

    function textKey(event) {
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        win.askClaude();
      } else if (event.key === Qt.Key_S && !(event.modifiers & Qt.ControlModifier)) {
        win.search();
      } else if (event.key === Qt.Key_Backspace) {
        win.hide();
      } else {
        event.accepted = false;
        return;
      }
    }

    function askClaude() {
      ScreenTools.askClaude();
    }

    function search() {
      ScreenTools.search();
      win.hide();
    }

    function qrKey(event) {
      var info = ScreenTools.codeInfo;
      if (event.key === Qt.Key_Left || event.key === Qt.Key_H)
        ScreenTools.stepCode(-1);
      else if (event.key === Qt.Key_Right || event.key === Qt.Key_L)
        ScreenTools.stepCode(1);
      else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
        info.openable ? win.openCode() : win.copyCode();
      else if (event.key === Qt.Key_C && !(event.modifiers & Qt.ControlModifier))
        win.copyCode();
      else if (event.key === Qt.Key_O && info.openable)
        win.openCode();
      else if (event.key === Qt.Key_Backspace)
        win.hide();
      else
        event.accepted = false;
    }

    function openCode() {
      ScreenTools.openCode();
      win.hide();
    }

    function copyCode() {
      ScreenTools.copy(ScreenTools.code);
      win.hide();
    }

    function colourKey(event) {
      var ctrl = event.modifiers & Qt.ControlModifier;
      var n = ScreenTools.formats.length;
      switch (event.key) {
      case Qt.Key_Down:
      case Qt.Key_J:
        win.area = "rows";
        win.row = (win.row + 1) % n;
        return;
      case Qt.Key_Up:
      case Qt.Key_K:
        win.area = "rows";
        win.row = (win.row + n - 1) % n;
        return;
      case Qt.Key_N:
        if (ctrl) {
          win.area = "rows";
          win.row = (win.row + 1) % n;
          return;
        }
        break;
      case Qt.Key_P:
        if (ctrl) {
          win.area = "rows";
          win.row = (win.row + n - 1) % n;
          return;
        }
        break;
      case Qt.Key_Left:
        win.walkHistory(-1);
        return;
      case Qt.Key_Right:
        win.walkHistory(1);
        return;
      case Qt.Key_Tab:
      case Qt.Key_Backtab:
        win.area = win.area === "rows" ? "history" : "rows";
        return;
      case Qt.Key_Return:
      case Qt.Key_Enter:
        if (win.area === "history")
          ScreenTools.setColour(ScreenTools.history[win.histIndex]);
        else
          win.copyRow(win.row);
        return;
      case Qt.Key_Backspace:
        win.hide();
        return;
      }
      if (!ctrl && event.key >= Qt.Key_1 && event.key <= Qt.Key_4) {
        win.row = event.key - Qt.Key_1;
        win.area = "rows";
        win.copyRow(win.row);
        return;
      }
      event.accepted = false;
    }

    // ---- what it draws ----

    Item {
      id: body

      anchors.fill: parent

      ChoiceTiles {
        id: tiles

        inset: Theme.powerInset
        model: ScreenTools.tools
        currentIndex: win.selected
        activeIndex: win.selected
        opacity: win.view === "tools" ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          Morph {
            duration: Theme.duration(Theme.morphContent)
          }
        }

        onEntered: win.selected = index
        onActivated: win.activate(index)
      }

      // ---- Text copied ----

      Item {
        anchors.fill: parent
        opacity: win.view === "text" ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          Morph {
            duration: Theme.duration(Theme.morphContent)
          }
        }

        ResultHeader {
          glyph: IconPaths.scanText
          title: "Text copied"
          detail: ScreenTools.textDetail
          pill: true
          pillLabel: "Copied"
        }

        ResultBlock {
          text: ScreenTools.text
          lines: win.textLines
          maxLines: Theme.resultTextLinesMax
          pixelSize: Theme.launcherChatBodySize
        }

        Row {
          layoutDirection: Qt.RightToLeft
          spacing: Theme.notifActionGap
          x: Theme.resultWidth - Theme.resultInset - width
          y: Theme.resultBlockTop + win.blockHeight + Theme.resultActionGap

          ActionPill {
            label: "Ask Claude"
            glyph: IconPaths.sparkles
            primary: true
            onClicked: win.askClaude()
          }

          ActionPill {
            label: "Search"
            glyph: IconPaths.search
            onClicked: win.search()
          }
        }
      }

      // ---- QR code found ----

      Item {
        anchors.fill: parent
        opacity: win.view === "qr" ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          Morph {
            duration: Theme.duration(Theme.morphContent)
          }
        }

        ResultHeader {
          glyph: IconPaths.qrCode
          title: "QR code found"
          detail: ScreenTools.codeInfo.what
          pillLabel: ScreenTools.codes.length > 1 ? (ScreenTools.codeIndex + 1) + " / " + ScreenTools.codes.length : ScreenTools.codeInfo.tag
        }

        ResultBlock {
          text: ScreenTools.code
          lines: win.qrLines
          maxLines: Theme.resultQrLines
          mono: true
          pixelSize: Theme.resultQrSize
        }

        Row {
          layoutDirection: Qt.RightToLeft
          spacing: Theme.notifActionGap
          x: Theme.resultWidth - Theme.resultInset - width
          y: Theme.resultBlockTop + win.blockHeight + Theme.resultActionGap

          // Open is only for a payload that means something to xdg-open; otherwise Copy leads.
          ActionPill {
            visible: ScreenTools.codeInfo.openable
            label: "Open"
            glyph: IconPaths.externalLink
            primary: true
            onClicked: win.openCode()
          }

          ActionPill {
            label: "Copy"
            glyph: IconPaths.copy
            primary: !ScreenTools.codeInfo.openable
            onClicked: win.copyCode()
          }
        }
      }

      // ---- nothing found ----

      Item {
        anchors.fill: parent
        opacity: win.view === "none" ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          Morph {
            duration: Theme.duration(Theme.morphContent)
          }
        }

        ResultHeader {
          glyph: ScreenTools.missing === "text" ? IconPaths.scanText : IconPaths.qrCode
          title: "No " + ScreenTools.missing + " found"
          detail: "Try a tighter selection"
        }
      }

      // ---- Colour picked ----

      Item {
        id: colourCard

        anchors.fill: parent
        opacity: win.view === "colour" ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          Morph {
            duration: Theme.duration(Theme.morphContent)
          }
        }

        Rectangle {
          x: Theme.resultInset
          y: Theme.resultInset
          width: Theme.colourSwatch
          height: Theme.colourSwatch
          radius: Theme.colourSwatchRadius
          color: ScreenTools.colour
          // A colour close to the card's own would vanish without an edge.
          border.width: Colour.lightnessGap(ScreenTools.colour, Theme.surface) < 0.1 ? 1 : 0
          border.color: Theme.withAlpha(Theme.text, 0.18)
        }

        Repeater {
          model: ScreenTools.formats

          Item {
            id: formatRow

            required property int index
            required property var modelData

            readonly property bool current: win.area === "rows" && win.row === index
            readonly property bool copied: win.copiedRow === index

            x: Theme.colourRowsX
            y: Theme.resultInset + index * (Theme.launcherRowHeight + Theme.launcherRowGap)
            width: Theme.colourRowWidth
            height: Theme.launcherRowHeight

            Rectangle {
              anchors.fill: parent
              radius: Theme.launcherRowRadius
              color: formatRow.current ? Theme.launcherChatCodeFill : "transparent"

              Behavior on color {
                Tint {}
              }
            }

            Rectangle {
              visible: formatRow.current
              y: 11
              width: 3
              height: 20
              radius: 1.5
              color: Theme.accent
            }

            Text {
              x: Theme.colourLabelLeft
              y: (parent.height - height) / 2
              text: formatRow.modelData.label
              color: Theme.launcherHeaderColor
              font.family: Theme.uiFont
              font.pixelSize: Theme.launcherHeaderSize
              font.weight: Theme.weightSemi
              font.letterSpacing: Theme.launcherHeaderTracking
            }

            Text {
              x: Theme.colourValueLeft
              y: (parent.height - height) / 2
              text: formatRow.modelData.value
              color: Theme.inkPrimary
              font.family: Theme.monoFont
              font.pixelSize: Theme.resultQrSize
              font.weight: Theme.weightMedium
            }

            StrokeIcon {
              x: parent.width - Theme.resultInset - width
              y: (parent.height - height) / 2
              size: Theme.colourCopyGlyph
              strokeWidth: 1.75
              path: formatRow.copied ? IconPaths.check : IconPaths.copy
              color: formatRow.current || formatRow.copied ? Theme.accent : Theme.inkTertiary
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: {
                win.area = "rows";
                win.row = formatRow.index;
              }
              onClicked: win.copyRow(formatRow.index)
            }
          }
        }

        Rectangle {
          x: Theme.resultInset
          y: Theme.colourDividerTop
          width: Theme.colourWidth - Theme.resultInset * 2
          height: 1
          color: Theme.withAlpha(Theme.highlightMed, 0.6)
        }

        Text {
          x: Theme.colourLabelLeft
          y: Theme.colourRecentTop
          text: "RECENT"
          color: Theme.launcherHeaderColor
          font.family: Theme.uiFont
          font.pixelSize: Theme.launcherHeaderSize
          font.weight: Theme.weightSemi
          font.letterSpacing: Theme.launcherHeaderTracking
        }

        Repeater {
          model: ScreenTools.history

          Rectangle {
            id: swatch

            required property int index
            required property string modelData

            readonly property bool isCurrent: index === 0
            readonly property bool cursor: win.area === "history" && win.histIndex === index

            x: Theme.resultInset + index * (Theme.colourHistoryWidth + Theme.colourHistoryGap)
            y: Theme.colourHistoryTop
            width: Theme.colourHistoryWidth
            height: Theme.colourHistoryHeight
            radius: Theme.colourHistoryRadius
            color: modelData
            // Drawn inside, so the ring never grows the swatch: the current one in accent, the
            // one the keyboard is on in text, the rest with a faint edge.
            border.width: isCurrent || cursor ? 2 : 1
            border.color: isCurrent ? Theme.accent : cursor ? Theme.text : Theme.withAlpha(Theme.text, 0.18)

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: ScreenTools.setColour(swatch.modelData)
            }
          }
        }
      }
    }
  }

  // The header every answer shares: a glyph tile, a title, a line of detail, and optionally a
  // pill at the far end.
  component ResultHeader: Item {
    property string glyph: ""
    property string title: ""
    property string detail: ""
    property string pillLabel: ""
    // The accent "Copied" form, with a check; otherwise the neutral tag.
    property bool pill: false

    anchors.fill: parent

    Rectangle {
      x: Theme.resultInset
      y: Theme.resultInset
      width: Theme.resultTile
      height: Theme.resultTile
      radius: Theme.resultTileRadius
      color: Theme.withAlpha(Theme.accent, 0.18)

      StrokeIcon {
        anchors.centerIn: parent
        size: Theme.resultTileGlyph
        strokeWidth: 1.75
        path: glyph
        color: Theme.accent
      }
    }

    Text {
      x: 58
      y: 15
      width: pillItem.x - x - 8
      text: title
      color: Theme.inkPrimary
      elide: Text.ElideRight
      font.family: Theme.uiFont
      font.pixelSize: Theme.resultTitleSize
      font.weight: Theme.weightSemi
    }

    Text {
      x: 58
      y: 33
      width: pillItem.x - x - 8
      text: detail
      color: Theme.inkTertiary
      elide: Text.ElideRight
      font.family: Theme.uiFont
      font.pixelSize: Theme.resultDescSize
    }

    StatusPill {
      id: pillItem

      visible: pillLabel !== ""
      x: Theme.resultWidth - Theme.resultInset - width
      y: 19
      accent: pill
      label: pillLabel
    }
  }

  // The recognised text or decoded payload, on its sunken block.
  component ResultBlock: Rectangle {
    property string text: ""
    property int lines: 1
    property int maxLines: 4
    property bool mono: false
    property real pixelSize: 13

    x: Theme.resultInset
    y: Theme.resultBlockTop
    width: Theme.resultWidth - Theme.resultInset * 2
    height: Theme.resultBlockPad * 2 + Theme.resultTextLeading * lines
    radius: Theme.resultBlockRadius
    color: Theme.surfaceSubtle

    // OCR output is untrusted, so it is never read as markup.
    Text {
      x: Theme.resultBlockPad
      y: Theme.resultBlockPad
      width: parent.width - Theme.resultBlockPad * 2
      height: Theme.resultTextLeading * parent.lines
      text: parent.text
      textFormat: Text.PlainText
      color: Theme.inkPrimary
      wrapMode: parent.mono ? Text.WrapAnywhere : Text.WordWrap
      maximumLineCount: parent.maxLines
      elide: parent.mono ? Text.ElideMiddle : Text.ElideRight
      lineHeightMode: Text.FixedHeight
      lineHeight: Theme.resultTextLeading
      font.family: parent.mono ? Theme.monoFont : Theme.uiFont
      font.pixelSize: parent.pixelSize
    }
  }
}
