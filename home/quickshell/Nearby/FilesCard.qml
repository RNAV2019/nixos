import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui

// The staged files card (board 16b): up to three thumbnails, the count and total, and two
// disc buttons to add more or clear. Thumbnails enter 30 ms apart, scaling 0.92 -> 1.
Rectangle {
  id: root

  // Absolute paths.
  property var files: []
  property int totalBytes: 0

  signal addClicked
  signal clearClicked

  implicitWidth: Theme.nearbyWidth - Theme.nearbyInset * 2
  implicitHeight: Theme.nearbyFilesHeight
  radius: Theme.nearbyFilesRadius
  color: Theme.withAlpha(Theme.surfaceSubtle, 0.85)
  border.width: 1
  border.color: Theme.withAlpha(Theme.separator, 0.55)

  readonly property int shown: Math.min(3, files.length)

  readonly property string title: files.length + (files.length === 1 ? " file" : " files")

  readonly property string sizeLabel: {
    if (totalBytes <= 0)
      return "";
    if (totalBytes < 1024)
      return totalBytes + " B";
    if (totalBytes < 1024 * 1024)
      return (totalBytes / 1024).toFixed(1) + " KB";
    return (totalBytes / (1024 * 1024)).toFixed(1) + " MB";
  }

  function kind(path) {
    var ext = path.toString().toLowerCase().split(".").pop();
    if (["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "avif", "heic"].indexOf(ext) !== -1)
      return "image";
    if (["zip", "tar", "gz", "xz", "7z", "rar", "bz2", "zst"].indexOf(ext) !== -1)
      return "zip";
    return "doc";
  }

  function glyph(kind) {
    return kind === "image" ? IconPaths.image : kind === "zip" ? IconPaths.fileArchive : IconPaths.fileText;
  }

  function ink(kind) {
    return kind === "image" ? Theme.accentFill : kind === "zip" ? Theme.gold : Theme.love;
  }

  // Each thumbnail enters on its own 30 ms beat.
  Repeater {
    model: root.shown

    Item {
      id: thumb

      required property int index

      x: 20 + index * (Theme.nearbyThumbSize + Theme.nearbyThumbGap)
      y: (root.height - Theme.nearbyThumbSize) / 2
      width: Theme.nearbyThumbSize
      height: Theme.nearbyThumbSize

      readonly property var path: root.files[index]
      readonly property string fileKind: root.kind(path)

      opacity: 0
      scale: 0.92

      Timer {
        interval: thumb.index * 30
        running: true
        onTriggered: {
          thumb.opacity = 1;
          thumb.scale = 1;
        }
      }

      Behavior on opacity {
        Morph {
          duration: Theme.morphContent
        }
      }

      Behavior on scale {
        Morph {
          duration: Theme.morphState
        }
      }

      // Images get their picture; everything else a tinted glyph tile. A broken image
      // falls back to the same glyph its extension would have drawn.
      Image {
        id: pic

        anchors.fill: parent
        visible: thumb.fileKind === "image"
        source: thumb.fileKind === "image" ? "file://" + thumb.path : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        // Masked to the tile's rounded corner, or a photo's square corner would poke past
        // the disc-shaped frame the card draws around it.
        layer.enabled: thumb.fileKind === "image"
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: picMask
        }
      }

      Item {
        id: picMask

        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
          anchors.fill: parent
          radius: Theme.nearbyThumbRadius
          color: "black"
        }
      }

      Rectangle {
        anchors.fill: parent
        visible: thumb.fileKind !== "image" || pic.status !== Image.Ready
        radius: Theme.nearbyThumbRadius
        color: Theme.surfaceRaised
      }

      StrokeIcon {
        anchors.centerIn: parent
        visible: thumb.fileKind !== "image" || pic.status !== Image.Ready
        size: Theme.nearbyThumbGlyph
        strokeWidth: 1.6
        path: root.glyph(thumb.fileKind)
        color: root.ink(thumb.fileKind)
      }

      Rectangle {
        anchors.fill: parent
        visible: thumb.fileKind === "image"
        radius: Theme.nearbyThumbRadius
        color: "transparent"
        border.width: 1
        border.color: Theme.withAlpha(Theme.separator, 0.55)
      }

      clip: true
    }
  }

  Text {
    x: 20 + root.shown * (Theme.nearbyThumbSize + Theme.nearbyThumbGap) - Theme.nearbyThumbGap + Theme.nearbyFilesTextGap
    y: root.height / 2 - 15
    text: root.title
    color: Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: Theme.nearbyFilesTitleSize
    font.weight: Theme.weightSemi
  }

  Text {
    x: 20 + root.shown * (Theme.nearbyThumbSize + Theme.nearbyThumbGap) - Theme.nearbyThumbGap + Theme.nearbyFilesTextGap
    y: root.height / 2 + 4
    visible: root.sizeLabel !== ""
    text: root.sizeLabel
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: Theme.nearbyFilesMetaSize
    font.weight: Theme.weightRegular
  }

  // The two disc buttons, 8 px apart and 16 px in from the card's right edge.
  Row {
    x: root.width - Theme.nearbyRowInset - 2 * Theme.nearbyIconBtnSize - Theme.nearbyIconBtnGap
    y: (root.height - Theme.nearbyIconBtnSize) / 2
    spacing: Theme.nearbyIconBtnGap

    Rectangle {
      width: Theme.nearbyIconBtnSize
      height: Theme.nearbyIconBtnSize
      radius: height / 2
      color: Theme.surfaceRaised
      scale: addArea.pressed ? Theme.pressScale : 1

      Behavior on scale {
        Morph {
          duration: Theme.morphState
        }
      }

      StrokeIcon {
        anchors.centerIn: parent
        size: Theme.nearbyIconBtnGlyph
        strokeWidth: 2
        path: IconPaths.plus
        color: Theme.inkSecondary
      }

      MouseArea {
        id: addArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.addClicked()
      }

      Accessible.role: Accessible.Button
      Accessible.name: "Add files"
      Accessible.onPressAction: root.addClicked()
    }

    Rectangle {
      width: Theme.nearbyIconBtnSize
      height: Theme.nearbyIconBtnSize
      radius: height / 2
      color: Theme.surfaceRaised
      scale: clearArea.pressed ? Theme.pressScale : 1

      Behavior on scale {
        Morph {
          duration: Theme.morphState
        }
      }

      StrokeIcon {
        anchors.centerIn: parent
        size: Theme.nearbyIconBtnGlyph
        strokeWidth: 2
        path: IconPaths.x
        color: Theme.inkSecondary
      }

      MouseArea {
        id: clearArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clearClicked()
      }

      Accessible.role: Accessible.Button
      Accessible.name: "Clear files"
      Accessible.onPressAction: root.clearClicked()
    }
  }
}
