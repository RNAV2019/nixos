import QtQuick
import Quickshell
import qs.Commons
import qs.Services

// Raises the plugged-in moment when the charger goes in. Only a change seen while running
// counts: the state the shell finds at startup or on a reload is the baseline, and so is
// whatever settles in the first seconds, while UPower is still filling in the battery.
QtObject {
  id: root

  // For tests: -1 follows the real battery, 0 / 1 stand in for it (QUICKSHELL_FAKE_PLUGGED=1
  // starts the shell with the charger in).
  property int fake: Quickshell.env("QUICKSHELL_FAKE_PLUGGED") === "1" ? 1 : -1

  readonly property bool present: fake >= 0 || Battery.present
  readonly property bool plugged: fake >= 0 ? fake === 1 : Battery.plugged

  property var stand: null
  property bool armed: false
  property bool was: false

  onPresentChanged: {
    armed = false;
    settle.stop();
    if (present)
      arm.restart();
  }

  Component.onCompleted: if (present)
    arm.restart()

  // How long after the battery appears that its state is still being learnt.
  property Timer arm: Timer {
    interval: 2000
    onTriggered: {
      root.was = root.plugged;
      root.armed = true;
    }
  }

  onPluggedChanged: {
    if (!armed)
      return;
    if (plugged && !was)
      settle.restart();
    else if (!plugged)
      settle.stop();
    was = plugged;
  }

  // A contact that flickers is not a plug; it has to hold a moment.
  property Timer settle: Timer {
    interval: 400
    onTriggered: if (root.plugged)
      root.raise()
  }

  // The test hook: a plug as the logic above sees one, without the wait to be armed.
  function simulatePlug(percent, minutes) {
    stand = percent >= 0 ? {
      level: percent / 100,
      toFull: minutes * 60
    } : null;
    arm.stop();
    fake = 0;
    was = false;
    armed = true;
    fake = 1;
  }

  property Component body: Component {
    PluggedBody {}
  }

  // The moment itself; `stand` is a charge a test hook made up, else the battery is read live.
  function raise() {
    Activities.raiseMoment({
      kind: "plugged-in",
      key: "plugged-in",
      attention: false,
      width: Theme.momentCompactWidth,
      height: Theme.momentCompactHeight,
      radius: Theme.momentCompactRadius,
      dwell: Theme.momentPluggedDwell,
      data: root.stand,
      body: root.body
    });
  }
}
