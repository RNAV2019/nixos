import QtQuick
import qs.Commons
import qs.Services
import qs.Ui

// One application's notifications in the control centre's list. A lone one is a plain card; two
// or more sit behind a header with their count, collapsed to a line of preview or opened onto
// their rows. The group's height is a spring, so opening and closing it moves the groups below
// and the panel with it; the header's marks glide between their collapsed and open places on
// the same turn.
Item {
  id: root

  // The list's row for this application.
  required property string key
  required property string appName
  required property int count
  required property string summary
  required property string body
  required property string image
  required property string appIcon
  required property string desktopEntry
  required property bool urgent
  required property real arrived

  property bool expanded: false
  property date clockDate: new Date()

  signal toggled

  readonly property bool single: root.count < 2

  readonly property string iconSource: NotificationStore.iconFor(root.image, root.appIcon, root.desktopEntry, root.appName)
  readonly property bool iconTinted: NotificationStore.iconTinted(root.desktopEntry, root.appName)
  readonly property color accentColour: root.urgent ? Theme.urgent : NotificationStore.avatarColour(root.appName, root.iconTinted)

  // The rows follow the group's own list, which a notification arriving or leaving edits in
  // place; see Control/KeyedList.
  function syncEntries() {
    entries.sync(NotificationStore.entryRows(root.appName));
  }

  Component.onCompleted: root.syncEntries()

  Connections {
    target: NotificationStore

    function onRevisionChanged() {
      root.syncEntries();
    }
  }

  // 0 collapsed, 1 open; the header's marks ride it.
  property real openness: root.expanded ? 1 : 0

  Behavior on openness {
    Morph {
      duration: Theme.duration(Theme.morphState)
    }
  }

  // Open, it is as tall as its rows; the rows' own list glides when one comes or goes, and the
  // spring follows it.
  readonly property real targetHeight: {
    if (root.single)
      return card.implicitHeight;
    return root.expanded ? Theme.controlNotifGroupHeader + entries.height : Theme.controlNotifGroupCollapsed;
  }

  height: shape.value

  MorphSpring {
    id: shape

    target: root.targetHeight
  }

  // ---- a notification on its own ----

  NotificationCard {
    id: card

    width: parent.width
    visible: root.single
    appName: root.appName
    summary: root.summary
    body: root.body
    image: root.image
    appIcon: root.appIcon
    desktopEntry: root.desktopEntry
    urgent: root.urgent
    onDismissed: NotificationStore.clearApp(root.appName)
  }

  // ---- a group ----

  // A plate under the collapsed group, so it reads as more behind it.
  Rectangle {
    x: 10
    y: root.height + Theme.controlNotifSliver - height
    width: parent.width - 20
    height: 16
    radius: Theme.controlNotifRadius
    color: Theme.surfaceSubtle
    border.width: 1
    border.color: Theme.withAlpha(Theme.separator, 0.8)
    z: -1
    opacity: root.single ? 0 : 1 - root.openness
    visible: opacity > 0
  }

  Rectangle {
    id: group

    width: parent.width
    height: parent.height
    visible: !root.single
    radius: Theme.controlNotifRadius
    color: Theme.surfaceSubtle
    border.width: 1
    border.color: root.urgent ? Theme.withAlpha(Theme.dangerFill, 0.7) : Theme.withAlpha(Theme.separator, 0.8)
    clip: true

    Accessible.role: Accessible.Button
    Accessible.name: root.appName + ", " + root.count + " notifications, " + (root.expanded ? "open" : "closed")
    Accessible.focusable: true
    Accessible.onPressAction: root.toggled()
    activeFocusOnTab: !root.single

    Keys.onPressed: function (event) {
      if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        root.toggled();
        event.accepted = true;
      }
    }

    // The header, anywhere but its cross.
    MouseArea {
      width: parent.width
      height: root.expanded ? Theme.controlNotifGroupHeader : Theme.controlNotifGroupCollapsed
      cursorShape: Qt.PointingHandCursor
      onPressed: group.forceActiveFocus()
      onClicked: root.toggled()
    }

    Rectangle {
      id: avatar

      x: 14
      y: 14 - 6 * root.openness
      width: Theme.controlNotifAvatar
      height: width
      radius: width / 2
      color: Theme.withAlpha(root.accentColour, 0.22)

      Text {
        anchors.centerIn: parent
        visible: !icon.shown
        text: NotificationStore.initial(root.appName)
        color: root.accentColour
        font.family: Theme.uiFont
        font.pixelSize: Theme.controlNotifBodySize
        font.weight: Theme.weightBold
      }

      NotificationIcon {
        id: icon

        anchors.fill: parent
        anchors.margins: 3
        source: root.iconSource
        tinted: root.iconTinted
        tint: root.accentColour
      }
    }

    Text {
      id: name

      x: Theme.controlNotifTextLeft
      y: 10 + 4 * root.openness
      width: Math.min(implicitWidth, 250)
      text: root.appName
      color: Theme.inkPrimary
      elide: Text.ElideRight
      font.family: Theme.uiFont
      font.pixelSize: Theme.controlNotifRowTitleSize
      font.weight: Theme.weightSemi
    }

    // How many it holds.
    Rectangle {
      x: name.x + name.width + 8
      y: 12 + root.openness
      width: Math.max(22, countText.implicitWidth + 12)
      height: Theme.controlNotifChipHeight
      radius: height / 2
      color: Theme.withAlpha(Theme.highlightMed, Theme.notifActionSecondaryAlpha)

      Text {
        id: countText

        anchors.centerIn: parent
        text: root.count
        color: Theme.inkPrimary
        font.family: Theme.uiFont
        font.pixelSize: Theme.notifChipSize
        font.weight: Theme.weightSemi
      }
    }

    // The newest one's summary and body, until the rows take its place.
    Text {
      x: Theme.controlNotifTextLeft
      y: 29
      width: chevron.x - x - 8
      text: root.summary + (root.body !== "" ? " · " + root.body.replace(/\s*\n\s*/g, " ") : "")
      textFormat: Text.StyledText
      color: Theme.inkSecondary
      elide: Text.ElideRight
      opacity: 1 - root.openness
      visible: opacity > 0
      font.family: Theme.uiFont
      font.pixelSize: Theme.controlNotifBodySize
    }

    // One chevron, turned over as the group opens.
    StrokeIcon {
      id: chevron

      x: parent.width - 58
      y: 20 - 6 * root.openness
      size: 16
      strokeWidth: 1.75
      path: IconPaths.chevronDown
      color: Theme.inkTertiary
      rotation: 180 * root.openness
    }

    IconButton {
      x: parent.width - 30
      y: 21 - 6 * root.openness
      text: Icons.close
      font.family: Theme.iconFont
      font.pixelSize: 14
      baseColor: Theme.inkTertiary
      hoverColor: Theme.inkPrimary
      hitSlop: 8
      accessibleName: "Clear " + root.appName
      activeFocusOnTab: true

      onClicked: NotificationStore.clearApp(root.appName)
    }

    KeyedList {
      id: entries

      y: Theme.controlNotifGroupHeader
      width: parent.width
      spacing: 0
      animated: root.expanded
      opacity: root.openness
      visible: opacity > 0

      delegate: NotificationEntry {
        id: row

        width: entries.width
        clockDate: root.clockDate
        onDismissed: NotificationStore.dismissKey(row.key)
      }
    }
  }
}
