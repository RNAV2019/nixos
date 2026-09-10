import QtQuick
import qs.Commons

// The lock's one reveal clock, held apart from the surfaces that read it.
//
// One progress value drives the whole cross-fade - the ground, the clock
// block and the login cluster - so the real session lock and the IPC preview
// run the same ramps from the same definition and a rehearsal can only ever
// look like the thing it rehearses.
//
// Neither direction is a morph: stepping the recording's clock block frame by
// frame, the digits never move and never change size, so the spring stays out
// of this and each tier rides its own easing.
Item {
  id: reveal

  property real ground: 0
  property real clockAlpha: 0
  property real loginAlpha: 0

  readonly property bool animatingIn: inAnim.running

  // Raised when the out-ramp has fully cleared, hold included. The session
  // stays locked until this lands, so the last fade frame is presented
  // before the surface goes away.
  signal revealOutFinished

  function animateIn() {
    outAnim.stop();
    inAnim.restart();
  }

  function animateOut() {
    inAnim.stop();
    outAnim.restart();
  }

  function reset() {
    inAnim.stop();
    outAnim.stop();
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