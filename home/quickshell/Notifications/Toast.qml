import QtQuick
import qs.Commons
import qs.Services
import qs.Ui
import "../Ui/Motion.js" as Motion

// One notification's card contents, at the board's positions.
Item {
  id: toast

  // The window, and the minute clock: this file cannot see Notifications.qml's ids.
  property var host: null
  property date clockDate: new Date()
  // The snapshot drawn (see snapshot()), or null before the first one.
  property var n: null
  // The slot the card is showing. Only it takes input.
  property bool live: false
  // Names its spring in the motion log ("A", "B").
  property string slot: ""

  readonly property bool urgent: toast.n ? toast.n.urgent : false
  readonly property string appName: toast.n ? toast.n.appName : ""
  readonly property bool iconTinted: toast.n ? toast.n.iconTinted : false
  readonly property color tint: toast.urgent ? Theme.love : NotificationStore.avatarColour(toast.appName, toast.iconTinted)
  readonly property var buttons: toast.n ? toast.n.buttons : []

  readonly property int bodyLines: !toast.n || toast.n.body === "" ? 0 : Math.min(Theme.notifBodyLines, bodyMetrics.lineCount)

  // Nothing on this bus carries a source line, so the body starts where it would have.
  readonly property int bodyTop: Theme.notifBodyTopBare
  readonly property int bodyBottom: bodyLines > 0 ? bodyTop + bodyLines * Theme.notifBodyLeading - 3 : Theme.notifTitleTop + 18
  readonly property int actionsTop: bodyBottom + Theme.notifActionGapAbove
  readonly property int cardHeight: Math.max(Theme.notifAvatarSize + Theme.notifInset * 2, actionsTop + Theme.notifActionHeight + Theme.notifPadBottom)

  readonly property string timestamp: {
    toast.clockDate;
    if (!toast.n)
      return "";
    var mins = Math.floor((Date.now() - toast.n.arrived.getTime()) / 60000);
    if (mins < 1)
      return "now";
    if (mins === 1)
      return "1 min ago";
    return mins + " min ago";
  }

  anchors.fill: parent
  enabled: toast.live
  // The card's presence is one spring (0 hidden, 1 shown) that a toast taking over or giving
  // way retargets with its speed. In, the opacity is the progress itself; out, it is spent over
  // the first 0.6 of the travel, so a card leaving clears before the next one is fully there.
  opacity: toast.live ? present.value : Math.min(present.value, Motion.ramp(present.value, 0.4, 1))
  visible: opacity > 0 && toast.n !== null

  ProgressSpring {
    id: present

    target: toast.live ? 1 : 0
    label: "toast." + toast.slot
  }

  // The sender's icon, or its initial on a colour picked off the name.
  Rectangle {
    id: avatar

    x: Theme.notifInset
    y: Theme.notifInset
    width: Theme.notifAvatarSize
    height: width
    radius: width / 2
    color: Theme.withAlpha(toast.tint, Theme.notifAvatarAlpha)

    Text {
      anchors.centerIn: parent
      text: NotificationStore.initial(toast.appName)
      color: toast.tint
      visible: !appIcon.shown
      font.family: Theme.uiFont
      font.pixelSize: Theme.notifAvatarLetterSize
      font.weight: Theme.weightBold
    }

    NotificationIcon {
      id: appIcon

      anchors.centerIn: parent
      width: parent.width - 12
      height: width
      source: toast.n ? toast.n.iconSource : ""
      tinted: toast.iconTinted
      tint: toast.tint
    }
  }

  Text {
    x: Theme.notifTextLeft
    y: Theme.notifAppTop
    width: Math.max(0, stamp.x - x - Theme.notifActionGap)
    text: toast.appName
    color: toast.tint
    elide: Text.ElideRight
    font.family: Theme.uiFont
    font.pixelSize: Theme.notifAppSize
    font.weight: Theme.weightMedium
  }

  Text {
    id: stamp

    x: closeGlyph.x - width - Theme.notifActionGap
    y: Theme.notifAppTop
    text: toast.timestamp
    color: Theme.muted
    font.family: Theme.uiFont
    font.pixelSize: Theme.notifAppSize
  }

  Button {
    id: closeGlyph

    x: Theme.notifWidth - Theme.notifInset - width
    y: Theme.notifAppTop + 1.5
    kind: Button.Icon
    icon: Icons.close
    iconSize: Theme.notifCloseSize
    baseColor: Theme.muted
    hoverColor: Theme.text
    hitSlop: 6
    accessibleName: "Dismiss notification"

    onClicked: toast.host.close()
  }

  Text {
    x: Theme.notifTextLeft
    y: Theme.notifTitleTop
    width: Theme.notifWidth - x - Theme.notifInset
    text: toast.n ? toast.n.summary : ""
    color: toast.urgent ? Theme.love : Theme.text
    elide: Text.ElideRight
    font.family: Theme.uiFont
    font.pixelSize: Theme.notifTitleSize
    font.weight: Theme.weightSemi
  }

  Text {
    id: bodyMetrics

    x: Theme.notifTextLeft
    y: toast.bodyTop
    width: Theme.notifWidth - x - Theme.notifInset
    text: toast.n ? toast.n.body : ""
    visible: text !== ""
    color: Theme.subtle
    textFormat: Text.StyledText
    wrapMode: Text.WordWrap
    maximumLineCount: Theme.notifBodyLines
    elide: Text.ElideRight
    // Fixed leading, so height follows from a line count, not a measurement.
    lineHeightMode: Text.FixedHeight
    lineHeight: Theme.notifBodyLeading
    font.family: Theme.uiFont
    font.pixelSize: Theme.notifBodySize
  }

  // Laid out right to left: the sender's own buttons first, ours last.
  Row {
    id: actions

    layoutDirection: Qt.RightToLeft
    spacing: Theme.notifActionGap
    x: Theme.notifWidth - Theme.notifInset - width
    y: toast.actionsTop

    Repeater {
      model: toast.buttons

      Button {
        required property int index
        required property var modelData

        text: modelData.text
        kind: index === 0 ? Button.Primary : Button.Neutral
        onClicked: toast.host.invoke(modelData.action)
      }
    }

    // Always present and leftmost. A critical notification says Ignore, not
    // Dismiss, because sending it away is not dealing with it.
    Button {
      text: toast.urgent ? "Ignore" : "Dismiss"
      kind: toast.buttons.length === 0 ? Button.Primary : Button.Neutral
      onClicked: toast.host.close()
    }
  }

  // How many more are waiting, where the action row starts. Counting down cross-fades the
  // digits; with nothing waiting it goes.
  QueueChip {
    x: Theme.notifTextLeft
    y: toast.actionsTop + (Theme.notifActionHeight - height) / 2
    count: toast.host ? toast.host.queued : 0
    shown: toast.live
  }
}
