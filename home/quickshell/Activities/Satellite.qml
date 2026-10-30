import QtQuick
import QtQuick.Shapes
import qs.Commons
import qs.Ui

// One satellite: a pill-high circle beside the shut pill (Penpot "Ariadne / Satellite"). It
// draws whatever `look` (an Activity's, see Services/Activity.qml) says: a ring that is a
// track and an arc from 12 o'clock, and either a glyph or a short reading in the middle.
// Attention is a role-coloured ground with a halo that pulses outside the disc.
Item {
  id: root

  // The look to draw; the owner keeps the last one while the satellite fades out.
  property var look: null

  // Its card is up: the 1 px outline becomes an inner 1.5 px ring.
  property bool open: false

  readonly property bool hovered: hover.hovered

  readonly property real ring: look ? look.ring : -1
  readonly property bool hasRing: look !== null && (ring >= 0 || look.indeterminate)
  readonly property bool attention: look !== null && look.attention && !look.acknowledged
  readonly property bool filled: look !== null && look.filled

  readonly property real centre: Theme.satelliteSize / 2
  readonly property real ringRadius: centre - Theme.satelliteRingInset

  width: Theme.satelliteSize
  height: Theme.satelliteSize

  // The halo lives outside the disc, so nothing here clips.
  Rectangle {
    id: halo

    readonly property real size: Theme.satelliteSize + 2 * 4

    x: (root.width - size) / 2
    y: (root.height - size) / 2
    width: size
    height: size
    radius: size / 2
    color: "transparent"
    border.width: Theme.satelliteOpenRing
    border.color: root.look ? root.look.haloColor : Theme.accent
    visible: root.attention
    // Reduced motion shows the mid-pulse still frame instead of the loop.
    opacity: Theme.reduceMotion ? 0.4 : 0
    scale: Theme.reduceMotion ? 1.22 : 1
  }

  // Two pulses when it first needs the user, then one every twelve seconds until its card has
  // been opened: the halo scales 1 to 1.35 as it fades from 0.5, then rests.
  SequentialAnimation {
    id: pulse

    ParallelAnimation {
      NumberAnimation {
        target: halo
        property: "scale"
        from: 1
        to: 1.35
        duration: Theme.satellitePulse
        easing.type: Easing.OutCubic
      }

      NumberAnimation {
        target: halo
        property: "opacity"
        from: 0.5
        to: 0
        duration: Theme.satellitePulse
        easing.type: Easing.OutCubic
      }
    }

    PauseAnimation {
      duration: Theme.satellitePulseRest
    }
  }

  function pulseNow(times) {
    if (Theme.reduceMotion || !root.attention)
      return;
    pulse.loops = times;
    pulse.restart();
  }

  onAttentionChanged: {
    if (attention)
      pulseNow(2);
    else
      pulse.stop();
  }

  Component.onCompleted: if (attention)
    pulseNow(2)

  Timer {
    interval: Theme.satellitePulseEvery
    running: root.attention && !Theme.reduceMotion
    repeat: true
    onTriggered: if (!pulse.running)
      root.pulseNow(1)
  }

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: root.filled ? root.look.ground : hover.hovered ? Theme.surfaceRaised : Theme.surface
    border.width: root.open ? Theme.satelliteOpenRing : 1
    border.color: root.open ? Theme.withAlpha(Theme.inkPrimary, 0.9) : Theme.surfaceOutline

    Behavior on color {
      Tint {}
    }
  }

  // The ring: its track, then the arc. A depleting one is already the remaining fraction.
  Shape {
    id: ringShape

    anchors.fill: parent
    visible: root.hasRing
    preferredRendererType: Shape.CurveRenderer
    transformOrigin: Item.Center

    // A quarter arc turns once a second; a fraction holds still.
    RotationAnimator on rotation {
      from: 0
      to: 360
      duration: 1000
      loops: Animation.Infinite
      running: root.look !== null && root.look.indeterminate && root.visible && !Theme.reduceMotion
    }

    ShapePath {
      fillColor: "transparent"
      strokeColor: Theme.surfaceRaised
      strokeWidth: Theme.satelliteRingWidth
      capStyle: ShapePath.RoundCap

      PathAngleArc {
        centerX: root.centre
        centerY: root.centre
        radiusX: root.ringRadius
        radiusY: root.ringRadius
        startAngle: -90
        sweepAngle: 360
      }
    }

    ShapePath {
      fillColor: "transparent"
      strokeColor: root.look && (root.look.indeterminate || root.ring > 0.001) ? root.look.ringColor : "transparent"
      strokeWidth: Theme.satelliteRingWidth
      capStyle: ShapePath.RoundCap

      PathAngleArc {
        centerX: root.centre
        centerY: root.centre
        radiusX: root.ringRadius
        radiusY: root.ringRadius
        startAngle: -90
        sweepAngle: root.look ? (root.look.indeterminate ? 90 : Math.min(359.9, Theme.clamp01(root.ring) * 360)) : 0
      }
    }
  }

  // A reading replaces the glyph; with a caption the number rides above it.
  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    y: (root.look && root.look.caption !== "" ? 15.5 : root.centre) - height / 2
    visible: root.look !== null && root.look.text !== ""
    text: root.look ? root.look.text : ""
    color: root.look ? root.look.textColor : Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: root.look ? (root.look.caption !== "" ? 14 : root.look.textSize) : 10.5
    font.weight: Theme.weightSemi
    font.features: {
      "tnum": 1
    }
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    y: 25.5 - height / 2
    visible: root.look !== null && root.look.text !== "" && root.look.caption !== ""
    text: root.look ? root.look.caption : ""
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: Theme.satelliteCaptionSize
    font.weight: Theme.weightMedium
  }

  StrokeIcon {
    anchors.centerIn: parent
    visible: root.look !== null && root.look.text === "" && root.look.icon !== ""
    size: root.look ? root.look.iconSize : Theme.satelliteGlyphSize
    strokeWidth: 1.75
    path: root.look ? root.look.icon : ""
    color: root.look ? root.look.iconColor : Theme.inkPrimary
  }

  HoverHandler {
    id: hover

    cursorShape: Qt.PointingHandCursor
  }
}
