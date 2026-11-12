import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.Commons
import qs.Services

Scope {
  id: root

  // password is the display (the dots), submittedPassword the copy fed to PAM: the
  // field wipes the frame Enter lands, long before the conversation answers.
  property string password: ""
  property string submittedPassword: ""
  property bool busy: false
  // Counts the tries PAM refused; each one shakes the pill and turns its padlock red.
  property int refusals: 0
  // Counts the tries PAM never judged (a dead or wedged worker): the padlock turns gold and
  // the pill stays still, so a right password is not told it was wrong.
  property int faults: 0
  // A prefix: each output is captured to <prefix>-<output>.png, so every lock surface shows
  // its own screen rather than the whole layout squeezed onto it.
  readonly property string snapshotFile: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-lock-snapshot"
  property string snapshotPath: ""
  property string snapshotCleanupPath: ""
  property bool snapshotPending: false
  readonly property bool secure: lockContext.secure

  // quickshell forks its PAM worker without exec (quickshell-mirror/quickshell #964), so
  // the child can inherit a dead thread's mutex and deadlock. The watchdog kills and reforks.
  property string pendingPassword: ""
  property int pamKicks: 0
  // quickshell sends error() then completed(Error); onError already named it, so this
  // stops a broken worker reading as a wrong password.
  property bool pamErrored: false

  LockReveal {
    id: reveal

    onRevealOutFinished: {
      // Only the lock that is letting go: a later one's capture is not this one's to delete.
      if (!lockContext.locked || !reveal.leaving)
        return;
      root.snapshotCleanupPath = root.snapshotPath;
      root.snapshotPath = "";
      lockContext.locked = false;
      if (root.snapshotCleanupPath.length > 0)
        snapshotCleanup.running = true;
    }
  }

  function lock() {
    if (lockContext.locked)
      return;
    // The boot lock can overtake a manual one still waiting on its capture; that snapshot
    // never lands, so this lock shows the wallpaper instead of a missing file.
    if (snapshotPending || snapshotCapture.running)
      root.snapshotPath = "";
    snapshotDelay.stop();
    settleCap.stop();
    snapshotPending = false;
    Bus.prepareForLock();
    root.password = "";
    root.submittedPassword = "";
    root.busy = false;
    root.refusals = 0;
    root.faults = 0;
    reveal.reset();
    lockContext.locked = true;
    passwordPam.start();
    // Covers the boot lock too: a worker wedged before its prompt never asks for a password.
    root.pamKicks = 0;
    root.pendingPassword = "";
    root.pamErrored = false;
    pamWatchdog.restart();
  }

  function captureSnapshot() {
    settleCap.stop();
    root.snapshotPending = false;
    snapshotCapture.running = true;
  }

  function requestManualLock() {
    if (Bus.locking || lockContext.locked || snapshotCapture.running || snapshotPending)
      return;
    // Close the shell's panels before the capture so the lock background never contains its
    // own UI. The bar stays: the lock's pill starts on the island in the capture.
    Bus.prepareForLock();
    root.snapshotPath = root.snapshotFile;
    snapshotPending = true;
    settleCap.restart();
    snapshotDelay.restart();
  }

  // respond() is dropped unless PAM is already asking, so the password is held here and
  // handed over by whichever of the two arrives second.
  function deliverPending() {
    if (root.pendingPassword.length === 0)
      return;
    if (!passwordPam.active || !passwordPam.responseRequired)
      return;
    passwordPam.respond(root.pendingPassword);
    root.pendingPassword = "";
  }

  function unlock() {
    pamWatchdog.stop();
    root.pendingPassword = "";
    passwordPam.abort();
    root.password = "";
    root.submittedPassword = "";
    root.busy = false;
    // The bar comes back on the first frame of the way out, not after it.
    Bus.finishUnlock();
    reveal.animateOut();
  }

  function fail() {
    // submit already wiped the dots, so a refusal only shakes the pill back to its glyph.
    root.refusals += 1;
  }

  function submit() {
    if (root.busy || root.password.length === 0)
      return;
    root.busy = true;
    root.submittedPassword = root.password;
    // The dots go the frame Enter lands; the pill closes to its checking lozenge.
    root.password = "";
    root.pamKicks = 0;
    root.pamErrored = false;
    root.pendingPassword = root.submittedPassword;
    pamWatchdog.restart();
    // A give-up abort or a silent start failure leaves no conversation to answer; fork one.
    if (!passwordPam.active)
      passwordPam.start();
    deliverPending();
  }

  Connections {
    target: Bus

    function onLockRequested() {
      root.requestManualLock();
    }

    function onLockHeldChanged() {
      if (!Bus.lockHeld && root.snapshotPending && settleCap.running)
        snapshotDelay.restart();
    }
  }

  // Capture before the session-lock protocol takes the output. Boot locks bypass this.
  Timer {
    id: snapshotDelay

    // Two frames at 60Hz is enough for the compositor to commit a panel-less output;
    // the layer has no_anim, so there is no fade to wait out.
    interval: 32
    onTriggered: {
      // Something is still coming to rest (Bus.lockHeld): its release starts these two frames
      // again, or settleCap gives up on it.
      if (Bus.lockHeld && settleCap.running)
        return;
      root.captureSnapshot();
    }
  }

  Timer {
    id: settleCap

    interval: Theme.lockSettleMax
    onTriggered: {
      if (root.snapshotPending && !snapshotDelay.running)
        root.captureSnapshot();
    }
  }

  Process {
    id: snapshotCapture

    // grim, not grimblast, and stored, not deflated: read once off tmpfs then deleted, so
    // compression is pure latency. Level 0 costs 30ms vs grimblast's 680ms.
    command: {
      var outputs = [];
      for (var i = 0; i < Quickshell.screens.length; i++)
        outputs.push(Quickshell.screens[i].name);
      return ["sh", "-c", "for o; do grim -l 0 -o \"$o\" \"$0-$o.png\" & done; for p in $(jobs -p); do wait \"$p\" || exit 1; done", root.snapshotPath].concat(outputs);
    }

    onExited: function (exitCode) {
      // Overtaken by the boot lock: the frame is not used, so it goes straight away.
      if (lockContext.locked) {
        root.snapshotCleanupPath = root.snapshotFile;
        snapshotCleanup.running = true;
        return;
      }
      if (exitCode !== 0)
        root.snapshotPath = "";
      root.lock();
    }
  }

  Process {
    id: snapshotCleanup

    command: ["sh", "-c", "rm -f \"$0\"-*.png", root.snapshotCleanupPath]
  }

  // Lock until this compositor instance completes its first secure lock.
  Process {
    id: markerCheck

    running: true
    command: ["sh", "-c", "test -e \"$XDG_RUNTIME_DIR/quickshell-secured-$HYPRLAND_INSTANCE_SIGNATURE\""]

    onExited: function (exitCode, exitStatus) {
      if (exitCode === 0) {
        Bus.finishUnlock();
        return;
      }
      root.lock();
    }
  }

  Process {
    id: markerWrite

    command: ["sh", "-c", ": > \"$XDG_RUNTIME_DIR/quickshell-secured-$HYPRLAND_INSTANCE_SIGNATURE\""]
  }

  PamContext {
    id: passwordPam

    configDirectory: "/etc/pam.d"
    config: "quickshell-password"

    onPamMessage: {
      // The password may be typed before or after the prompt; the prompt is the half
      // that arrives second often enough to matter.
      root.deliverPending();
    }

    onCompleted: function (result) {
      pamWatchdog.stop();
      root.pendingPassword = "";
      root.busy = false;
      if (result === PamResult.Success) {
        root.unlock();
        return;
      }
      // A worker that died or never came up has already shaken the pill in onError.
      if (!root.pamErrored)
        root.fail();
      root.pamErrored = false;
      // Each failed attempt ends the PAM conversation.
      passwordPam.start();
    }

    onError: function (err) {
      pamWatchdog.stop();
      root.pendingPassword = "";
      root.busy = false;
      root.pamErrored = true;
      // The lock has no words: the padlock says the check failed, and invites another try.
      root.faults += 1;
    }
  }

  Timer {
    id: pamWatchdog

    interval: 4000

    onTriggered: {
      // Sitting at a prompt with nothing submitted is waiting on the user, not wedged;
      // killing the healthy one made a correct password look wrong.
      if (!root.busy && passwordPam.active && passwordPam.responseRequired)
        return;
      if (root.pamKicks >= 3) {
        // Three lost fork rolls. Kill the worker, surface the failure, leave the input alone.
        passwordPam.abort();
        root.pendingPassword = "";
        root.busy = false;
        root.faults += 1;
        return;
      }
      root.pamKicks += 1;
      passwordPam.abort();
      // Only a submitted password rides the replacement conversation, held before the
      // fork, so a kick mid-typing cannot submit a half-typed field.
      root.pendingPassword = root.busy ? root.submittedPassword : "";
      passwordPam.start();
      restart();
    }
  }

  WlSessionLock {
    id: lockContext

    onSecureChanged: {
      if (secure)
        markerWrite.running = true;
    }

    WlSessionLockSurface {
      id: surface

      // A transparent session-lock surface composites as black, so an opaque base stays
      // mounted for the whole secure-lock lifetime.
      color: Theme.canvas

      // One per screen, sharing one reveal clock, so a second screen joins the ramp in
      // progress rather than restarting it.
      Component.onCompleted: {
        if (!reveal.animatingIn && reveal.ground === 0 && !reveal.away)
          reveal.arm();
      }

      LockView {
        id: view

        anchors.fill: parent
        outputScreen: surface.screen
        captured: root.snapshotPath.length > 0 && surface.screen !== null
        backgroundSource: captured ? "file://" + root.snapshotPath + "-" + surface.screen.name + ".png" : Wallpapers.url
        password: root.password
        busy: root.busy
        refusals: root.refusals
        faults: root.faults
        ground: reveal.ground
        flight: reveal.flight
        rise: reveal.rise
        away: reveal.widthAway
        leaving: reveal.leaving
        flying: reveal.flying
        snapping: reveal.snapping
        armed: reveal.armed

        onPresented: reveal.presented()
        onPasswordEdited: function (text) {
          root.password = text;
        }
        onAccepted: root.submit()
      }
    }
  }
}
