import QtQuick
import qs.Commons

// The lock's one reveal clock, held apart from the surfaces that read it.
//
// The wallpaper stays mounted while its blur and the foreground content animate
// together. The real session lock and the IPC preview share these same ramps.
//
// Neither direction is a morph: the digits never move or change size, so the
// spring stays out of this and each tier rides its own easing.
Item {
  id: reveal

  property real ground: 0
  property real clockAlpha: 0
  property real loginAlpha: 0

  readonly property bool animatingIn: inAnim.running

  // Raised when the foreground out-ramp has fully cleared. The opaque base
  // stays visible until this lands and the session lock is released.
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
    // Start from the sharp current wallpaper. The surface remains opaque while
    // the lock is secured, so the compositor never exposes a black frame.
    ground = 0;
    clockAlpha = 0;
    loginAlpha = 0;
  }

  ParallelAnimation {
    id: inAnim

    NumberAnimation {
      target: reveal
      property: "ground"
      to: 1
      duration: Theme.lockIn
      easing.type: Easing.OutQuad
    }

    SequentialAnimation {
      PauseAnimation {
        duration: Theme.lockInClock
      }
      NumberAnimation {
        target: reveal
        property: "clockAlpha"
        to: 1
        duration: Theme.lockInContent
        easing.type: Easing.OutCubic
      }
    }

    SequentialAnimation {
      PauseAnimation {
        duration: Theme.lockInLogin
      }
      NumberAnimation {
        target: reveal
        property: "loginAlpha"
        to: 1
        duration: Theme.lockInContent
        easing.type: Easing.OutCubic
      }
    }
  }

  SequentialAnimation {
    id: outAnim

    ParallelAnimation {
      NumberAnimation {
        target: reveal
        property: "ground"
        to: 0
        duration: Theme.lockOut
        easing.type: Easing.OutCubic
      }

      NumberAnimation {
        target: reveal
        property: "loginAlpha"
        to: 0
        duration: Theme.lockOutContent
        easing.type: Easing.OutCubic
      }

      SequentialAnimation {
        PauseAnimation {
          duration: Theme.lockOutClock
        }
        NumberAnimation {
          target: reveal
          property: "clockAlpha"
          to: 0
          duration: Theme.lockOutContent
          easing.type: Easing.OutCubic
        }
      }
    }

    PauseAnimation {
      duration: 50
    }

    ScriptAction {
      script: reveal.revealOutFinished()
    }
  }
}
