import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import qs.Commons

// Face unlock: Howdy and the IR camera, as a second PAM conversation beside the password's.
// It can only ever add a way in. Every way it can fail ends in "idle", the password field
// is never touched, and nothing is shown unless the camera actually looked and missed.
//
// state: "idle"       nothing running (no model enrolled, cancelled, or something broke)
//        "scanning"   the camera is looking
//        "recognised" PAM said yes; `succeeded` follows after the hold
//        "missed"     the camera looked and did not know the face
Scope {
  id: root

  // Set by the lock: the face may only be tried while the session is locked.
  property bool locked: false
  property string state: "idle"

  // Where the face model lives; Howdy's PAM module looks for the same file and stays out
  // of the conversation when it is absent, but the pill must not draw a ring for nothing.
  readonly property string model: "/var/lib/howdy/models/" + Quickshell.env("USER") + ".dat"
  readonly property string pamDirectory: "/etc/pam.d"
  readonly property string pamService: "quickshell-face"

  property int misses: 0
  property double startedAt: 0

  signal succeeded

  // A new lock, or a wake from suspend: forget the misses and look again.
  function begin() {
    root.misses = 0;
    root.state = "idle";
    root.attempt();
  }

  // The user asks again (Esc on an empty field). The cap holds until the next lock or wake.
  function retry() {
    if (root.state === "scanning" || root.state === "recognised")
      return;
    root.attempt();
  }

  function attempt() {
    root.halt();
    if (!root.locked || root.misses >= Theme.lockFaceMaxMisses)
      return;
    // No model, no attempt: stay idle and say nothing.
    modelCheck.running = true;
  }

  // The first keystroke, or an unlock: stop looking without a word.
  function cancel() {
    // PAM has already said yes; a key struck in the hold must not take it back.
    if (root.state === "recognised")
      return;
    root.halt();
    root.state = "idle";
  }

  // A fresh lock, or the unlock itself.
  function reset() {
    root.halt();
    root.state = "idle";
  }

  function halt() {
    modelCheck.running = false;
    hardTimeout.stop();
    holdTimer.stop();
    noticeTimer.stop();
    if (facePam.active)
      facePam.abort();
  }

  function giveUp() {
    // Anything but a refusal after a real look: no camera, no service, a hung worker.
    root.halt();
    root.state = "idle";
  }

  Process {
    id: modelCheck

    // The model and the service file both: with either missing there is nothing to look with.
    command: ["sh", "-c", "test -e \"$0\" && test -e \"$1\"", root.model, root.pamDirectory + "/" + root.pamService]

    onExited: function (exitCode) {
      if (exitCode !== 0 || !root.locked)
        return;
      root.startedAt = Date.now();
      root.state = "scanning";
      hardTimeout.restart();
      facePam.start();
    }
  }

  PamContext {
    id: facePam

    configDirectory: root.pamDirectory
    config: root.pamService

    // The face service never asks a question; if a misconfigured one does, nobody answers
    // and the hard timeout ends it.
    onCompleted: function (result) {
      hardTimeout.stop();
      if (root.state !== "scanning")
        return;
      if (result === PamResult.Success) {
        root.state = "recognised";
        holdTimer.restart();
        return;
      }
      // An attempt that ended almost at once never looked: the lid is shut, the camera is
      // missing or busy. That is not a miss, so no notice and no count.
      if (Date.now() - root.startedAt < Theme.lockFaceMinLookMs) {
        root.giveUp();
        return;
      }
      root.misses += 1;
      root.state = "missed";
      noticeTimer.restart();
    }

    // A worker that cannot start: no such service, no PAM at all.
    onError: function (err) {
      if (root.state === "scanning")
        root.giveUp();
    }
  }

  // Howdy's own timeout is shorter; this only catches a conversation that never ends.
  Timer {
    id: hardTimeout

    interval: Theme.lockFaceHardTimeoutMs
    onTriggered: root.giveUp()
  }

  // The pill shows "Recognised" a beat before the reveal-out starts.
  Timer {
    id: holdTimer

    interval: Theme.lockFaceHold
    onTriggered: {
      if (root.locked && root.state === "recognised")
        root.succeeded();
    }
  }

  // "Not recognised" reverts to the plain placeholder on its own.
  Timer {
    id: noticeTimer

    interval: Theme.lockFaceNoticeMs
    onTriggered: {
      if (root.state === "missed")
        root.state = "idle";
    }
  }
}
