import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Services
import qs.Ui

// The phone's hover card (Penpot "Ariadne / Phone card"): the name and link, the battery, up to
// three of its notifications (a click dismisses one on the phone), this machine's clipboard with
// a button that sends it to the phone, Ring phone and Send files. Beside them, a live thumbnail
// of the phone's screen when an adb device is connected (Services/Phone.qml); 440 wide with it,
// 360 without. Laid out at its final size; the island's card grows over it.
Item {
  id: root

  readonly property bool preview: Phone.previewAvailable

  implicitWidth: preview ? Theme.phoneCardWidth : Theme.phoneCardCompactWidth
  implicitHeight: Theme.phoneCardHeight

  readonly property real colX: preview ? 156 : 16
  readonly property real colWidth: width - Theme.activityCardPad - colX

  // Ages follow the clock while the card is up.
  property real now: Date.now()

  Timer {
    interval: 15000
    repeat: true
    running: root.visible
    onTriggered: root.now = Date.now()
  }

  function shortAge(ms) {
    if (!ms)
      return "";
    var mins = Math.floor((root.now - ms) / 60000);
    if (mins < 1)
      return "now";
    if (mins < 60)
      return mins + "m";
    var hours = Math.floor(mins / 60);
    return hours < 24 ? hours + "h" : Math.floor(hours / 24) + "d";
  }

  function longAge(ms) {
    return NotificationStore.ago(ms, root.now);
  }

  // ---- header ----

  readonly property color batteryInk: Phone.low ? Theme.love : Theme.accent

  CardHeader {
    icon: IconPaths.smartphone
    tint: Theme.accent
    title: Phone.name
    caption: Phone.caption
    titleSize: 15
    reserve: Phone.hasBattery ? batteryText.width + 24 + 12 : 0
  }

  Text {
    id: batteryText

    x: root.width - Theme.activityCardPad - width
    y: 34 - height / 2
    visible: Phone.hasBattery
    text: Phone.charge + "%"
    color: root.batteryInk
    font.family: Theme.uiFont
    font.pixelSize: 13
    font.weight: Theme.weightSemi
  }

  StrokeIcon {
    x: batteryText.x - 6 - size
    y: 34 - size / 2
    visible: Phone.hasBattery
    size: 18
    strokeWidth: 1.75
    path: Phone.charging ? IconPaths.batteryCharging : IconPaths.battery
    color: Phone.low ? Theme.love : Phone.charging ? Theme.accent : Theme.inkSecondary
  }

  // ---- the screen ----

  Item {
    id: screen

    x: Theme.activityCardPad
    y: 68
    width: Theme.phonePreviewWidth
    height: Theme.phonePreviewHeight
    visible: root.preview

    Item {
      anchors.fill: parent
      layer.enabled: true
      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: screenMask
      }

      Rectangle {
        anchors.fill: parent
        color: Theme.surfaceSubtle
      }

      StrokeIcon {
        anchors.centerIn: parent
        visible: frame.status !== Image.Ready
        size: 22
        strokeWidth: 1.75
        path: IconPaths.smartphone
        color: Theme.inkTertiary
      }

      Image {
        id: frame

        anchors.fill: parent
        source: Phone.previewUrl
        sourceSize: Qt.size(Theme.phonePreviewWidth * 2, Theme.phonePreviewHeight * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: status === Image.Ready
      }
    }

    Item {
      id: screenMask

      anchors.fill: parent
      visible: false
      layer.enabled: true

      Rectangle {
        anchors.fill: parent
        radius: Theme.phonePreviewRadius
        color: "black"
      }
    }

    // The bezel: 1.5 px, inside the edge.
    Rectangle {
      anchors.fill: parent
      radius: Theme.phonePreviewRadius
      color: "transparent"
      border.width: 1.5
      border.color: Theme.highlightHigh
    }
  }

  // ---- notifications ----

  Text {
    x: root.colX
    y: 74 - height / 2
    text: "Notifications"
    color: Theme.inkTertiary
    font.family: Theme.uiFont
    font.pixelSize: Theme.sectionSize
    font.weight: Theme.weightMedium
  }

  Text {
    x: root.colX
    y: 88 + (3 * 44 - 4 - height) / 2
    width: root.colWidth
    visible: Phone.notifications.length === 0
    horizontalAlignment: Text.AlignHCenter
    text: "Nothing new on the phone"
    color: Theme.inkTertiary
    font.family: Theme.uiFont
    font.pixelSize: 12
  }

  Repeater {
    model: Phone.notifications.slice(0, 3)

    Item {
      id: row

      required property var modelData
      required property int index

      readonly property string label: modelData.app !== "" ? modelData.app : modelData.title

      x: root.colX
      y: 88 + index * 44
      width: root.colWidth
      height: 40

      Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: 12
        color: Theme.withAlpha(Theme.surfaceSubtle, 0.9)
        opacity: rowArea.containsMouse && row.modelData.dismissable ? 1 : 0

        Behavior on opacity {
          Morph {
            duration: Theme.morphState
          }
        }
      }

      Rectangle {
        id: avatar

        x: 0
        y: 7
        width: 28
        height: 28
        radius: 14
        color: Theme.withAlpha(Theme.stableAccent(row.label), Theme.notifAvatarAlpha)

        Text {
          anchors.centerIn: parent
          visible: !glyph.visible
          text: row.label.length > 0 ? row.label.charAt(0).toUpperCase() : ""
          color: Theme.stableAccent(row.label)
          font.family: Theme.uiFont
          font.pixelSize: 12
          font.weight: Theme.weightBold
        }

        Image {
          id: glyph

          anchors.fill: parent
          anchors.margins: 5
          visible: row.modelData.icon !== "" && status === Image.Ready
          source: row.modelData.icon !== "" ? "file://" + row.modelData.icon : ""
          sourceSize: Qt.size(56, 56)
          fillMode: Image.PreserveAspectFit
          asynchronous: true
        }
      }

      Text {
        x: 38
        y: 13 - height / 2
        width: Math.max(0, root.colWidth - 38 - 28)
        elide: Text.ElideRight
        text: row.modelData.title !== "" ? row.modelData.title : row.modelData.app
        textFormat: Text.PlainText
        color: Theme.inkPrimary
        font.family: Theme.uiFont
        font.pixelSize: Theme.activityRowTitleSize
        font.weight: Theme.weightSemi
      }

      Text {
        x: 38
        y: 29 - height / 2
        width: root.colWidth - 38
        elide: Text.ElideRight
        text: row.modelData.text
        textFormat: Text.PlainText
        color: Theme.inkSecondary
        font.family: Theme.uiFont
        font.pixelSize: 11
      }

      // The age, which a click on a dismissable one turns into the cross that does it.
      Text {
        x: row.width - width
        y: 13 - height / 2
        visible: !cross.visible
        text: root.shortAge(row.modelData.time)
        color: Theme.inkTertiary
        font.family: Theme.uiFont
        font.pixelSize: Theme.momentSubtitleSize
      }

      StrokeIcon {
        id: cross

        x: row.width - size
        y: 13 - size / 2
        visible: rowArea.containsMouse && row.modelData.dismissable
        size: 12
        strokeWidth: 1.75
        path: IconPaths.x
        color: Theme.inkSecondary
      }

      MouseArea {
        id: rowArea

        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: row.modelData.dismissable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (row.modelData.dismissable)
          Phone.dismiss(row.modelData.id)
      }
    }
  }

  // ---- clipboard ----

  Text {
    x: root.colX
    y: 234 - height / 2
    text: "Clipboard"
    color: Theme.inkTertiary
    font.family: Theme.uiFont
    font.pixelSize: Theme.sectionSize
    font.weight: Theme.weightMedium
  }

  readonly property bool clipSent: Phone.clipText !== "" && Phone.sentText === Phone.clipText && Phone.sentAt > 0

  readonly property string clipCaption: {
    if (Phone.clipText === "")
      return "Copy something to share it";
    if (root.clipSent)
      return "Sent to phone · " + root.longAge(Phone.sentAt);
    return Phone.clipAt > 0 ? "On this computer · " + root.longAge(Phone.clipAt) : "On this computer";
  }

  Rectangle {
    id: well

    x: root.colX
    y: 246
    width: root.colWidth
    height: 44
    radius: Theme.activityWellRadius
    color: Theme.surfaceSubtle

    Text {
      x: 12
      y: 14 - height / 2
      width: parent.width - 12 - 44
      elide: Text.ElideRight
      text: Phone.clipText !== "" ? Phone.clipText.replace(/\s+/g, " ") : "Nothing copied yet"
      textFormat: Text.PlainText
      color: Phone.clipText !== "" ? Theme.inkPrimary : Theme.inkTertiary
      font.family: Theme.uiFont
      font.pixelSize: 12
    }

    Text {
      x: 12
      y: 31 - height / 2
      width: parent.width - 12 - 44
      elide: Text.ElideRight
      text: root.clipCaption
      color: Theme.inkTertiary
      font.family: Theme.uiFont
      font.pixelSize: Theme.momentSubtitleSize
    }

    Rectangle {
      id: sendButton

      readonly property bool enabled: Phone.clipText !== ""

      x: parent.width - 12 - width
      y: (parent.height - height) / 2
      width: 26
      height: 26
      radius: 13
      color: sendArea.containsMouse && enabled ? Qt.lighter(Theme.withAlpha(Theme.separator, 0.85), 1.06) : Theme.withAlpha(Theme.separator, 0.85)
      opacity: enabled ? 1 : 0.4
      scale: sendArea.pressed && enabled ? Theme.pressScale : 1

      Behavior on scale {
        Morph {
          duration: Theme.morphState
        }
      }

      StrokeIcon {
        anchors.centerIn: parent
        size: 13
        strokeWidth: 1.75
        path: root.clipSent ? IconPaths.check : IconPaths.send
        color: root.clipSent ? Theme.accent : Theme.inkPrimary
      }

      MouseArea {
        id: sendArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: sendButton.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (sendButton.enabled)
          Phone.sendClipboard()
      }
    }
  }

  // ---- actions ----

  Row {
    x: root.colX
    y: 298
    spacing: Theme.activityButtonGap

    ActivityButton {
      width: (root.colWidth - Theme.activityButtonGap) / 2
      kind: "secondary"
      icon: IconPaths.bellRing
      text: Phone.ringing ? "Ringing…" : "Ring phone"
      onClicked: Phone.ring()
    }

    ActivityButton {
      width: (root.colWidth - Theme.activityButtonGap) / 2
      kind: "secondary"
      icon: IconPaths.folderOpen
      text: "Send files"
      onClicked: {
        Activities.closeCard();
        Nearby.requestSend([]);
      }
    }
  }
}
