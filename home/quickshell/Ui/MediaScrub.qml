import QtQuick
import qs.Commons
import qs.Services

// The scrub bar of whatever is playing (Services/Media.qml), for the control centre's media card
// and the Now playing panel. MPRIS reports position about once a second, so the thumb runs on
// its own clock between reports and is pulled back only when a report disagrees; a drag previews
// the time and seeks once, on release. Hills ride the played part while music plays. The item's
// width is the track's; `trackY` and `timeY` place the track's centre line and the times in it.
// Whoever shows one holds Media.trackPosition true meanwhile.
Item {
  id: scrub

  property real trackY: 0
  property real timeY: 0
  // The far label counts down what is left, behind a minus, where it otherwise gives the length.
  property bool countsDown: false
  // "02:05", as One UI writes it; off, the minutes stand as they are ("2:05").
  property bool padded: true

  // How tall the time labels are, for an owner that places them by their middle.
  readonly property real timeHeight: elapsed.height
  readonly property bool focused: scrubArea.activeFocus

  readonly property real thumbR: Theme.controlMediaThumbSize / 2

  property real shown: 0
  property bool dragging: false
  property real dragFraction: 0

  readonly property real fraction: {
    if (dragging)
      return dragFraction;
    return Media.length > 0 ? Math.max(0, Math.min(1, shown / Media.length)) : 0;
  }

  readonly property real thumbX: thumbR + fraction * (width - thumbR * 2)

  // The hills rise when music plays and settle flat when it stops.
  property real swell: Media.playing && !Theme.reduceMotion ? 1 : 0
  property real phase: 0

  Behavior on swell {
    Morph {
      duration: Theme.duration(Theme.morphAmbient)
    }
  }

  // A step along the track from the keyboard: five seconds a press, like a player's own arrow keys.
  function nudge(seconds) {
    if (!Media.seekable)
      return;
    var to = Math.max(0, Math.min(Media.length, scrub.shown + seconds));
    Media.seek(to / Media.length);
    scrub.shown = to;
  }

  // An hour or more gains its own field.
  function clock(seconds) {
    var two = function (n) {
      return n < 10 ? "0" + n : "" + n;
    };
    if (!(seconds > 0))
      return scrub.padded ? "00:00" : "0:00";
    var s = Math.floor(seconds % 60), m = Math.floor(seconds / 60) % 60, h = Math.floor(seconds / 3600);
    return (h > 0 ? h + ":" : "") + (scrub.padded || h > 0 ? two(m) : m) + ":" + two(s);
  }

  Connections {
    target: Media

    function onPositionChanged() {
      if (!scrub.dragging && (Math.abs(Media.position - scrub.shown) > 0.75 || !Media.playing))
        scrub.shown = Media.position;
    }

    function onPlayerChanged() {
      scrub.shown = Media.position;
    }
  }

  Component.onCompleted: shown = Media.position

  FrameAnimation {
    // Media.trackPosition is held true only while a surface with a scrub bar is showing.
    running: Media.trackPosition && (Media.playing || scrub.swell > 0.001)
    onTriggered: {
      if (Media.playing && Media.length > 0)
        scrub.shown = Math.min(Media.length, scrub.shown + frameTime);
      if (!Theme.reduceMotion)
        scrub.phase += frameTime;
    }
  }

  // Three layers in darker shades of the accent, each two slow sine waves under an envelope
  // that rises from the start of the track and eases off into the thumb. Positions are taken
  // against the whole track, so the waves stay put as the played part grows, not stretching.
  // Drawn on the GPU (Shaders/hills.frag); the waves' frequencies and speeds live there.
  ShaderEffect {
    id: hills

    y: scrub.trackY - Theme.controlMediaHillHeight
    width: scrub.width
    height: Theme.controlMediaHillHeight
    visible: scrub.swell > 0.001 && scrub.thumbX >= 4

    property real phase: scrub.phase
    property size itemSize: Qt.size(width, height)
    property real amplitude: scrub.swell
    property real progress: scrub.thumbX / Math.max(1, scrub.width)
    property color ink0: shade(1.5, 0.85)
    property color ink1: shade(2, 0.8)
    property color ink2: shade(2.6, 0.75)

    // The accent darkened, with the layer's own opacity (Qt premultiplies it on the way to the shader).
    function shade(by, alpha) {
      var c = Qt.darker(Theme.accent, by);
      return Qt.rgba(c.r, c.g, c.b, alpha);
    }

    fragmentShader: Qt.resolvedUrl("../Shaders/hills.frag.qsb")
  }

  Rectangle {
    objectName: "track"
    y: scrub.trackY - height / 2
    width: scrub.width
    height: Theme.controlMediaTrackHeight
    radius: height / 2
    color: Theme.withAlpha(Theme.text, Theme.controlMediaTrackAlpha)

    Rectangle {
      objectName: "played"
      width: scrub.thumbX
      height: parent.height
      radius: height / 2
      color: Theme.accent
    }
  }

  Rectangle {
    objectName: "thumb"
    x: scrub.thumbX - width / 2
    y: scrub.trackY - height / 2
    width: Theme.controlMediaThumbSize
    height: width
    radius: width / 2
    visible: Media.length > 0
    // A shade under the played track, so the thumb still reads against it without a ring.
    color: Qt.darker(Theme.accent, Theme.controlMediaThumbShade)
    border.width: scrubArea.activeFocus ? Theme.controlMediaThumbRing : 0
    border.color: Theme.focusRing
    scale: thumbScale.value

    MorphSpring {
      id: thumbScale

      target: scrub.dragging ? Theme.controlMediaThumbPressScale : 1
      omega: Theme.microOmega
      epsilon: 0.001
      label: "media.thumb"
    }
  }

  Text {
    id: elapsed

    objectName: "elapsed"
    y: scrub.timeY
    text: scrub.clock(scrub.fraction * Media.length)
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlMediaCaptionSize
    font.features: {
      "tnum": 1
    }
  }

  Text {
    objectName: "length"
    x: scrub.width - width
    y: scrub.timeY
    // A true minus, the width of a digit, not a hyphen.
    text: scrub.countsDown ? "−" + scrub.clock(Math.max(0, (1 - scrub.fraction) * Media.length)) : scrub.clock(Media.length)
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlMediaCaptionSize
    font.features: {
      "tnum": 1
    }
  }

  // Taller than the drawn track, so the thumb is easy to catch.
  MouseArea {
    id: scrubArea

    x: -scrub.thumbR
    y: scrub.trackY - 14
    width: scrub.width + scrub.thumbR * 2
    height: 28
    enabled: Media.seekable
    cursorShape: Qt.PointingHandCursor
    preventStealing: true

    activeFocusOnTab: Media.seekable
    Accessible.role: Accessible.Slider
    Accessible.name: "Seek"
    Accessible.description: scrub.clock(scrub.fraction * Media.length) + " of " + scrub.clock(Media.length)

    function fractionAt(px) {
      var local = px + x - scrub.thumbR;
      return Math.max(0, Math.min(1, local / Math.max(1, scrub.width - scrub.thumbR * 2)));
    }

    onPressed: function (mouse) {
      forceActiveFocus();
      scrub.dragFraction = fractionAt(mouse.x);
      scrub.dragging = true;
    }

    onPositionChanged: function (mouse) {
      if (pressed)
        scrub.dragFraction = fractionAt(mouse.x);
    }

    onReleased: {
      Media.seek(scrub.dragFraction);
      scrub.shown = scrub.dragFraction * Media.length;
      scrub.dragging = false;
    }

    onCanceled: scrub.dragging = false

    Keys.onPressed: function (event) {
      if (Media.length <= 0 || (event.key !== Qt.Key_Left && event.key !== Qt.Key_Right))
        return;
      scrub.nudge(event.key === Qt.Key_Right ? 5 : -5);
      event.accepted = true;
    }
  }
}
