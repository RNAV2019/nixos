import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Ui

// The keybind cheatsheet: the island grown into a wide card of every shortcut while Super is
// held on its own. Hyprland times the hold (home/desktop.nix) and tells the shell through
// Bus.cheatsheetWanted; the card takes no keys and no pointer, so the window under it is
// left exactly as it was and any combo started from the hold still reaches it. The rows are
// generated from the bind table (Services/Keybinds.qml), never listed here.
Variants {
  id: root

  model: Quickshell.screens

  IslandSurface {
    id: win

    key: "cheatsheet"
    takesInput: false
    openWidth: Theme.panelWidth(modelData, Theme.cheatWidth)
    openHeight: Theme.cheatBodyTop + Keybinds.bodyHeight + Theme.cheatBottom
    openRadius: Theme.panelRadius

    // The width left for a column once the sides and gaps are out, so a narrow output
    // shrinks the columns rather than running off the card.
    readonly property real columnWidth: Math.min(Theme.cheatColumnWidth, (win.openWidth - 2 * Theme.cheatInset - (Theme.cheatColumns - 1) * Theme.cheatColumnGap) / Theme.cheatColumns)

    // Shown on the focused output while wanted, unless a panel the user opened is up, which
    // the sheet would shove aside. Nothing with no rows to show.
    readonly property bool wanted: Bus.cheatsheetWanted && !Bus.locking && Bus.sessionReady && Keybinds.groups.length > 0 && win.focused

    onWantedChanged: {
      if (wanted && !win.open && !Bus.islandOpenAnywhere)
        win.show();
      else if (!wanted && win.open)
        win.hide();
    }

    // A hide that never arrived would leave the card up for good.
    Timer {
      running: win.open
      interval: Theme.cheatTimeout
      onTriggered: win.hide()
    }

    Text {
      x: Theme.cheatInset
      y: (Theme.cheatHeaderHeight - height) / 2
      text: "Shortcuts"
      color: Theme.inkPrimary
      font.family: Theme.uiFont
      font.pixelSize: Theme.cheatTitleSize
      font.weight: Theme.weightMedium
    }

    // The key being held, as the design shows it.
    Rectangle {
      x: win.openWidth - Theme.cheatInset - width
      y: (Theme.cheatHeaderHeight - height) / 2
      width: badge.implicitWidth + Theme.cheatBadgePad * 2
      height: Theme.cheatBadgeHeight
      radius: Theme.cheatBadgeRadius
      color: Theme.accentFill

      Text {
        id: badge

        anchors.centerIn: parent
        text: "Super"
        color: Theme.inkOnAccent
        font.family: Theme.uiFont
        font.pixelSize: Theme.cheatBadgeSize
        font.weight: Theme.weightBold
      }
    }

    Rectangle {
      x: Theme.launcherInset
      y: Theme.cheatHeaderHeight
      width: win.openWidth - 2 * Theme.launcherInset
      height: 1
      color: Theme.withAlpha(Theme.separator, 0.6)
    }

    Repeater {
      model: Keybinds.columns

      Column {
        id: column

        required property var modelData
        required property int index

        x: Theme.cheatInset + index * (win.columnWidth + Theme.cheatColumnGap)
        y: Theme.cheatBodyTop
        width: win.columnWidth
        spacing: Theme.cheatGroupGap

        Repeater {
          model: column.modelData

          Item {
            id: group

            required property var modelData

            width: column.width
            height: Keybinds.groupHeight(modelData)

            Text {
              y: Theme.cheatHeadY
              text: group.modelData.group
              color: Theme.inkTertiary
              font.family: Theme.uiFont
              font.pixelSize: Theme.sectionSize
              font.weight: Theme.weightMedium
            }

            Repeater {
              model: group.modelData.rows

              Item {
                id: row

                required property var modelData
                required property int index

                y: Theme.cheatHeadBand + index * Theme.cheatRowPitch
                width: group.width
                height: Theme.cheatRowPitch

                Text {
                  y: 6
                  width: row.width - caps.width - Theme.cheatCapGap * 3
                  text: row.modelData.desc
                  elide: Text.ElideRight
                  color: Theme.inkPrimary
                  font.family: Theme.uiFont
                  font.pixelSize: Theme.cheatRowSize
                  font.weight: Theme.weightMedium
                }

                Row {
                  id: caps

                  anchors.right: parent.right
                  y: 3
                  spacing: Theme.cheatCapGap

                  Repeater {
                    model: row.modelData.keys

                    KeyCap {
                      required property string modelData

                      name: modelData
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
