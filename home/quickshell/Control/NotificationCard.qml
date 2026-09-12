import QtQuick
import Quickshell.Widgets
import qs.Commons
import qs.Services
import qs.Ui

Rectangle {
  id: root

  property string appName: ""
  property string summary: ""
  property string body: ""
  property string image: ""
  property string appIcon: ""
  property bool urgent: false

  signal dismissed

  readonly property string iconSource: NotificationStore.iconFor(image, appIcon)

  implicitHeight: body !== "" ? 48 + Math.ceil(bodyText.implicitHeight) + 14 : 62

  radius: Theme.controlNotifRadius
  color: Theme.surfaceSubtle
  border.width: 1
  border.color: urgent ? Theme.withAlpha(Theme.dangerFill, 0.7) : Theme.withAlpha(Theme.separator, 0.8)

  readonly property color accentColour: urgent ? Theme.urgent : NotificationStore.avatarColour(appName)

  Rectangle {
    id: avatar

    x: 14
    y: 14
    width: Theme.controlNotifAvatar
    height: Theme.controlNotifAvatar
    radius: height / 2
    color: Theme.withAlpha(root.accentColour, 0.22)

    Text {
      anchors.centerIn: parent
      visible: !icon.visible
      text: NotificationStore.initial(root.appName)
      color: root.accentColour
      font.family: Theme.uiFont
      font.pixelSize: Theme.controlNotifBodySize
      font.weight: Font.Bold
    }

    IconImage {
      id: icon

      anchors.fill: parent
      anchors.margins: 3
      source: root.iconSource
      // An unresolved icon falls back to the letter rather than a hole in the avatar.
      visible: root.iconSource !== "" && status !== Image.Error && status !== Image.Null
    }
  }

  Text {
    x: Theme.controlNotifTextLeft
    y: 13
    width: Math.max(0, dismiss.x - x - 10)
    text: root.appName
    color: Theme.inkTertiary
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlSectionSize
    elide: Text.ElideRight
  }

  Text {
    x: Theme.controlNotifTextLeft
    y: 28
    width: Math.max(0, dismiss.x - x - 10)
    text: root.summary
    color: Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlNotifTitleSize
    font.weight: Theme.weightSemi
    elide: Text.ElideRight
  }

  Text {
    id: bodyText

    x: Theme.controlNotifTextLeft
    y: 48
    width: Math.max(0, root.width - x - 20)
    visible: root.body !== ""
    text: root.body
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlNotifBodySize
    lineHeight: 1.3
    textFormat: Text.StyledText
    wrapMode: Text.WordWrap
    maximumLineCount: 3
    elide: Text.ElideRight
  }

  Text {
    id: dismiss

    x: root.width - 30
    y: 14
    text: Icons.close
    Accessible.role: Accessible.Button
    Accessible.name: "Dismiss notification"
    Accessible.focusable: true
    Accessible.focused: dismissHover.activeFocus
    Accessible.onPressAction: root.dismissed()
    color: dismissHover.containsMouse ? Theme.inkPrimary : Theme.inkTertiary
    scale: dismissHover.pressed ? 0.95 : 1

    Behavior on color {
      Tint {}
    }

    Behavior on scale {
      Morph { duration: Theme.morphState }
    }
    font.family: Theme.iconFont
    font.pixelSize: 14

    MouseArea {
      id: dismissHover

      anchors.fill: parent
      anchors.margins: -8
      hoverEnabled: true
      activeFocusOnTab: true
      cursorShape: Qt.PointingHandCursor
      onPressed: dismissHover.forceActiveFocus()
      onClicked: root.dismissed()
    }
  }
}
