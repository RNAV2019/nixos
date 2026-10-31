import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The app launcher: the island grown into a 520 px column from the pill's exact size,
// radius and centre line. The clipped panel uncovers pre-laid rows; reflow animates.
// What it lists comes from Omnibox, which merges every provider into sections; a provider
// may scope the field to itself (a chip).
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

    // The provider running alone (entered from a row, or by its hidden prefix); the chip
    // names it.
    readonly property var scope: Omnibox.scope
    readonly property var results: Omnibox.results

    // Set once the selection is moved by hand, so a late answer (qalc, date) does not pull
    // it back to the top.
    property bool userMoved: false

    // Up to Theme.launcherMaxRows rows, then the list scrolls. Nothing to show leaves no list,
    // and the panel closes up to the search row rather than saying so.
    readonly property int listHeight: {
      var shown = Math.min(Theme.launcherMaxRows, win.results.length);
      return shown > 0 ? shown * (Theme.launcherRowHeight + Theme.launcherRowGap) - Theme.launcherRowGap : 0;
    }
    readonly property bool listEmpty: win.results.length === 0
    readonly property int contentHeight: listEmpty ? Theme.launcherSearchHeight : Theme.launcherListTop + listHeight + Theme.launcherPadBottom

    onOpening: {
      Omnibox.reset();
      query.text = "";
      win.selectFirst();
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

    // Escape peels one layer: the scope, then the launcher.
    function back() {
      if (win.scope)
        Omnibox.leaveScope();
      else
        win.hide();
    }

    function selectable(i) {
      return i >= 0 && i < rows.count;
    }

    function selectFirst() {
      list.currentIndex = 0;
      // The index may not have changed while the rows under it did.
      Qt.callLater(list.reveal, false);
    }

    // Stays put at either end.
    function step(dir) {
      var i = list.currentIndex + dir;
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

    // Every row carries every role, so every provider's rows share one model.
    function rowFor(item) {
      var row = {
        entryId: item.id,
        rowName: String(item.name || ""),
        rowDesc: String(item.desc || ""),
        rowIcon: String(item.icon || ""),
        rowGlyph: String(item.glyph || ""),
        rowSwatch: String(item.swatch || ""),
        rowEmoji: String(item.emoji || "")
      };
      row.rowKey = [row.rowName, row.rowDesc, row.rowIcon, row.rowGlyph, row.rowSwatch, row.rowEmoji].join("\u0001");
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
      font.family: Theme.iconFont
      font.pixelSize: Theme.launcherGlyphSize
    }

    // The scope, named at the search row's far end: the provider's glyph and name in the
    // accent on a quiet pill, inset from the right as the search glyph is from the left.
    // Backspace or Escape lifts it.
    Rectangle {
      id: chip

      x: win.openWidth - (Theme.launcherGlyphLeft - Theme.launcherChipPad) - width
      y: (Theme.launcherSearchHeight - height) / 2
      width: chipRow.implicitWidth + Theme.launcherChipPad * 2
      height: Theme.launcherChipHeight
      radius: height / 2
      color: Theme.withAlpha(Theme.text, Theme.launcherChipAlpha)
      visible: win.scope !== null

      Row {
        id: chipRow

        x: Theme.launcherChipPad
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.launcherChipGap

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: text.length > 0
          text: win.scope && win.scope.scopeGlyph ? win.scope.scopeGlyph : ""
          color: Theme.accent
          font.family: Theme.iconFont
          font.pixelSize: Theme.launcherChipGlyphSize
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: win.scope ? win.scope.section : ""
          color: Theme.accent
          font.family: Theme.uiFont
          font.pixelSize: Theme.launcherChipSize
          font.weight: Theme.weightSemi
        }
      }
    }

    TextInput {
      id: query

      x: Theme.launcherTextLeft
      y: Theme.launcherSearchHeight / 2 - height / 2
      width: (win.scope ? chip.x - Theme.launcherChipTextGap : win.openWidth - Theme.launcherInset) - x
      color: Theme.text
      font.family: Theme.uiFont
      font.pixelSize: Theme.launcherSearchSize
      selectByMouse: true
      selectionColor: Theme.withAlpha(Theme.accent, Theme.fillSelected)
      clip: true

      onTextChanged: {
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
        text: win.scope && win.scope.hint ? win.scope.hint : "Search…"
        color: Theme.muted
        elide: Text.ElideRight
        font: query.font
        visible: query.text.length === 0
      }

      // Down/Up step the list, and Ctrl+N/P or Ctrl+J/K for hands that stay on the home
      // row. Tab is taken and does nothing, so focus never leaves the field.
      Keys.onPressed: function (event) {
        var ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
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
      visible: !win.listEmpty
    }

    ListView {
      id: list

      x: Theme.launcherInset
      y: Theme.launcherListTop
      width: win.openWidth - Theme.launcherInset * 2
      height: win.listHeight
      model: rows
      spacing: Theme.launcherRowGap
      clip: true
      currentIndex: 0
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick

      // Keep the selection on screen without pinning it to a fixed row. By hand, so the
      // scroll rides the same Morph as everything else.
      onCurrentIndexChanged: Qt.callLater(list.reveal, false)

      function reveal(settle) {
        var item = list.currentItem;
        if (!item)
          return;
        var top = item.y;
        var bottom = item.y + item.height;
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

      highlight: Rectangle {
        radius: Theme.launcherRowRadius
        color: Theme.withAlpha(Theme.text, Theme.launcherSelectedAlpha)
      }

      delegate: Item {
        id: slot

        required property int index
        required property string rowName
        required property string rowDesc
        required property string rowIcon
        required property string rowGlyph
        required property string rowSwatch
        required property string rowEmoji

        width: list.width
        height: Theme.launcherRowHeight

        LauncherRow {
          anchors.fill: parent
          name: slot.rowName
          description: slot.rowDesc
          iconSource: slot.rowIcon
          glyph: slot.rowGlyph
          swatch: slot.rowSwatch
          emoji: slot.rowEmoji
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
