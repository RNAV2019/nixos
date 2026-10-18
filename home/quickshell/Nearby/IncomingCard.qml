import QtQuick
import qs.Commons
import qs.Services
import qs.Ui

// An inbound Quick Share offer (board 16g): the accent card carrying the sender, what they
// are offering, the consent PIN, and Decline / Accept. AirDrop has no consent step - omdrop
// accepts itself - so only Quick Share rows ever land here.
Rectangle {
  id: root

  // The transfer row from the daemon (direction "in", state "waiting_consent").
  required property var transfer

  signal accepted
  signal declined

  implicitWidth: Theme.nearbyWidth - Theme.nearbyInset * 2
  implicitHeight: Theme.nearbyIncomingHeight
  radius: Theme.nearbyIncomingRadius
  color: Theme.accentFill

  readonly property string sender: transfer && transfer.peer ? transfer.peer : "Unknown device"

  readonly property string payload: Nearby.payloadLabel(transfer)

  StrokeIcon {
    x: 16
    y: (root.height - Theme.nearbyIncomingGlyph) / 2
    size: Theme.nearbyIncomingGlyph
    strokeWidth: 1.75
    path: IconPaths.smartphone
    color: Theme.inkOnAccent
  }

  Text {
    x: 48
    y: 14
    width: root.width - 48 - 220
    elide: Text.ElideRight
    text: root.sender
    color: Theme.inkOnAccent
    font.family: Theme.uiFont
    font.pixelSize: Theme.nearbyIncomingSenderSize
    font.weight: Theme.weightSemi
  }

  Text {
    x: 48
    y: 33
    width: root.width - 48 - 220
    elide: Text.ElideRight
    text: root.payload
    color: Theme.withAlpha(Theme.inkOnAccent, 0.72)
    font.family: Theme.uiFont
    font.pixelSize: Theme.nearbyIncomingMetaSize
    font.weight: Theme.weightRegular
  }

  Row {
    x: root.width - Theme.nearbyRowInset - width
    y: (root.height - Theme.nearbyAnswerHeight) / 2
    spacing: 8

    Text {
      visible: root.transfer && root.transfer.pin
      anchors.verticalCenter: parent.verticalCenter
      text: root.transfer && root.transfer.pin ? root.transfer.pin : ""
      color: Theme.inkOnAccent
      font.family: Theme.monoFont
      font.pixelSize: Theme.nearbyPinSize
      font.weight: Theme.weightSemi
    }

    Item {
      width: 16
      height: 1
    }

    Rectangle {
      width: declineLabel.implicitWidth + 24
      height: Theme.nearbyAnswerHeight
      radius: Theme.nearbyAnswerRadius
      color: Theme.withAlpha(Theme.inkOnAccent, 0.12)
      border.width: 1
      border.color: Theme.withAlpha(Theme.inkOnAccent, 0.35)
      scale: declineArea.pressed ? Theme.pressScale : 1

      Behavior on scale {
        Morph {
          duration: Theme.morphState
        }
      }

      Text {
        id: declineLabel

        anchors.centerIn: parent
        text: "Decline"
        color: Theme.inkOnAccent
        font.family: Theme.uiFont
        font.pixelSize: Theme.nearbySectionSize
        font.weight: Theme.weightSemi
      }

      MouseArea {
        id: declineArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.declined()
      }

      Accessible.role: Accessible.Button
      Accessible.name: "Decline"
      Accessible.onPressAction: root.declined()
    }

    Rectangle {
      width: acceptLabel.implicitWidth + 24
      height: Theme.nearbyAnswerHeight
      radius: Theme.nearbyAnswerRadius
      color: Theme.inkOnAccent
      scale: acceptArea.pressed ? Theme.pressScale : 1

      Behavior on scale {
        Morph {
          duration: Theme.morphState
        }
      }

      Text {
        id: acceptLabel

        anchors.centerIn: parent
        text: "Accept"
        color: Theme.accentFill
        font.family: Theme.uiFont
        font.pixelSize: Theme.nearbySectionSize
        font.weight: Theme.weightSemi
      }

      MouseArea {
        id: acceptArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.accepted()
      }

      Accessible.role: Accessible.Button
      Accessible.name: "Accept"
      Accessible.onPressAction: root.accepted()
    }
  }
}
