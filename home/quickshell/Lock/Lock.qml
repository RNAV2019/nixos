import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.Commons
import qs.Services

Scope {
  id: root

  // password is the display - the dots the field's row draws - and submittedPassword is
  // the copy PAM is fed. The field wipes the frame Enter lands, long before the
  // conversation answers, so the two lives of one password are kept apart.
  property string password: ""
  property string submittedPassword: ""
  property string status: ""
  property bool statusIsError: false
  property bool busy: false
  // False until the first keystroke; the field itself is present from the first frame.
  property bool inputStarted: false
  property int attempts: 0
  property string snapshotPath: ""
  property string snapshotCleanupPath: ""
  property bool snapshotPending: false
  readonly property bool secure: lockContext.secure

  // quickshell forks its PAM worker without exec (quickshell-mirror/quickshell #964). The
  // child can inherit a mutex held by a thread that no longer exists in it and deadlock in
  // futex before PAM produces anything, freezing the screen with the input already disabled.
  //
  // The child is still killable, so the watchdog aborts the wedged conversation, forks a
  // fresh one and resubmits the held password. Three losses in a row give up visibly.
  property string pendingPassword: ""
  property int pamKicks: 0
  // quickshell answers one fault with error() and then completed(Error). The error handler
  // has already named it, so this stops a broken worker reading as a wrong password.
  property bool pamErrored: false

  LockReveal {
    id: reveal

    onRevealOutFinished: {
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
    snapshotDelay.stop();
    snapshotPending = false;
    Bus.prepareForLock();
    root.password = "";
    root.submittedPassword = "";
    root.status = "";
    root.statusIsError = false;
    root.busy = false;
    root.inputStarted = false;
    root.attempts = 0;
    reveal.reset();
    lockContext.locked = true;
    passwordPam.start();
    // Covers the boot lock too: a worker wedged before its prompt never asks for a password.
    root.pamKicks = 0;
    root.pendingPassword = "";
    root.pamErrored = false;
    pamWatchdog.restart();
  }

  function requestManualLock() {
    if (Bus.locking || lockContext.locked || snapshotCapture.running || snapshotPending)
      return;
    // Remove shell layers before the capture so the lock background never contains its own UI.
    Bus.prepareForLock();
    root.snapshotPath = Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-lock-snapshot.png";
    snapshotPending = true;
    snapshotDelay.restart();
  }

  // respond() is dropped unless PAM is already asking, and a freshly forked conversation
  // has not asked yet, so the password is held here and handed over by whichever is second.
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
    root.status = "";
    root.statusIsError = false;
    root.busy = false;
    // The bar comes back on the first frame of the fade, not after it.
    Bus.finishUnlock();
    reveal.animateOut();
  }

  function fail(reason) {
    // submit already wiped the dots, so a refusal just relabels the empty field.
    root.attempts += 1;
    root.statusIsError = true;
    root.status = reason + " (" + root.attempts + ")";
    failTimeout.restart();
  }

  function submit() {
    if (root.busy || root.password.length === 0)
      return;
    root.busy = true;
    root.inputStarted = true;
    root.status = "";
    root.statusIsError = false;
    root.submittedPassword = root.password;
    // The field wipes the frame Enter lands; the placeholder turns to Authenticating.
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
  }

  // Capture before the session-lock protocol takes the output. Boot locks bypass this.
  Timer {
    id: snapshotDelay

    interval: 80
    onTriggered: {
      root.snapshotPending = false;
      snapshotCapture.running = true;
    }
  }

  Process {
    id: snapshotCapture

    command: ["grimblast", "save", "screen", root.snapshotPath]

    onExited: function (exitCode) {
      if (exitCode !== 0)
        root.snapshotPath = "";
      root.lock();
    }
  }

  Process {
    id: snapshotCleanup

    command: ["rm", "-f", root.snapshotCleanupPath]
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

  Process {
    id: submapReset

    command: ["hyprctl", "dispatch", "hl.dsp.submap(\"reset\")"]
  }

  PamContext {
    id: passwordPam

    configDirectory: "/etc/pam.d"
    config: "quickshell-password"

    onPamMessage: {
      // The password may be typed before the prompt or after it; the prompt is the half
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
      // A worker that died or never came up is not a refused password; onError named it.
      if (!root.pamErrored)
        root.fail(result === PamResult.MaxTries ? "Too many attempts" : "Authentication failed");
      root.pamErrored = false;
      // Each failed attempt ends the PAM conversation.
      passwordPam.start();
    }

    onError: function (err) {
      pamWatchdog.stop();
      root.pendingPassword = "";
      root.busy = false;
      root.pamErrored = true;
      root.statusIsError = true;
      root.status = "Authentication unavailable";
      // Clear it like a refusal, so the field invites another try.
      failTimeout.restart();
    }
  }

  Timer {
    id: pamWatchdog

    interval: 4000

    onTriggered: {
      // A conversation sitting at its prompt with nothing submitted is waiting on the user,
      // not wedged. Killing the healthy one is what made a correct password look wrong.
      if (!root.busy && passwordPam.active && passwordPam.responseRequired)
        return;
      if (root.pamKicks >= 3) {
        // Three lost fork rolls. Kill the worker, surface the failure, leave the input alone.
        passwordPam.abort();
        root.pendingPassword = "";
        root.busy = false;
        root.statusIsError = true;
        root.status = "Authentication unavailable";
        return;
      }
      root.pamKicks += 1;
      passwordPam.abort();
      // Only a submitted password rides the replacement conversation, and it is held before
      // the fork, so a kick landing mid-typing cannot submit a half-typed field.
      root.pendingPassword = root.busy ? root.submittedPassword : "";
      passwordPam.start();
      restart();
    }
  }

  Timer {
    id: failTimeout

    interval: 2000
    onTriggered: {
      root.status = "";
      root.statusIsError = false;
    }
  }

  WlSessionLock {
    id: lockContext

    onSecureChanged: {
      if (secure) {
        markerWrite.running = true;
        submapReset.running = true;
      }
    }

    WlSessionLockSurface {
      id: surface

      // A transparent session-lock surface is composited as black during lock and unlock,
      // so an opaque base stays mounted for the whole secure-lock lifetime.
       color: Theme.canvas

      // One of these per screen, sharing the one reveal clock, so a second screen joins
      // the ramp already in progress rather than restarting it.
      Component.onCompleted: {
        if (!reveal.animatingIn && reveal.ground === 0 && reveal.clockAlpha === 0 && reveal.loginAlpha === 0)
          reveal.animateIn();
      }

      LockView {
        id: view

        anchors.fill: parent
        outputScreen: surface.screen
        backgroundSource: root.snapshotPath.length > 0 ? "file://" + root.snapshotPath : Wallpapers.url
        password: root.password
        status: root.status
        statusIsError: root.statusIsError
        busy: root.busy
        inputStarted: root.inputStarted
        ground: reveal.ground
        clockAlpha: reveal.clockAlpha
        loginAlpha: reveal.loginAlpha

        onPasswordEdited: function (text) {
          root.password = text;
          if (text.length > 0 && !root.inputStarted)
            root.inputStarted = true;
        }
        onAccepted: root.submit()
      }
    }
  }
}
