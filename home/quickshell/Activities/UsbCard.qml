import QtQuick
import qs.Commons
import qs.Services
import qs.Ui

// The hover card of a USB satellite (Penpot "Ariadne / Activity card / USB"): the drive's
// label, its filesystem and size, how much of it is used, and Open and Eject; while it ejects,
// a spinner and the reminder to keep it plugged in.
Item {
  id: root

  required property string device

  readonly property var drive: Usb.find(device)
  readonly property bool busy: Usb.ejecting[device] === true
  readonly property real total: drive && drive.total > 0 ? drive.total : 0
  readonly property real used: drive && drive.used !== undefined ? drive.used : 0
  readonly property color tint: busy ? Theme.inkTertiary : Theme.accent

  implicitWidth: Theme.activityCardWidth
  implicitHeight: 160

  CardHeader {
    icon: IconPaths.hardDrive
    tint: root.busy ? Theme.inkSecondary : Theme.accent
    title: root.drive ? Usb.name(root.drive) : ""
    caption: root.busy ? "Ejecting…" : root.drive ? Usb.describe(root.drive) : ""
  }

  ProgressTrack {
    x: Theme.activityCardPad
    y: 70
    width: root.width - 2 * Theme.activityCardPad
    fraction: root.total > 0 ? root.used / root.total : 0
    tint: root.tint
  }

  Text {
    visible: root.total > 0
    x: Theme.activityCardPad
    y: 96 - height / 2
    text: Usb.bytes(root.used) + " used"
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: Theme.activityDetailSize
  }

  Text {
    visible: root.total > 0
    x: root.width - Theme.activityCardPad - width
    y: 96 - height / 2
    text: Usb.bytes(root.total - root.used) + " free"
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: Theme.activityDetailSize
    font.weight: Theme.weightSemi
  }

  Row {
    visible: !root.busy
    x: Theme.activityCardPad
    y: 114
    spacing: Theme.activityButtonGap

    ActivityButton {
      kind: "primary"
      width: 112
      icon: IconPaths.folderOpen
      text: "Open"
      onClicked: {
        Usb.open(root.device);
        Activities.closeCard();
      }
    }

    ActivityButton {
      kind: "secondary"
      width: 92
      icon: IconPaths.eject
      text: "Eject"
      onClicked: Usb.eject(root.device)
    }
  }

  Row {
    visible: root.busy
    x: Theme.activityCardPad
    y: 129 - height / 2
    spacing: 8

    StrokeIcon {
      id: spinner

      anchors.verticalCenter: parent.verticalCenter
      size: 14
      strokeWidth: 1.75
      path: IconPaths.loaderCircle
      color: Theme.accent

      RotationAnimator on rotation {
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
        running: root.busy && root.visible && !Theme.reduceMotion
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "Flushing writes — keep it plugged in"
      color: Theme.inkSecondary
      font.family: Theme.uiFont
      font.pixelSize: Theme.activityDetailSize
    }
  }
}
