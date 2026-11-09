import QtQuick
import qs.Commons
import "Motion.js" as Motion

// A body taller than its card. The wheel does not move the content, it moves where the content is
// going: every notch adds wheelStep to that, so a spun wheel loses nothing, and the content follows
// on a spring (Theme.scrollOmega) that a new notch retargets without a restart. A touchpad's
// fingers move it one to one, and a throw coasts on.
//
// Past either end the content gives (Motion.rubberBand) and comes back when the hand stops; it is
// never left out of place. The give is a shift of the body, so `contentY` stays inside the ends.
//
// The thumb sits in a gutter outside the rows (Theme.scrollThumbGap past the right edge, so leave
// that much inset), comes up while the content moves or the pointer is over it, and goes a moment
// after.
Item {
  id: root

  default property alias content: body.data

  // Disable only the Flickable; disabling this Item would kill nested input.
  property bool scrollable: true

  // How far one wheel notch moves the content.
  property real wheelStep: Theme.panelRowHeight * 3

  // Names the scroll spring in the motion log (`scroll.<name>`, see Ui/MorphSpring.qml); empty
  // keeps it out.
  property string name: ""

  readonly property alias contentHeight: body.implicitHeight
  readonly property alias contentY: view.contentY
  readonly property alias scrolling: view.interactive

  // The furthest the content scrolls.
  readonly property real limit: Math.max(0, view.contentHeight - view.height)

  // Where the content is going, inside the ends, and how far the hand has pushed past one.
  property real aim: 0
  property real over: 0
  // How far past an end the content is drawn.
  property real give: 0
  // Fingers on a touchpad are moving it, and how fast (for the throw).
  property bool touching: false
  property real travelled: 0
  readonly property var speed: Motion.tracker()

  function clampY(y) {
    return Math.max(0, Math.min(root.limit, y));
  }

  function scrollToTop() {
    root.rest(0);
  }

  // Stops where it is told to, with no give left.
  function rest(y) {
    idle.stop();
    glide.following = false;
    root.touching = false;
    root.over = 0;
    root.give = 0;
    view.contentY = root.clampY(y);
  }

  // The spring's value is where the hand has the content, ends ignored; what is past an end is
  // drawn as give.
  function show(v) {
    var y = root.clampY(v);
    root.give = Motion.rubberBand(v - y, view.height);
    if (view.contentY !== y)
      view.contentY = y;
  }

  // Puts the spring on a value, at rest.
  function seat(v) {
    glide.animate = false;
    glide.target = v;
    glide.value = v;
    glide.velocity = 0;
    glide.animate = true;
  }

  // `dy` more px of scroll, from a wheel notch or (direct) from fingers.
  function feed(dy, direct) {
    if (!glide.following) {
      // Start from where the content is.
      root.aim = view.contentY;
      root.over = 0;
      root.seat(view.contentY);
      glide.following = true;
    } else if (direct && !root.touching) {
      // Fingers land on content that is still travelling: they take it where it is.
      root.aim = root.clampY(glide.value);
      root.over = glide.value - root.aim;
    }
    if (direct && !root.touching) {
      root.travelled = 0;
      root.speed.reset();
    }
    root.touching = direct;

    var raw = root.aim + root.over + dy;
    var y = root.clampY(raw);
    var past = raw - y;
    if (Theme.reduceMotion)
      past = 0;
    else if (!direct && Math.abs(past) > Math.abs(root.over))
      past = root.over + (past - root.over) * Theme.scrollWheelGive;
    root.aim = y;
    root.over = past;

    if (direct) {
      root.travelled += dy;
      root.speed.push(Date.now(), root.travelled);
      root.seat(y + past);
    } else {
      glide.omega = Theme.scrollOmega;
      glide.target = y + past;
    }
    // Motion off, or nowhere to go: the spring is not running, so nothing else would draw it.
    if (!glide.running)
      root.show(y + past);
    idle.restart();
  }

  // The hand has stopped: what was pushed past an end comes back, and a throw coasts.
  function letGo() {
    idle.stop();
    if (!glide.following)
      return;
    var v = root.touching ? root.speed.velocity(Date.now()) : 0;
    var thrown = v !== 0 && root.over === 0 && !Theme.reduceMotion;
    root.touching = false;
    root.over = 0;
    if (thrown)
      root.aim = root.clampY(root.aim + Motion.project(v, Theme.scrollCoastRate));
    // On a whole pixel, so the content is crisp where it stops.
    root.aim = root.clampY(Math.round(root.aim));
    glide.omega = thrown ? 2000 * (1 - Theme.scrollCoastRate) / Theme.scrollCoastRate : Theme.scrollOmega;
    glide.target = root.aim;
    if (thrown && glide.value !== glide.target)
      glide.kick(v);
    if (!glide.running)
      root.rest(root.aim);
  }

  // The content shrank under a scrolled view (a row removed): stay inside it.
  onLimitChanged: {
    if (glide.following) {
      root.aim = root.clampY(root.aim);
      if (!root.touching)
        glide.target = root.aim + root.over;
    } else if (view.contentY > root.limit) {
      view.contentY = root.limit;
    }
  }

  MorphSpring {
    id: glide

    // The spring owns the content from the first notch until it has landed and the hand is still.
    property bool following: false

    damping: 1
    omega: Theme.scrollOmega
    label: root.name !== "" ? "scroll." + root.name : ""
    onValueChanged: {
      if (following)
        root.show(value);
    }
    onRunningChanged: {
      if (!running && following && !idle.running)
        root.rest(root.aim);
    }
  }

  Timer {
    id: idle

    interval: Theme.scrollIdle
    onTriggered: root.letGo()
  }

  HoverHandler {
    id: hover
  }

  Flickable {
    id: view

    anchors.fill: parent
    contentWidth: width
    contentHeight: body.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    interactive: root.scrollable && contentHeight > height

    // A drag on the content itself is the Flickable's own; the spring lets go of it.
    onDraggingChanged: {
      if (dragging && glide.following)
        root.rest(view.contentY);
    }

    // Qt's own wheel handling steps too little and stops dead at the ends.
    WheelHandler {
      enabled: view.interactive
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: function (event) {
        // Fingers are told from a wheel by the phase: only a touchpad's scroll has one. Both
        // report pixels here (a notch comes as 15 px beside its 120), so the pixels alone say
        // nothing. A wheel counts in notches, fractions of one on a high-resolution wheel.
        var direct = event.phase !== Qt.NoScrollPhase && event.pixelDelta.y !== 0;
        if (direct)
          root.feed(-event.pixelDelta.y, true);
        else if (event.angleDelta.y !== 0)
          root.feed(-(event.angleDelta.y / 120) * root.wheelStep, false);
        // The fingers lifting ends the gesture at once; where that is not reported, the idle
        // timer does it.
        if (event.phase === Qt.ScrollEnd)
          root.letGo();
      }
    }

    Item {
      id: body

      width: view.width
      implicitHeight: childrenRect.height
      // Avoids a circular height dependency.
      height: root.scrollable ? implicitHeight : view.height

      transform: Translate {
        y: -root.give
      }
    }
  }

  Rectangle {
    id: thumb

    // Moving, or the pointer over the list; the linger keeps it a moment after either ends.
    readonly property bool active: glide.following || view.moving || hover.hovered
    readonly property bool wanted: view.interactive && (active || linger.running)
    // Its length, and how much of that the give has squeezed out of it against the end.
    readonly property real length: Math.max(20, view.visibleArea.heightRatio * root.height)
    readonly property real squeeze: Math.min(length - 8, Math.abs(root.give))

    onActiveChanged: {
      if (!active)
        linger.restart();
    }

    x: root.width + Theme.scrollThumbGap
    width: Theme.scrollThumbWidth
    radius: width / 2
    color: Theme.withAlpha(Theme.text, Theme.fillSelected)
    opacity: wanted ? 1 : 0
    visible: opacity > 0
    // Bound straight to the view, so the thumb is where the content is on every frame.
    y: view.visibleArea.yPosition * root.height + (root.give > 0 ? squeeze : 0)
    height: length - squeeze

    // Up quickly, away slowly.
    Behavior on opacity {
      Morph {
        duration: thumb.wanted ? Theme.morphState : Theme.tintFade
      }
    }

    Timer {
      id: linger

      interval: Theme.scrollThumbLinger
    }
  }
}
