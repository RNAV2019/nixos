import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The app launcher: the island grown into a 520 px column from the pill's exact size,
// radius and centre line. The clipped panel uncovers pre-laid rows; reflow animates.
// What it lists comes from Omnibox, which merges every provider into sections; a provider
// may scope the field to itself (a chip) or swap the list for its own view.
Variants {
  id: root

  model: Quickshell.screens

  IslandSurface {
    id: win

    key: "launcher"
    hideCursor: true
    openWidth: Theme.panelWidth(modelData, Theme.launcherWidth)
    openHeight: win.contentHeight
    openRadius: Theme.launcherRadius

    // The provider running alone (entered from a row, or by its hidden prefix), and the one
    // whose view stands in for the list. The chip names whichever is innermost.
    readonly property var scope: Omnibox.scope
    readonly property var viewProvider: Omnibox.view
    readonly property var chip: viewProvider || scope
    readonly property var results: Omnibox.results

    // A view grows the panel to its own height, capped so the panel stays on screen.
    readonly property real viewMaxHeight: {
      var screenRoom = modelData && modelData.height > 0 ? modelData.height - Theme.barMarginTop - Theme.launcherListTop - Theme.launcherPadBottom - Theme.launcherViewScreenMargin : Theme.launcherViewMaxHeight;
      return Math.max(Theme.launcherRowHeight, Math.min(Theme.launcherViewMaxHeight, screenRoom));
    }
    readonly property real viewHeight: view.item ? Math.max(Theme.launcherRowHeight, Math.min(win.viewMaxHeight, view.item.implicitHeight)) : Theme.launcherRowHeight

    // Set once the selection is moved by hand, so a late answer (qalc, date) does not pull
    // it back to the top.
    property bool userMoved: false

    // Headers are shorter than rows; the cap is still Theme.launcherMaxRows rows' worth, and
    // an empty result set owns one row's height, so the panel can say so.
    readonly property int listHeight: {
      var cap = Theme.launcherMaxRows * (Theme.launcherRowHeight + Theme.launcherRowGap) - Theme.launcherRowGap;
      var h = -Theme.launcherRowGap;
      for (var i = 0; i < win.results.length && h < cap; i++)
        h += (win.results[i].header ? Theme.launcherHeaderHeight : Theme.launcherRowHeight) + Theme.launcherRowGap;
      return Math.max(Theme.launcherRowHeight, Math.min(cap, h));
    }
    readonly property int contentHeight: Theme.launcherListTop + (viewProvider ? viewHeight : listHeight) + Theme.launcherPadBottom

    onOpening: {
      Omnibox.reset();
      query.text = "";
      win.selectFirst();
      if (Omnibox.pendingAsk !== "") {
        var asked = Omnibox.pendingAsk;
        Omnibox.pendingAsk = "";
        ClaudeChat.ask(asked);
      }
    }

    function selectedRow() {
      if (!win.selectable(list.currentIndex))
        return null;
      var id = rows.get(list.currentIndex).entryId;
      for (var i = 0; i < win.results.length; i++) {
        if (win.results[i].id === id)
          return win.results[i];
      }
      return null;
    }

    // Escape peels one layer: the view, then the scope, then the launcher.
    function back() {
      if (win.viewProvider)
        Omnibox.closeView();
      else if (win.scope)
        Omnibox.leaveScope();
      else
        win.hide();
    }

    function selectable(i) {
      return i >= 0 && i < rows.count && !rows.get(i).rowHeader;
    }

    function selectFirst() {
      var i = 0;
      while (i < rows.count && !win.selectable(i))
        i++;
      list.currentIndex = i < rows.count ? i : 0;
      // The index may not have changed while the rows under it did.
      Qt.callLater(list.reveal, false);
    }

    // Steps over headers; stays put at either end.
    function step(dir) {
      var i = list.currentIndex + dir;
      while (i >= 0 && i < rows.count && !win.selectable(i))
        i += dir;
      if (!win.selectable(i))
        return;
      list.currentIndex = i;
      win.userMoved = true;
    }

    function activate(modifiers) {
      var row = win.selectedRow();
      if (row && !Omnibox.activate(row, modifiers))
        hide();
    }

    // Rebuilt in place, not replaced, so delegates survive a query change and can
    // animate; a reset would read as a cut.
    function syncRows() {
      var want = win.results;
      var i, j;

      // An unfiltered query is the whole list, so the sweep uses a lookup, not a scan.
      var wanted = {};
      for (i = 0; i < want.length; i++)
        wanted[want[i].id] = true;

      for (i = rows.count - 1; i >= 0; i--) {
        if (!wanted[rows.get(i).entryId])
          rows.remove(i);
      }

      // Survivors keep their relative order, so each match is found at or after the
      // position being filled.
      for (i = 0; i < want.length; i++) {
        var at = -1;
        for (j = i; j < rows.count; j++) {
          if (rows.get(j).entryId === want[i].id) {
            at = j;
            break;
          }
        }
        var next = win.rowFor(want[i]);
        if (at < 0) {
          rows.insert(i, next);
          continue;
        }
        if (at !== i)
          rows.move(at, i, 1);
        // A row keeps its id as its answer or its highlight changes, so it is updated in
        // place, and only when something shown did change.
        if (rows.get(i).rowKey !== next.rowKey)
          rows.set(i, next);
      }

      if (!win.userMoved || !win.selectable(list.currentIndex))
        win.selectFirst();
    }

    // Every row carries every role, so headers and every provider's rows share one model.
    function rowFor(item) {
      var row = {
        entryId: item.id,
        rowHeader: item.header === true,
        rowName: String(item.name || ""),
        rowDesc: String(item.desc || ""),
        rowIcon: String(item.icon || ""),
        rowGlyph: String(item.glyph || ""),
        rowSwatch: String(item.swatch || ""),
        rowEmoji: String(item.emoji || ""),
        // A list role would become a nested model, so the indices travel as text.
        rowMatches: (item.matches || []).join(",")
      };
      row.rowKey = [row.rowName, row.rowDesc, row.rowIcon, row.rowGlyph, row.rowSwatch, row.rowEmoji, row.rowMatches].join("\u0001");
      return row;
    }

    onResultsChanged: win.syncRows()

    Connections {
      target: Omnibox

      function onQueryRequested(text) {
        query.text = text;
      }
    }
    // Hyprland skips focus when a mapped OnDemand surface goes None -> OnDemand, so
    // Exclusive covers the close animation (permanent would swallow all pointer events).
    onOpenChanged: {
      if (open) {
        // Layer-shell gives the surface focus, but Qt needs an active-focus target
        // inside it before input sees a key.
        Qt.callLater(function () {
          if (win.open)
            query.forceActiveFocus();
        });
      }
    }

    ListModel {
      id: rows
    }

    Component.onCompleted: win.syncRows()

    Text {
      x: Theme.launcherGlyphLeft
      y: Theme.launcherSearchHeight / 2 - height / 2
      text: Icons.search
      color: Theme.muted
      visible: !win.chip
      font.family: Theme.iconFont
      font.pixelSize: Theme.launcherGlyphSize
    }

    // The scope as a breadcrumb: the provider's glyph and name on an accent tint, where the
    // search glyph sat, so its glyph lands on the same spot. Backspace or Escape lifts it.
    Rectangle {
      id: chip

      x: Theme.launcherGlyphLeft - Theme.launcherChipPad
      y: (Theme.launcherSearchHeight - height) / 2
      width: chipRow.implicitWidth + Theme.launcherChipPad * 2
      height: Theme.launcherChipHeight
      radius: Theme.launcherChipRadius
      color: Theme.withAlpha(Theme.accent, Theme.launcherChipAlpha)
      visible: win.chip !== null

      Row {
        id: chipRow

        x: Theme.launcherChipPad
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.launcherChipGap

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: text.length > 0
          text: win.chip && win.chip.scopeGlyph ? win.chip.scopeGlyph : ""
          color: Theme.accent
          font.family: Theme.iconFont
          font.pixelSize: Theme.launcherChipGlyphSize
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: win.chip ? win.chip.section : ""
          color: Theme.accent
          font.family: Theme.uiFont
          font.pixelSize: Theme.launcherChipSize
          font.weight: Theme.weightSemi
        }
      }
    }

    TextInput {
      id: query

      x: win.chip ? chip.x + chip.width + Theme.launcherChipTextGap : Theme.launcherTextLeft
      y: Theme.launcherSearchHeight / 2 - height / 2
      width: win.openWidth - x - Theme.launcherInset
      color: Theme.text
      font.family: Theme.uiFont
      font.pixelSize: Theme.launcherSearchSize
      selectByMouse: true
      selectionColor: Theme.withAlpha(Theme.accent, Theme.fillSelected)
      clip: true

      // An open view owns the field as its input; the list's providers never see it.
      onTextChanged: {
        if (win.viewProvider)
          return;
        win.userMoved = false;
        Omnibox.query = text;
      }

      cursorDelegate: Rectangle {
        width: 1.5
        radius: 0.75
        color: Theme.accent
      }

      Text {
        width: query.width
        text: view.item && view.item.placeholder ? view.item.placeholder : win.scope && win.scope.hint && !win.viewProvider ? win.scope.hint : "Search…"
        color: Theme.muted
        elide: Text.ElideRight
        font: query.font
        visible: query.text.length === 0
      }

      // Down/Up step the list, and Ctrl+N/P or Ctrl+J/K for hands that stay on the home
      // row. Tab is not a step: it is the selected row's own (Omnibox.tab), else it asks
      // Claude about the query, as Raycast's "Tab to ask AI".
      Keys.onPressed: function (event) {
        if (win.viewProvider && view.item && view.item.keyPressed) {
          view.item.keyPressed(event);
          if (event.accepted)
            return;
        }
        var ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        if (win.viewProvider) {
          switch (event.key) {
          case Qt.Key_Escape:
            win.back();
            break;
          case Qt.Key_Return:
          case Qt.Key_Enter:
            if (view.item && view.item.submit && view.item.submit(query.text) === true)
              query.text = "";
            break;
          default:
            return;
          }
          event.accepted = true;
          return;
        }
        switch (event.key) {
        case Qt.Key_Escape:
          win.back();
          break;
        case Qt.Key_Backspace:
          if (query.text.length > 0 || !win.scope || query.selectedText.length > 0)
            return;
          Omnibox.leaveScope();
          break;
        case Qt.Key_Up:
          win.step(-1);
          break;
        case Qt.Key_Down:
          win.step(1);
          break;
        case Qt.Key_Tab:
          Omnibox.tab(win.selectedRow(), query.text);
          break;
        case Qt.Key_Backtab:
          break;
        case Qt.Key_P:
        case Qt.Key_K:
          if (!ctrl)
            return;
          win.step(-1);
          break;
        case Qt.Key_N:
        case Qt.Key_J:
          if (!ctrl)
            return;
          win.step(1);
          break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
          win.activate(event.modifiers);
          break;
        default:
          return;
        }
        event.accepted = true;
      }
    }

    Rectangle {
      x: Theme.launcherInset
      y: Theme.launcherSearchHeight
      width: win.openWidth - Theme.launcherInset * 2
      height: 1
      color: Theme.withAlpha(Theme.highlightMed, 0.6)
    }

    Text {
      x: Theme.launcherTextLeft
      y: Theme.launcherListTop + (Theme.launcherRowHeight - height) / 2
      text: !win.scope ? "No matches" : win.scope.query.trim().length > 0 ? "No result" : "Start typing"
      color: Theme.muted
      visible: rows.count === 0 && !win.viewProvider
      font.family: Theme.uiFont
      font.pixelSize: Theme.launcherNameSize
    }

    // A provider's own view, in the list's place. Made when opened and dropped on close, so
    // each open starts from the provider's own state rather than a stale delegate.
    Loader {
      id: view

      x: Theme.launcherInset
      y: Theme.launcherListTop
      width: win.openWidth - Theme.launcherInset * 2
      height: win.viewHeight
      active: win.viewProvider !== null
      sourceComponent: win.viewProvider ? win.viewProvider.view : null

      onLoaded: {
        if (item.maxHeight !== undefined)
          item.maxHeight = Qt.binding(function () {
            return win.viewMaxHeight;
          });
      }
    }

    ListView {
      id: list

      x: Theme.launcherInset
      y: Theme.launcherListTop
      width: win.openWidth - Theme.launcherInset * 2
      height: win.listHeight
      visible: !win.viewProvider
      model: rows
      spacing: Theme.launcherRowGap
      clip: true
      currentIndex: 0
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick

      // Keep the selection on screen without pinning it to a fixed row, with a heading right
      // above it in view too. By hand: ListView's own range tracking loses the row once a
      // heading's delegate, shorter than its size guess, has been recycled.
      onCurrentIndexChanged: Qt.callLater(list.reveal, false)

      function reveal(settle) {
        var item = list.currentItem;
        if (!item)
          return;
        var top = item.y;
        var bottom = item.y + item.height;
        if (currentIndex > 0 && currentIndex <= rows.count && rows.get(currentIndex - 1).rowHeader)
          top -= Theme.launcherHeaderHeight + Theme.launcherRowGap;
        var y = scroll.running ? scroll.to : list.contentY;
        if (top < y)
          y = top;
        else if (bottom > y + list.height)
          y = bottom - list.height;
        y = Math.max(list.originY, Math.min(y, list.originY + list.contentHeight - list.height));
        if (Math.abs(y - list.contentY) < 0.5)
          return;
        // Delegates made on the way can shift the estimate, so the landing is checked again.
        if (settle) {
          list.contentY = y;
          return;
        }
        scroll.stop();
        scroll.to = y;
        scroll.start();
      }

      Morph {
        id: scroll

        target: list
        property: "contentY"
        onFinished: list.reveal(true)
      }
      highlightMoveDuration: Theme.duration(Theme.morphSurface)
      highlightMoveVelocity: -1
      highlightResizeDuration: 0

      highlight: Item {
        Rectangle {
          anchors.fill: parent
          radius: Theme.launcherRowRadius
          color: Theme.withAlpha(Theme.text, 0.06)
        }

        Rectangle {
          y: (parent.height - height) / 2
          width: Theme.launcherMarkerWidth
          height: Theme.launcherMarkerHeight
          radius: width / 2
          color: Theme.accent
        }
      }

      delegate: Item {
        id: slot

        required property int index
        required property bool rowHeader
        required property string rowName
        required property string rowDesc
        required property string rowIcon
        required property string rowGlyph
        required property string rowSwatch
        required property string rowEmoji
        required property string rowMatches

        width: list.width
        height: rowHeader ? Theme.launcherHeaderHeight : Theme.launcherRowHeight

        Text {
          x: Theme.launcherIconLeft - Theme.launcherInset
          y: parent.height - height - Theme.launcherHeaderPadBottom
          width: parent.width - x
          visible: slot.rowHeader
          text: slot.rowName
          color: Theme.launcherHeaderColor
          elide: Text.ElideRight
          font.family: Theme.uiFont
          font.pixelSize: Theme.launcherHeaderSize
          font.weight: Theme.weightSemi
          font.capitalization: Font.AllUppercase
          font.letterSpacing: Theme.launcherHeaderTracking
        }

        LauncherRow {
          anchors.fill: parent
          visible: !slot.rowHeader
          enabled: !slot.rowHeader
          name: slot.rowName
          description: slot.rowDesc
          iconSource: slot.rowIcon
          glyph: slot.rowGlyph
          swatch: slot.rowSwatch
          emoji: slot.rowEmoji
          matches: slot.rowMatches.length > 0 ? slot.rowMatches.split(",").map(Number) : []
          current: slot.ListView.isCurrentItem

          onActivated: function (modifiers) {
            list.currentIndex = slot.index;
            win.activate(modifiers);
          }
        }
      }

      add: Transition {
        NumberAnimation {
          property: "opacity"
          from: 0
          to: 1
          duration: Theme.morphState
        }
      }

      remove: Transition {
        NumberAnimation {
          property: "opacity"
          to: 0
          duration: Theme.morphState
        }
      }

      // Survivors travel on an OutCubic ease for the surface duration, so two can be
      // seen crossing, not shoving.
      displaced: Transition {
        Morph {
          properties: "y"
          duration: Theme.duration(Theme.morphSurface)
        }
        NumberAnimation {
          property: "opacity"
          to: 1
          duration: Theme.morphState
        }
      }
    }
  }
}
