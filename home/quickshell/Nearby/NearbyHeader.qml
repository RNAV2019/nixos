import QtQuick
import qs.Commons
import qs.Services
import qs.Ui

// The header both directions share: the protocol stack on the left, Send / Receive on the right.
Item {
  id: root

  property string direction: "send"

  signal directionChosen(string direction)

  width: parent.width
  height: Theme.nearbyHeaderHeight

  // Labels only: three cells with glyphs would not fit beside the direction control.
  Segmented {
    x: Theme.nearbyHeaderSide
    fit: true
    currentIndex: Nearby.platform === "kdeconnect" ? 0 : Nearby.platform === "apple" ? 2 : 1
    pending: Nearby.busy
    accessibleName: "Protocol"
    segments: [
      {
        "label": "KDE Connect"
      },
      {
        "label": "Android"
      },
      {
        "label": "Apple"
      }
    ]
    onChosen: function (index) {
      Nearby.setPlatform(index === 0 ? "kdeconnect" : index === 2 ? "apple" : "android");
    }
  }

  Segmented {
    x: parent.width - Theme.nearbyHeaderSide - Theme.nearbyTrackWidth
    currentIndex: root.direction === "receive" ? 1 : 0
    accessibleName: "Direction"
    segments: [
      {
        "icon": IconPaths.arrowUp,
        "label": "Send"
      },
      {
        "icon": IconPaths.arrowDown,
        "label": "Receive"
      }
    ]
    onChosen: function (index) {
      root.directionChosen(index === 1 ? "receive" : "send");
    }
  }
}
