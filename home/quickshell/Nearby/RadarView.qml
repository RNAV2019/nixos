import QtQuick
import qs.Commons
import qs.Services
import qs.Ui

// The receive body's head (boards 16g, 16h): rings rippling out of a filled laptop core, the
// name other devices see, and the chips - the visibility countdown (click to switch receiving
// off or back on) and, in Apple mode, the gold note that Wi-Fi is down for the radio.
//
// While receivable, three rings ride one clock a third of a loop apart: each leaves the core,
// decelerates as it widens, and fades as it passes the outer ring, so at any instant the three
// sit roughly where the board draws them. Not receivable, they settle on the board's static
// rings, dimmed.
Item {
  id: root

  property string deviceName: ""
  property string remainingLabel: ""
  property bool receivable: false
  property bool wifiPaused: false

  signal timerClicked

  implicitWidth: Theme.nearbyWidth
  implicitHeight: Theme.nearbyRadarOuter + Theme.nearbyRadarNameGap + 17 + Theme.nearbyChipGap + Theme.nearbyChipHeight

  // 0..1, looping; each ring reads it at its own offset.
  property real phase: 0

  NumberAnimation on phase {
    from: 0
    to: 1
    duration: Theme.nearbyRadarLoop
    loops: Animation.Infinite
    running: root.receivable && root.visible && !Theme.reduceMotion
  }

  // How far the ripple has taken over from the static rings; eases both ways so switching
  // receiving on or off never pops.
  property real live: receivable && !Theme.reduceMotion ? 1 : 0

  Behavior on live {
    NumberAnimation {
      duration: Theme.duration(Theme.morphAmbient)
      easing.type: Easing.InOutQuad
    }
  }

  // The board's alphas by diameter - inner rings stronger, outer fainter - extended to fade in
  // just off the core and out just past the outer ring.
  function strokeAt(d) {
    var stops = [[Theme.nearbyRadarCore, 0], [Theme.nearbyRadarCore + 14, 0.32], [Theme.nearbyRadarInner, 0.28], [Theme.nearbyRadarMid, 0.14], [Theme.nearbyRadarOuter, 0.07], [Theme.nearbyRadarOuter + 18, 0]];
    if (d <= stops[0][0])
      return 0;
    for (var i = 1; i < stops.length; i++) {
      if (d <= stops[i][0]) {
        var a = stops[i - 1], b = stops[i];
        return a[1] + (b[1] - a[1]) * (d - a[0]) / (b[0] - a[0]);
      }
    }
    return 0;
  }

  // The fill tracks the stroke at the board's ratio (0.1 : 0.28 inner, 0.02 : 0.07 outer).
  function fillAt(d) {
    return strokeAt(d) * 0.34;
  }

  component Ring: Rectangle {
    id: ring

    // The board's own diameter for this ring, held while not receiving.
    property real rest: Theme.nearbyRadarOuter
    property real offset: 0

    readonly property real t: (root.phase + offset) % 1
    // Out-quad: quick off the core, slowing as it widens.
    readonly property real eased: 1 - (1 - t) * (1 - t)
    readonly property real travelling: Theme.nearbyRadarCore + (Theme.nearbyRadarOuter + 18 - Theme.nearbyRadarCore) * eased
    readonly property real diameter: rest + (travelling - rest) * root.live

    anchors.centerIn: parent
    width: diameter
    height: diameter
    radius: diameter / 2
    color: Theme.withAlpha(Theme.accentFill, root.fillAt(diameter) * (root.receivable ? 1 : 0.5))
    border.width: 1
    border.color: Theme.withAlpha(Theme.accentFill, root.strokeAt(diameter) * (root.receivable ? 1 : 0.5))
  }

  Item {
    id: rings

    x: (root.width - Theme.nearbyRadarOuter) / 2
    y: 0
    width: Theme.nearbyRadarOuter
    height: Theme.nearbyRadarOuter

    Ring {
      rest: Theme.nearbyRadarOuter
      offset: 2 / 3
    }

    Ring {
      rest: Theme.nearbyRadarMid
      offset: 1 / 3
    }

    Ring {
      rest: Theme.nearbyRadarInner
      offset: 0
    }

    Rectangle {
      anchors.centerIn: parent
      width: Theme.nearbyRadarCore
      height: Theme.nearbyRadarCore
      radius: width / 2
      color: root.receivable ? Theme.accentFill : Theme.withAlpha(Theme.accentFill, 0.35)

      Behavior on color {
        Tint {}
      }

      StrokeIcon {
        anchors.centerIn: parent
        size: Theme.nearbyRadarGlyph
        strokeWidth: 1.8
        path: IconPaths.laptop
        color: Theme.inkOnAccent
      }
    }
  }

  Text {
    x: 0
    y: Theme.nearbyRadarOuter + Theme.nearbyRadarNameGap
    width: root.width
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
    text: root.deviceName
    color: Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: Theme.nearbyNameSize
    font.weight: Theme.weightSemi
  }

  Row {
    x: (root.width - width) / 2
    y: Theme.nearbyRadarOuter + Theme.nearbyRadarNameGap + 17 + Theme.nearbyChipGap
    height: Theme.nearbyChipHeight
    spacing: Theme.nearbyChipPairGap

    // The countdown while a window runs, "Visible" while receiving has no end, "Off" when it
    // is switched off; clicking toggles receiving.
    Rectangle {
      width: timerRow.implicitWidth + 24
      height: Theme.nearbyChipHeight
      radius: Theme.nearbyChipRadius
      color: root.receivable ? Theme.withAlpha(Theme.accentFill, 0.12) : "transparent"
      border.width: root.receivable ? 0 : 1
      border.color: Theme.withAlpha(Theme.separator, 0.7)
      scale: timerArea.pressed ? Theme.pressScale : 1

      Behavior on scale {
        Morph {
          duration: Theme.morphState
        }
      }

      Behavior on color {
        Tint {}
      }

      Row {
        id: timerRow

        anchors.centerIn: parent
        spacing: Theme.nearbyChipInnerGap

        StrokeIcon {
          anchors.verticalCenter: parent.verticalCenter
          size: Theme.nearbyChipGlyph
          strokeWidth: 1.8
          path: IconPaths.timer
          color: root.receivable ? Theme.accentFill : Theme.inkTertiary
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.receivable ? (root.remainingLabel !== "" ? root.remainingLabel : "Visible") : "Off"
          color: root.receivable ? Theme.accentFill : Theme.inkTertiary
          font.family: Theme.uiFont
          font.pixelSize: Theme.nearbyChipSize
          font.weight: Theme.weightSemi
          font.features: {
            "tnum": 1
          }
        }
      }

      MouseArea {
        id: timerArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.timerClicked()
      }

      Accessible.role: Accessible.Button
      Accessible.name: root.receivable ? "Stop receiving" : "Start receiving"
      Accessible.onPressAction: root.timerClicked()
    }

    // Apple's exclusive radio: Wi-Fi is down while the window or a send runs.
    Rectangle {
      visible: root.wifiPaused
      width: wifiRow.implicitWidth + 24
      height: Theme.nearbyChipHeight
      radius: Theme.nearbyChipRadius
      color: Theme.withAlpha(Theme.gold, 0.12)

      Row {
        id: wifiRow

        anchors.centerIn: parent
        spacing: Theme.nearbyChipInnerGap

        StrokeIcon {
          anchors.verticalCenter: parent.verticalCenter
          size: Theme.nearbyChipGlyph
          strokeWidth: 1.8
          path: IconPaths.wifiOff
          color: Theme.gold
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "Wi-Fi paused"
          color: Theme.gold
          font.family: Theme.uiFont
          font.pixelSize: Theme.nearbyChipSize
          font.weight: Theme.weightSemi
        }
      }
    }
  }
}
