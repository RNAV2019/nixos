import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Ui

// The keybinds cheatsheet: a card in the middle of the focused screen, up for as long as AltGr
// is held (home/desktop.nix watches the key and calls `keys open` and `keys close`). It is a
// thing to read, not to use, so it is not an island surface: it takes neither the island nor
// the keyboard, and whatever is open stays as it is underneath.
Scope {
  id: root

  // Asked for by the key. The session locking takes it down, and no key brings it up there.
  property bool wanted: false

  readonly property bool shown: wanted && !Bus.locking && Keymap.available

  Connections {
    target: Bus

    function onLockingChanged() {
      if (Bus.locking)
        root.wanted = false;
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win

      required property var modelData

      readonly property bool here: root.shown && Monitors.isFocused(modelData)

      screen: modelData
      // Mapped only while it is up or on its way out.
      visible: here || presence.value > 0.001
      color: "transparent"

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "quickshell-keys"

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      exclusionMode: ExclusionMode.Ignore

      // A click anywhere puts it away, which is also the way out if a release was never seen.
      mask: win.here ? null : nothing

      Region {
        id: nothing
      }

      ProgressSpring {
        id: presence

        target: win.here ? 1 : 0
        omega: Theme.keysOmega
      }

      // The desktop steps back so the card is the one thing to read.
      Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.canvas, Theme.keysScrimAlpha)
        opacity: Theme.clamp01(presence.value)
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: root.wanted = false
      }

      FrostedSurface {
        id: card

        readonly property real grow: Theme.keysGrowFrom + (1 - Theme.keysGrowFrom) * presence.value
        // On a screen too small for it the card is drawn smaller, whole, rather than cut.
        readonly property real fit: Math.min(1, (win.width - Theme.panelSideMargin * 2) / Math.max(1, width), (win.height - Theme.panelSideMargin * 2) / Math.max(1, height))

        implicitWidth: columns.implicitWidth + Theme.keysPad * 2
        implicitHeight: Theme.keysHeaderHeight + columns.implicitHeight + Theme.keysPad
        x: snap((win.width - width) / 2)
        y: snap((win.height - height) / 2)
        surfaceRadius: Theme.panelRadius
        backdropOpacity: Theme.clamp01(presence.value)
        contentOpacity: Theme.clamp01(presence.value)
        scale: grow * fit

        Text {
          x: Theme.keysPad
          y: Theme.keysPad
          text: "Keys"
          color: Theme.inkPrimary
          font.family: Theme.displayFont
          font.pixelSize: Theme.panelTitleSize
          font.weight: Theme.weightSemi
        }

        // How it got here, at the far end of the title's line.
        Row {
          x: card.width - Theme.keysPad - width
          y: Theme.keysPad
          spacing: Theme.keysChordGap

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Hold"
            color: Theme.inkTertiary
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSize
          }

          Keycap {
            text: "AltGr"
          }
        }

        Row {
          id: columns

          x: Theme.keysPad
          y: Theme.keysHeaderHeight
          spacing: Theme.keysColumnGap

          Repeater {
            model: Keymap.columns

            KeyColumn {
              required property var modelData

              sections: modelData
            }
          }
        }
      }
    }
  }
}
