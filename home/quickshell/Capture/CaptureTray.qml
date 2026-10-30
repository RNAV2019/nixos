import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Services
import qs.Ui

// The screenshot tray: after a capture a thumbnail card grows out of the island, holds a few
// seconds, and melts back. Pointer only, it never takes the keyboard; hovering it swaps the
// details for four actions, and the picture can be dragged out as a file. Several captures
// make a stack, newest on top, whose badge steps through them.
Variants {
  id: root

  model: Quickshell.screens

  TransientSurface {
    id: win

    key: "captures"
    rank: Theme.trayRank

    // Waits behind a user-opened panel, like a toast.
    readonly property bool blocked: Bus.islandOpenFor(win.screenName)

    wanted: Captures.trayWanted && win.focused && !win.blocked

    openWidth: Theme.trayWidth
    openHeight: Theme.trayHeight
    openRadius: Theme.panelRadius

    readonly property var capture: Captures.current
    readonly property bool stacked: Captures.count > 1
    readonly property bool recording: win.capture !== null && win.capture.kind === "recording"
    readonly property bool hovered: cardHover.hovered || dragger.active || thumbHover.hovered

    // The thumbnail of the capture shown: the file itself for a screenshot, the first frame
    // for a recording.
    readonly property string picture: {
      if (!win.capture)
        return "";
      var p = win.capture.kind === "screenshot" ? win.capture.path : win.capture.thumb;
      return p !== "" ? "file://" + p : "";
    }

    // ---- dwell ----
    //
    // Counted down so hovering holds it in place, as a toast does; a drag holds it too, and a
    // new capture or a step through the stack starts it again.
    property int remaining: Theme.trayDwell

    Connections {
      target: Captures

      function onRevisionChanged() {
        win.remaining = Theme.trayDwell;
      }
    }

    onOpening: win.remaining = Theme.trayDwell

    Timer {
      running: win.open && !win.hovered
      interval: 100
      repeat: true
      onTriggered: {
        win.remaining -= interval;
        if (win.remaining <= 0)
          Captures.dismiss();
      }
    }

    // ---- the stack behind the card ----
    //
    // Two layers peek out below the front card, 8 px each. They are placed off the card, and
    // come in once it has grown, so nothing shows under a card still on its way out of the pill.
    underlay: [
      Rectangle {
        id: layerFar

        readonly property real grown: Math.max(0, Math.min(1, (win.surface.height - Theme.trayHeight * 0.85) / (Theme.trayHeight * 0.15)))

        x: win.surface.x + Theme.trayStackInset * 2
        y: win.surface.y + Theme.trayStackPeek * 2
        width: win.surface.width - Theme.trayStackInset * 4
        height: win.surface.height
        radius: Theme.panelRadius
        color: Theme.surfaceRaised
        border.width: 1
        border.color: Theme.surfaceOutline
        visible: opacity > 0
        opacity: win.stacked && win.open ? grown : 0

        Behavior on opacity {
          Morph {
            duration: Theme.duration(Theme.morphContent)
          }
        }
      },
      Rectangle {
        x: win.surface.x + Theme.trayStackInset
        y: win.surface.y + Theme.trayStackPeek
        width: win.surface.width - Theme.trayStackInset * 2
        height: win.surface.height
        radius: Theme.panelRadius
        color: Theme.surfaceSubtle
        border.width: 1
        border.color: Theme.surfaceOutline
        visible: opacity > 0
        opacity: layerFar.opacity
      }
    ]

    // ---- the card ----

    HoverHandler {
      id: cardHover

      enabled: win.open
    }

    Item {
      id: thumb

      x: Theme.trayInset
      y: Theme.trayInset
      width: Theme.trayThumbWidth
      height: Theme.trayThumbHeight

      Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: thumbMask
        }

        Rectangle {
          anchors.fill: parent
          color: Theme.surfaceRaised
        }

        StrokeIcon {
          visible: pic.status !== Image.Ready
          anchors.centerIn: parent
          size: 32
          strokeWidth: 1.5
          path: win.recording ? IconPaths.camera : IconPaths.photo
          color: Theme.inkTertiary
        }

        Image {
          id: pic

          anchors.fill: parent
          source: win.picture
          asynchronous: true
          fillMode: Image.PreserveAspectCrop
          sourceSize.width: Theme.trayThumbWidth * 2
          sourceSize.height: Theme.trayThumbHeight * 2
        }
      }

      Item {
        id: thumbMask

        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
          anchors.fill: parent
          radius: Theme.trayThumbRadius
          color: "black"
        }
      }

      // Recording length, bottom left of the picture.
      Rectangle {
        visible: win.recording
        x: 8
        y: parent.height - height - 8
        width: 10 + 12 + 5 + durationText.implicitWidth + 10
        height: Theme.trayChipHeight
        radius: height / 2
        color: Theme.surface

        StrokeIcon {
          x: 10
          y: (parent.height - height) / 2
          size: 12
          strokeWidth: 1.75
          path: IconPaths.camera
          color: Theme.love
        }

        Text {
          id: durationText

          x: 27
          y: (parent.height - height) / 2
          text: win.capture ? Captures.durationLabel(win.capture.seconds) : ""
          color: Theme.inkPrimary
          font.family: Theme.uiFont
          font.pixelSize: 11
          font.weight: Theme.weightSemi
        }
      }

      // The count of captures; pressing it steps through the stack, newest first.
      Rectangle {
        id: badge

        visible: win.stacked
        x: parent.width - width - 8 - (win.hovered ? Theme.trayDismiss + 6 : 0)
        y: 8
        width: Theme.trayBadge
        height: Theme.trayBadge
        radius: width / 2
        color: Theme.accentFill
        scale: badgeArea.pressed ? Theme.pressScale : 1

        Behavior on x {
          Morph {
            duration: Theme.morphState
          }
        }

        Text {
          anchors.centerIn: parent
          text: Captures.count
          color: Theme.inkOnAccent
          font.family: Theme.uiFont
          font.pixelSize: 12
          font.weight: Theme.weightBold
        }

        MouseArea {
          id: badgeArea

          anchors.fill: parent
          anchors.margins: -4
          cursorShape: Qt.PointingHandCursor
          onClicked: Captures.step()
        }
      }

      // Away with the card, on hover only; the files stay.
      Rectangle {
        id: dismissDisc

        x: parent.width - width - 8
        y: 8
        width: Theme.trayDismiss
        height: Theme.trayDismiss
        radius: width / 2
        color: Theme.surface
        opacity: win.hovered ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          Morph {
            duration: Theme.duration(Theme.morphContent)
          }
        }

        StrokeIcon {
          anchors.centerIn: parent
          size: 12
          strokeWidth: 2
          path: IconPaths.x
          color: Theme.inkPrimary
        }

        MouseArea {
          anchors.fill: parent
          anchors.margins: -4
          cursorShape: Qt.PointingHandCursor
          onClicked: Captures.dismiss()
        }
      }

      HoverHandler {
        id: thumbHover

        enabled: win.open
        cursorShape: Qt.OpenHandCursor
      }

      // A click opens the file; a drag takes it as a real file drag (text/uri-list), which
      // is what the compositor's drag pile and the receiving app both read.
      TapHandler {
        enabled: win.open
        onTapped: {
          Captures.open();
          Captures.dismiss();
        }
      }

      DragHandler {
        id: dragger

        enabled: win.open && win.capture !== null
        target: null
        cursorShape: Qt.ClosedHandCursor
      }

      Drag.active: dragger.active
      Drag.dragType: Drag.Automatic
      Drag.supportedActions: Qt.CopyAction
      Drag.proposedAction: Qt.CopyAction
      Drag.mimeData: ({
          "text/uri-list": win.capture ? win.capture.uri + "\r\n" : ""
        })
      Drag.onDragFinished: function (action) {
        // A drop that landed means the file is where it was wanted.
        if (action !== Qt.IgnoreAction)
          Captures.dismiss();
      }
    }

    // ---- the row under the picture: details, or actions while hovered ----

    Item {
      id: meta

      x: Theme.trayInset
      y: Theme.trayInset + Theme.trayThumbHeight + Theme.trayMetaGap
      width: Theme.trayThumbWidth
      height: Theme.trayMetaHeight

      Item {
        id: details

        anchors.fill: parent
        opacity: win.hovered ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
          Morph {
            duration: Theme.duration(Theme.morphContent)
          }
        }

        Rectangle {
          x: 0
          y: (parent.height - height) / 2
          width: Theme.trayTile
          height: Theme.trayTile
          radius: Theme.trayTileRadius
          color: Theme.withAlpha(Theme.accent, 0.18)

          StrokeIcon {
            anchors.centerIn: parent
            size: Theme.trayTileGlyph
            strokeWidth: 1.75
            path: win.stacked ? IconPaths.images : win.recording ? IconPaths.camera : IconPaths.photo
            color: Theme.accent
          }
        }

        Text {
          x: 38
          y: 9
          width: tag.x - x - 8
          text: win.stacked ? Captures.count + " captures" : win.recording ? "Screen recording" : "Screenshot"
          color: Theme.inkPrimary
          elide: Text.ElideRight
          font.family: Theme.uiFont
          font.pixelSize: Theme.trayTitleSize
          font.weight: Theme.weightSemi
        }

        Text {
          x: 38
          y: 28
          width: tag.x - x - 8
          text: {
            if (!win.capture)
              return "";
            if (win.stacked)
              return Captures.summary();
            var c = win.capture;
            var first = c.kind === "screenshot" ? c.width + " × " + c.height : Captures.durationLabel(c.seconds);
            return first + " · " + Captures.sizeLabel(c.bytes) + " · " + c.note;
          }
          color: Theme.inkTertiary
          elide: Text.ElideRight
          font.family: Theme.uiFont
          font.pixelSize: Theme.trayDescSize
        }

        // The format, or Clear for a stack.
        StatusPill {
          id: tag

          visible: !win.stacked
          x: parent.width - width
          y: (parent.height - height) / 2
          pad: 8
          fontSize: Theme.trayTagSize
          label: win.capture ? win.capture.name.replace(/^.*\./, "").toUpperCase() : ""
        }

        Rectangle {
          id: clear

          visible: win.stacked
          x: parent.width - width
          y: (parent.height - height) / 2
          width: Theme.trayClearWidth
          height: Theme.trayTagHeight
          radius: height / 2
          color: Theme.withAlpha(Theme.highlightLow, 0.9)
          border.width: 1
          border.color: Theme.withAlpha(Theme.separator, Theme.powerTileBorderAlpha)
          scale: clearArea.pressed ? Theme.pressScale : 1

          Text {
            anchors.centerIn: parent
            text: "Clear"
            color: Theme.inkSecondary
            font.family: Theme.uiFont
            font.pixelSize: 11
            font.weight: Theme.weightMedium
          }

          MouseArea {
            id: clearArea

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Captures.clear()
          }
        }
      }

      Row {
        id: actions

        spacing: Theme.trayActionGap
        opacity: win.hovered ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          Morph {
            duration: Theme.duration(Theme.morphContent)
          }
        }

        ActionTile {
          label: "Annotate"
          glyph: IconPaths.pencilLine
          enabled: !win.recording
          onClicked: Captures.annotate()
        }

        ActionTile {
          id: copyTile

          label: copied ? "Copied" : "Copy"
          glyph: copied ? IconPaths.check : IconPaths.copy
          property bool copied: false
          onClicked: {
            Captures.copy();
            copied = true;
            copiedReset.restart();
          }

          Timer {
            id: copiedReset

            interval: Theme.nearbySentDwell
            onTriggered: copyTile.copied = false
          }
        }

        ActionTile {
          label: "Send"
          glyph: IconPaths.smartphone
          onClicked: Captures.send()
        }

        ActionTile {
          label: "Delete"
          glyph: IconPaths.trash
          glyphColour: Theme.love
          onClicked: Captures.remove()
        }
      }
    }
  }

  component ActionTile: Rectangle {
    id: tile

    property string label: ""
    property string glyph: ""
    property color glyphColour: Theme.inkPrimary

    signal clicked

    width: Theme.trayActionWidth
    height: Theme.trayActionHeight
    radius: Theme.trayActionRadius
    color: Theme.withAlpha(area.containsMouse && tile.enabled ? Theme.highlightMed : Theme.highlightLow, Theme.powerTileFillAlpha)
    border.width: 1
    border.color: area.containsMouse && tile.enabled ? Theme.accent : Theme.withAlpha(Theme.separator, Theme.powerTileBorderAlpha)
    opacity: tile.enabled ? 1 : 0.4
    scale: area.pressed ? Theme.pressScale : 1

    Behavior on color {
      Tint {}
    }

    Behavior on border.color {
      Tint {}
    }

    Behavior on scale {
      Morph {
        duration: Theme.morphState
      }
    }

    StrokeIcon {
      x: (parent.width - width) / 2
      y: 8
      size: Theme.trayActionGlyph
      strokeWidth: 1.75
      path: tile.glyph
      color: tile.glyphColour
    }

    Text {
      x: (parent.width - width) / 2
      y: 30
      text: tile.label
      color: Theme.inkPrimary
      font.family: Theme.uiFont
      font.pixelSize: Theme.trayActionLabelSize
      font.weight: Theme.weightMedium
    }

    MouseArea {
      id: area

      anchors.fill: parent
      enabled: tile.enabled
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: tile.clicked()
    }
  }
}
