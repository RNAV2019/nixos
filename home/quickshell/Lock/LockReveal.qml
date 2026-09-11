import QtQuick
import qs.Commons

// The lock's one reveal clock, held apart from the surfaces that read it.
Item {
  id: reveal

  property real ground: 0
  property real clockAlpha: 0
  property real loginAlpha: 0

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
