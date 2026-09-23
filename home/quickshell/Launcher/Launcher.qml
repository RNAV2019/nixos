import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The app launcher: the island grown into a 520 px column from the pill's exact size,
// radius and centre line. The clipped panel uncovers pre-laid rows; reflow animates.
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

    // An empty result set still owns a row's worth of height, so the panel can say so.
    readonly property int rowCount: Math.max(1, Math.min(AppSearch.results.length, Theme.launcherMaxRows))
    readonly property int listHeight: rowCount * (Theme.launcherRowHeight + Theme.launcherRowGap) - Theme.launcherRowGap
    readonly property int contentHeight: Theme.launcherListTop + listHeight + Theme.launcherPadBottom

    onOpening: {
      query.text = "";
      list.currentIndex = 0;
    }

    function activate() {
      if (list.currentIndex < 0 || list.currentIndex >= rows.count)
        return;
      AppSearch.launch(rows.get(list.currentIndex).entryId);
      hide();
    }

    // Rebuilt in place, not replaced, so delegates survive a query change and can
    // animate; a reset would read as a cut.
    function syncRows() {
      var want = AppSearch.results;
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
        if (at < 0)
          rows.insert(i, {
            entryId: want[i].id,
            rowName: String(want[i].name),
            rowDesc: AppSearch.describe(want[i]),
            rowIcon: AppSearch.iconFor(want[i])
          });
        else if (at !== i)
          rows.move(at, i, 1);
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

    Connections {
      target: AppSearch

      function onResultsChanged() {
        win.syncRows();
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

        TextInput {
          id: query

          x: Theme.launcherTextLeft
          y: Theme.launcherSearchHeight / 2 - height / 2
           width: win.openWidth - x - Theme.launcherInset
          color: Theme.text
          font.family: Theme.uiFont
          font.pixelSize: Theme.launcherSearchSize
          selectByMouse: true
          selectionColor: Theme.withAlpha(Theme.accent, Theme.fillSelected)
          clip: true

          onTextChanged: {
            AppSearch.query = text;
            list.currentIndex = 0;
          }

          cursorDelegate: Rectangle {
            width: 1.5
            radius: 0.75
            color: Theme.accent
          }

          Text {
            text: "Search…"
            color: Theme.muted
            font: query.font
            visible: query.text.length === 0
          }

          Keys.onPressed: function (event) {
            switch (event.key) {
            case Qt.Key_Escape:
              win.hide();
              break;
            case Qt.Key_Up:
            case Qt.Key_Backtab:
              if (list.currentIndex > 0)
                list.currentIndex--;
              break;
            case Qt.Key_Down:
            case Qt.Key_Tab:
              if (list.currentIndex < rows.count - 1)
                list.currentIndex++;
              break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
              win.activate();
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
          text: "No matches"
          color: Theme.muted
          visible: rows.count === 0
          font.family: Theme.uiFont
          font.pixelSize: Theme.launcherNameSize
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

          // Keep the selection on screen without pinning it to a fixed row.
          highlightRangeMode: ListView.ApplyRange
          preferredHighlightBegin: 0
          preferredHighlightEnd: height
          highlightMoveDuration: Theme.morphSurface
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

          delegate: LauncherRow {
            required property int index
            required property string rowName
            required property string rowDesc
            required property string rowIcon

            width: list.width
            height: Theme.launcherRowHeight
            name: rowName
            description: rowDesc
            iconSource: rowIcon

            onActivated: {
              list.currentIndex = index;
              win.activate();
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

          // Survivors travel on the shape's curve, so two can be seen crossing, not shoving.
          displaced: Transition {
            NumberAnimation {
              properties: "y"
               duration: Theme.duration(Theme.morphSurface)
               easing.type: Easing.OutCubic
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
