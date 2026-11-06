import QtQuick
import qs.Commons

// The lock's one reveal clock, held apart from the surfaces that read it.
//
// The date, the time and the password field each have an alpha and a slide: the slide is 1 with
// the element at rest and 0 with it a lockSlideTravel away, so LockView puts it at
// (1 - slide) * travel. It rides the same delay and duration as the alpha. In, both ease out (the
// element decelerates into place); out, the slide eases in (it accelerates away) while the alpha
// fades as before. The time follows the date by lockStagger on the way in and leads it on the
// way out.
Item {
  id: reveal

  property real ground: 0
  property real dateAlpha: 0
  property real timeAlpha: 0
  property real loginAlpha: 0
  property real dateSlide: 0
  property real timeSlide: 0
  property real loginSlide: 0

  readonly property bool animatingIn: inAnim.running

  // Raised once the foreground out-ramp has cleared; the opaque base holds until then.
  signal revealOutFinished

  function animateIn() {
    outAnim.stop();
    ground = 0;
    inAnim.restart();
  }

  function animateOut() {
    inAnim.stop();
    outAnim.restart();
  }

  function reset() {
    inAnim.stop();
    outAnim.stop();
    // Stay opaque while the lock is secured, so the compositor never shows a black frame.
    ground = 0;
    dateAlpha = 0;
    timeAlpha = 0;
    loginAlpha = 0;
    dateSlide = 0;
    timeSlide = 0;
    loginSlide = 0;
  }

  // The slide's signed offset from rest in the motion log (y grows down: date and time start above, the field below), in reference px (QS_MOTION_LOG=1; check.mjs reads it).
  property var logLast: ({})

  function logSlide(label, slide, target, sign) {
    if (!Theme.motionLog || !(inAnim.running || outAnim.running))
      return;
    const now = Date.now();
    const prev = logLast[label];
    const v = sign * (1 - slide) * Theme.lockSlideTravel;
    const vel = prev && now > prev.t ? (v - prev.v) / ((now - prev.t) / 1000) : 0;
    logLast[label] = {
      "t": now,
      "v": v
    };
    console.info("motion " + label + " " + now + " " + v.toFixed(4) + " " + vel.toFixed(4) + " " + (sign * (1 - target) * Theme.lockSlideTravel).toFixed(4));
  }

  onDateSlideChanged: logSlide("lock.date.y", dateSlide, inAnim.running ? 1 : 0, -1)
  onTimeSlideChanged: logSlide("lock.time.y", timeSlide, inAnim.running ? 1 : 0, -1)
  onLoginSlideChanged: logSlide("lock.field.y", loginSlide, inAnim.running ? 1 : 0, 1)

  // One element's reveal: wait `delay`, then ease the alpha and the slide to `to`.
  component Lift: SequentialAnimation {
    id: lift

    property string alpha
    property string slide
    property int delay: 0
    property int length: Theme.duration(Theme.lockInContent)
    property real to: 1
    // Out, the slide accelerates; in, it decelerates into place.
    property int slideEasing: Easing.OutCubic

    PauseAnimation {
      duration: lift.delay
    }

    ParallelAnimation {
      NumberAnimation {
        target: reveal
        property: lift.alpha
        to: lift.to
        duration: lift.length
        easing.type: Easing.OutCubic
      }

      NumberAnimation {
        target: reveal
        property: lift.slide
        to: lift.to
        duration: lift.length
        easing.type: lift.slideEasing
      }
    }
  }

  ParallelAnimation {
    id: inAnim

    NumberAnimation {
      target: reveal
      property: "ground"
      to: 1
      duration: Theme.duration(Theme.lockIn)
      easing.type: Easing.OutQuad
    }

    Lift {
      alpha: "dateAlpha"
      slide: "dateSlide"
      delay: Theme.duration(Theme.lockInClock)
    }

    Lift {
      alpha: "timeAlpha"
      slide: "timeSlide"
      delay: Theme.duration(Theme.lockInClock) + Theme.duration(Theme.lockStagger)
    }

    Lift {
      alpha: "loginAlpha"
      slide: "loginSlide"
      delay: Theme.duration(Theme.lockInLogin)
    }
  }

  SequentialAnimation {
    id: outAnim

    ParallelAnimation {
      NumberAnimation {
        target: reveal
        property: "ground"
        to: 0
        duration: Theme.duration(Theme.lockOut)
        easing.type: Easing.OutCubic
      }

      Lift {
        alpha: "loginAlpha"
        slide: "loginSlide"
        to: 0
        length: Theme.duration(Theme.lockOutContent)
        slideEasing: Easing.InCubic
      }

      // The time leads on the way out, the date follows.
      Lift {
        alpha: "timeAlpha"
        slide: "timeSlide"
        to: 0
        delay: Theme.duration(Theme.lockOutClock)
        length: Theme.duration(Theme.lockOutContent)
        slideEasing: Easing.InCubic
      }

      Lift {
        alpha: "dateAlpha"
        slide: "dateSlide"
        to: 0
        delay: Theme.duration(Theme.lockOutClock) + Theme.duration(Theme.lockStagger)
        length: Theme.duration(Theme.lockOutContent)
        slideEasing: Easing.InCubic
      }
    }

    PauseAnimation {
      duration: Theme.duration(Theme.morphBeat)
    }

    ScriptAction {
      script: reveal.revealOutFinished()
    }
  }
}
