import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Commons

Scope {
  id: root

  readonly property int maxVisible: 3
  readonly property int defaultTimeout: 5000

  property var shown: []

  NotificationServer {
    id: server

    keepOnReload: false
    actionsSupported: true
    imageSupported: true
    bodySupported: true
    bodyMarkupSupported: true

    onNotification: function (notification) {
      notification.tracked = true;

      var next = shown.slice();
      for (var i = 0; i < next.length; i++) {
        if (next[i].appName === notification.appName) {
          next[i].dismiss();
          next.splice(i, 1);
          break;
        }
      }

      next.unshift(notification);
      while (next.length > root.maxVisible) {
        next[next.length - 1].dismiss();
        next.pop();
      }
      root.shown = next;
    }
  }

  function forget(notification) {
    var next = [];
    for (var i = 0; i < shown.length; i++) {
      if (shown[i] !== notification)
        next.push(shown[i]);
    }
    shown = next;
  }

  // Toasts belong on the output the user is looking at.
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: window

      required property var modelData

      readonly property bool focused: Monitors.isFocused(window.screen)

      screen: modelData
      visible: root.shown.length > 0 && focused
      color: "transparent"

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "quickshell-notifications"

      anchors {
        top: true
        right: true
      }

      implicitWidth: 420 + 16
      implicitHeight: Math.max(1, column.implicitHeight)
      margins.top: Theme.barMarginTop + Theme.barHeight + Theme.gapsOut
      exclusionMode: ExclusionMode.Ignore

      Column {
        id: column
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingXl
        anchors.top: parent.top
        width: 420
        spacing: Theme.spacingMd

        Repeater {
          model: root.shown

          Rectangle {
            id: card

            required property var modelData

            width: parent.width
            implicitHeight: Math.max(56, body.implicitHeight + 40)

            radius: 4
            color: Theme.base
            border.width: 1
            border.color: Theme.overlay

            // Per spec, 0 never expires and negatives use the default. Pausing
            // on hover keeps a notification from vanishing mid-read; the timer
            // restarts rather than resuming, which is the forgiving direction.
            Timer {
              running: card.modelData.expireTimeout !== 0 && !cardHover.hovered
              interval: card.modelData.expireTimeout > 0 ? card.modelData.expireTimeout : root.defaultTimeout
              onTriggered: {
                card.modelData.expire();
                root.forget(card.modelData);
              }
            }

            IconImage {
              id: icon
              anchors.left: parent.left
              anchors.leftMargin: Theme.spacingXl
              anchors.verticalCenter: parent.verticalCenter
              width: 32
              height: 32
              // Hide unresolved icons to avoid an empty 32 px gutter.
              visible: source !== "" && backer.status !== Image.Error && backer.status !== Image.Null
              source: card.modelData.image !== "" ? card.modelData.image : (card.modelData.appIcon !== "" ? card.modelData.appIcon : "")
            }

            Column {
              id: body
              anchors.left: icon.visible ? icon.right : parent.left
              anchors.leftMargin: Theme.spacingXl
              anchors.right: parent.right
              anchors.rightMargin: Theme.spacingXl
              anchors.verticalCenter: parent.verticalCenter
              spacing: Theme.spacingXs

              Text {
                width: parent.width
                text: card.modelData.summary
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                visible: card.modelData.body !== ""
                text: card.modelData.body
                color: Theme.subtle
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                textFormat: Text.StyledText
                wrapMode: Text.WordWrap
                maximumLineCount: 4
                elide: Text.ElideRight
              }
            }

            HoverHandler {
              id: cardHover
            }

            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              cursorShape: Qt.PointingHandCursor
              onClicked: function (event) {
                if (event.button === Qt.LeftButton) {
                  var actions = card.modelData.actions;
                  for (var i = 0; i < actions.length; i++) {
                    if (actions[i].identifier === "default") {
                      actions[i].invoke();
                      break;
                    }
                  }
                }
                card.modelData.dismiss();
                root.forget(card.modelData);
              }
            }
          }
        }
      }
    }
  }
}
