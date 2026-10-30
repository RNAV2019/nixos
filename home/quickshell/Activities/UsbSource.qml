import QtQuick
import Quickshell
import qs.Commons
import qs.Services

// Each mounted USB drive (Penpot "Ariadne / Satellite / USB"): a drive glyph, running round
// while it is being ejected, and a card with its space and Open / Eject; and the moments for a
// drive being plugged in, being safe to remove, and an eject that did not work. A drive that is
// not mounted is not an activity; its moment's Open mounts it (see Services/Usb.qml).
Scope {
  id: root

  Instantiator {
    model: Usb.drives.filter(d => d.mounts.length > 0 || Usb.ejecting[d.device] === true)

    delegate: Activity {
      id: act

      required property var modelData

      readonly property bool busy: Usb.ejecting[modelData.device] === true

      kind: "usb"
      key: "usb:" + modelData.id

      icon: IconPaths.hardDrive
      iconColor: busy ? Theme.inkSecondary : Theme.inkPrimary
      indeterminate: busy
      ring: -1
      ringColor: Theme.accent

      title: Usb.name(modelData)
      subtitle: busy ? "Ejecting…" : Usb.describe(modelData)
      value: modelData.total > 0 ? Usb.bytes(modelData.free) : ""

      card: Component {
        UsbCard {
          device: act ? act.modelData.device : ""
        }
      }
    }
  }

  Connections {
    target: Usb

    function onInserted(drive) {
      Activities.raiseMoment({
        kind: "usb-inserted",
        key: "usb:" + drive.id,
        attention: false,
        icon: IconPaths.hardDrive,
        iconColor: Theme.accent,
        title: Usb.name(drive),
        subtitle: Usb.bytes(drive.size) + " · " + Usb.fsName(drive.fs),
        buttons: [
          {
            text: "Eject",
            kind: "ghost",
            width: 60,
            action: () => Usb.eject(drive.device)
          },
          {
            text: "Open",
            kind: "primary",
            width: 60,
            action: () => Usb.open(drive.device)
          }
        ]
      });
    }

    function onEjected(name) {
      Activities.raiseMoment({
        kind: "usb-safe",
        key: "usb-eject",
        attention: false,
        icon: IconPaths.check,
        iconColor: Theme.accent,
        title: "Safe to remove",
        subtitle: name,
        dwell: 5000,
        buttons: []
      });
    }

    function onProblem(title, message) {
      Activities.raiseMoment({
        kind: "usb-error",
        key: "usb-eject",
        attention: true,
        icon: IconPaths.circleX,
        iconColor: Theme.urgent,
        title: title,
        subtitle: message,
        dwell: 10000,
        buttons: []
      });
    }
  }
}
