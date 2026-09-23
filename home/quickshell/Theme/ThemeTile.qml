import QtQuick
import qs.Commons
import qs.Ui

// One theme in the carousel: its wallpaper, cropped, with a mini island pill of dots in the
// theme's own colours. Pill and dots come from `colors`, never Theme, so each tile is itself.
TileBase {
  id: root

  property string source: ""
  property string label: ""
  property var colors: ({})

  kind: "theme"
  title: root.label
  imageSource: root.source !== "" ? "file://" + root.source : ""

  // The theme's own ground, so a tile whose wallpaper has not loaded still reads as it.
  placeholderColor: root.colors.base !== undefined ? root.colors.base : Theme.overlay

  // The mini island, bottom centre. Fixed size, so it stays put against the bottom edge.
  Rectangle {
    id: pill

    readonly property int count: Theme.themeSwatchRoles.length

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Theme.themePillInset
    width: count * Theme.themeSwatchSize + (count - 1) * Theme.themeSwatchGap + 2 * Theme.themeSwatchPad
    height: Theme.themePillHeight
    radius: height / 2
    color: root.colors.surface !== undefined ? root.colors.surface : Theme.surface

    Row {
      anchors.centerIn: parent
      spacing: Theme.themeSwatchGap

      Repeater {
        model: Theme.themeSwatchRoles

        Rectangle {
          required property string modelData

          width: Theme.themeSwatchSize
          height: width
          radius: width / 2
          color: root.colors[modelData] !== undefined ? root.colors[modelData] : "transparent"
          border.width: 1
          border.color: root.colors.highlightHigh !== undefined ? root.colors.highlightHigh : Theme.highlightHigh
        }
      }
    }
  }
}
