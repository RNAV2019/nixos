import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Control
import qs.Nearby
import qs.Services
import qs.Ui

// The screen-share picker: what xdg-desktop-portal-hyprland's stock Qt dialog was, drawn as
// the island in another shape. It opens when pkgs/share-picker asks (Services/SharePicker.qml),
// takes the keyboard, and answers with a screen, a window or a region, or with nothing.
Variants {
  id: root

  model: Quickshell.screens

  IslandSurface {
    id: win

    key: "sharepicker"
    exclusiveKeyboard: true
    openWidth: Theme.panelWidth(modelData, Theme.shareWidth)
    openHeight: Theme.shareHeight
    openRadius: Theme.shareRadius

    // 0 screens, 1 windows, 2 region; the ring's place in each list is kept across switches.
    property int source: 0
    property var picked: [0, 0]
    property bool remember: false
    // The question this surface is answering, to tell its own close from another's.
    property string fifo: ""
    // A region is drawn by slurp, which cannot run over a surface that holds the keyboard, so
    // its answer waits for the close to be over.
    property string regionAnswer: ""

    readonly property var request: SharePicker.request
    readonly property var entries: win.source === 0 ? SharePicker.screenEntries : win.source === 1 ? SharePicker.windowEntries : []
    readonly property var segments: [
      {
        icon: IconPaths.monitor,
        label: "Screens",
        muted: SharePicker.screenEntries.length === 0
      },
      {
        icon: IconPaths.appWindow,
        label: "Windows",
        muted: SharePicker.windowEntries.length === 0
      },
      {
        icon: IconPaths.crop,
        label: "Region",
        muted: false
      }
    ]

    readonly property string appName: win.request ? win.request.appName : ""
    readonly property string title: win.appName !== "" ? win.appName + " wants to share your screen" : "Choose what to share"
    readonly property string subtitle: win.source === 0 ? "Choose a screen to share" : win.source === 1 ? "Choose a window to share" : "Draw an area to share"

    // Takes the request as it stands: on every open, and when a second arrives while one is up.
    function seed() {
      var req = SharePicker.request;
      win.fifo = req ? req.fifo : "";
      win.remember = req ? req.token : false;
      win.regionAnswer = "";
      SharePicker.shown = true;

      var own = 0;
      for (var i = 0; i < SharePicker.screenEntries.length; i++) {
        if (win.screen && SharePicker.screenEntries[i].name === win.screen.name)
          own = i;
      }
      win.picked = [own, 0];
      win.source = !segments[0].muted ? 0 : !segments[1].muted ? 1 : 2;
      carousel.jump(win.picked[Math.min(win.source, 1)]);
    }

    onOpening: win.seed()

    // Any close that was not an answer is a cancel: Escape, a click away, the lock, another
    // surface taking the island.
    onOpenChanged: {
      if (!win.open && win.fifo !== "" && win.regionAnswer === "" && SharePicker.pending(win.fifo))
        SharePicker.answer("");
    }

    Connections {
      target: SharePicker

      function onAsked() {
        if (win.open)
          win.seed();
        else if (win.focused)
          win.show();
      }
    }

    function setSource(index) {
      if (index === win.source || win.segments[index].muted)
        return;
      if (win.source < 2) {
        var next = win.picked.slice();
        next[win.source] = carousel.selected;
        win.picked = next;
      }
      win.source = index;
      if (index < 2)
        carousel.jump(Math.min(win.picked[index], Math.max(0, win.entries.length - 1)));
    }

    // Up and down walk the sources, skipping any the request cannot satisfy.
    function stepSource(delta) {
      var i = win.source + delta;
      while (i >= 0 && i < win.segments.length && win.segments[i].muted)
        i += delta;
      if (i >= 0 && i < win.segments.length)
        win.setSource(i);
    }

    function share() {
      var flags = win.remember ? "r" : "";
      if (win.source === 2) {
        win.regionAnswer = flags + "/region";
        win.hide();
        regionCap.restart();
        Qt.callLater(win.answerRegion);
        return;
      }
      var entry = win.entries[carousel.selected];
      if (!entry)
        return;
      SharePicker.answer(flags + "/" + (win.source === 0 ? "screen:" + entry.name : "window:" + entry.id));
      win.hide();
    }

    function answerRegion() {
      if (win.regionAnswer === "" || win.open || win.showing || !win.parked)
        return;
      var line = win.regionAnswer;
      win.regionAnswer = "";
      regionCap.stop();
      SharePicker.answer(line);
    }

    onParkedChanged: if (parked)
      Qt.callLater(win.answerRegion)

    // A backstop only: if the window never parks (a lock mid-close), answer anyway.
    Timer {
      id: regionCap

      interval: 2000
      onTriggered: {
        if (win.regionAnswer === "")
          return;
        var line = win.regionAnswer;
        win.regionAnswer = "";
        SharePicker.answer(line);
      }
    }

    onKeyPressed: function (event) {
      switch (event.key) {
      case Qt.Key_Left:
      case Qt.Key_H:
      case Qt.Key_Backtab:
        carousel.step(-1);
        break;
      case Qt.Key_Right:
      case Qt.Key_L:
      case Qt.Key_Tab:
        carousel.step(1);
        break;
      case Qt.Key_Home:
        carousel.selected = 0;
        break;
      case Qt.Key_End:
        carousel.selected = Math.max(0, carousel.count - 1);
        break;
      case Qt.Key_Up:
        win.stepSource(-1);
        break;
      case Qt.Key_Down:
        win.stepSource(1);
        break;
      case Qt.Key_Space:
        win.remember = !win.remember;
        break;
      case Qt.Key_Return:
      case Qt.Key_Enter:
        win.share();
        break;
      default:
        return;
      }
      event.accepted = true;
    }

    Item {
      id: body

      anchors.fill: parent

      Rectangle {
        x: Theme.shareInset
        y: Theme.shareInset
        width: Theme.notifAvatarSize
        height: width
        radius: Theme.shareAvatarRadius
        color: Theme.withAlpha(Theme.stableAccent(win.appName), Theme.notifAvatarAlpha)

        Text {
          anchors.centerIn: parent
          visible: win.appName !== ""
          text: win.appName.charAt(0).toUpperCase()
          color: Theme.stableAccent(win.appName)
          font.family: Theme.uiFont
          font.pixelSize: Theme.notifAvatarLetterSize
          font.weight: Theme.weightBold
        }

        StrokeIcon {
          anchors.centerIn: parent
          visible: win.appName === ""
          size: Theme.notifAvatarLetterSize + 2
          strokeWidth: 1.75
          path: IconPaths.screenShare
          color: Theme.accent
        }
      }

      Text {
        x: Theme.shareTitleLeft
        y: Theme.shareTitleTop
        width: Theme.shareWidth - Theme.shareTrackWidth - Theme.shareInset * 2 - Theme.shareTitleLeft
        text: win.title
        elide: Text.ElideRight
        color: Theme.text
        font.family: Theme.uiFont
        font.pixelSize: Theme.wallpaperTitleSize
        font.weight: Theme.weightMedium
      }

      Text {
        x: Theme.shareTitleLeft
        y: Theme.shareSubTop
        text: win.subtitle
        color: Theme.inkSecondary
        font.family: Theme.uiFont
        font.pixelSize: Theme.shareSubSize
      }

      SegmentedTrack {
        x: Theme.shareWidth - Theme.shareInset - width
        y: Theme.shareTrackTop
        width: Theme.shareTrackWidth
        segments: win.segments
        currentIndex: win.source
        onChosen: function (index) {
          if (index === 2) {
            win.setSource(2);
            win.share();
          } else {
            win.setSource(index);
          }
        }
      }

      // The ring's thing, not necessarily the one that is shared: that waits on Share.
      CarouselRow {
        id: carousel

        anchors.fill: parent
        visible: win.source < 2
        model: win.entries
        tileWidths: Theme.shareTileWidths

        tile: Component {
          ShareTile {
            id: tile

            required property int index
            required property var modelData

            readonly property bool isScreen: win.source === 0
            readonly property string appLabel: isScreen ? "" : SharePicker.appLabel(modelData.class)

            x: carousel.tileX(index)
            y: Theme.shareRowMid - carousel.tileHeight(index) / 2
            width: carousel.tileWidth(index)
            height: carousel.tileHeight(index)
            glide: carousel.glide
            selected: index === carousel.selected
            kind: isScreen ? "screen" : "window"

            name: isScreen ? modelData.name : (modelData.title !== "" ? modelData.title : modelData.class)
            title: name
            detail: isScreen ? modelData.width + " × " + modelData.height : (appLabel !== "" ? appLabel : modelData.class)
            dot: isScreen ? "transparent" : Theme.stableAccent(modelData.class)
            captureSource: isScreen ? modelData.screen : SharePicker.toplevelFor(modelData)
            fallbackGlyph: isScreen ? IconPaths.monitor : IconPaths.appWindow
            capturing: win.open && carousel.stripX + x + width > 0 && carousel.stripX + x < Theme.shareWidth

            onActivated: carousel.selected = index
          }
        }
      }

      // A region has nothing to preview; the way to it is Share, or the segment.
      Row {
        visible: win.source === 2
        x: (Theme.shareWidth - width) / 2
        y: Theme.shareRowMid - height / 2
        spacing: Theme.shareButtonGlyphGap

        StrokeIcon {
          anchors.verticalCenter: parent.verticalCenter
          size: Theme.shareButtonGlyph + 2
          strokeWidth: 1.75
          path: IconPaths.crop
          color: Theme.inkTertiary
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "Share, then drag over the area you want to share"
          color: Theme.inkTertiary
          font.family: Theme.uiFont
          font.pixelSize: Theme.shareButtonSize
        }
      }

      Switch {
        x: Theme.shareInset
        y: Theme.shareFooterTop + (Theme.shareFooterHeight - height) / 2
        checked: win.remember
        accessibleName: "Remember this choice"
        onToggled: function (value) {
          win.remember = value;
        }
      }

      Text {
        x: Theme.shareInset + 46 + Theme.shareLabelGap
        y: Theme.shareFooterTop + (Theme.shareFooterHeight - height) / 2
        text: "Remember this choice"
        color: Theme.inkPrimary
        font.family: Theme.uiFont
        font.pixelSize: Theme.shareLabelSize
        font.weight: Theme.weightMedium
      }

      ShareButton {
        id: shareButton

        x: Theme.shareWidth - Theme.shareInset - width
        y: Theme.shareFooterTop
        primary: true
        label: "Share"
        glyph: IconPaths.screenShare
        onClicked: win.share()
      }

      ShareButton {
        x: shareButton.x - Theme.shareButtonGap - width
        y: Theme.shareFooterTop
        label: "Cancel"
        onClicked: win.hide()
      }
    }
  }
}
