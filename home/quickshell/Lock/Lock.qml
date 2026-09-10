import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.Commons
import qs.Services

Scope {
  id: root

  // password is the display - the dots the field's row draws - and
  // submittedPassword is the copy the PAM conversation is actually fed. The
  // recording wipes the field the frame Enter lands, long before the
  // conversation answers, so the two lives of one password are kept apart.
  property string password: ""
  property string submittedPassword: ""
  property string status: ""
  property bool statusIsError: false
  property bool busy: false
  // False until the first keystroke. The lock field itself is present from the
  // first board frame, but this state still tracks the input flow.
  property bool inputStarted: false
  property int attempts: 0
  property string snapshotPath: ""
  property string snapshotCleanupPath: ""
  readonly property bool secure: lockContext.secure

  // quickshell forks its PAM worker without exec (quickshell-mirror/quickshell
  // #964). The child of a threaded process can inherit a mutex held by a
  // thread that no longer exists in it and deadlock in futex before PAM
  // produces anything: no prompt, no completion, no error, while submit() has
  // already disabled the input. quickshell works once or twice and then, on
  // the wrong roll, freezes the screen for good.
  //
  // The child is still killable, so the watchdog aborts the wedged
  // conversation, forks a fresh one, and resubmits the held password when the
  // new prompt arrives. Each kick re-rolls the fork race; three losses in a
  // row give up visibly and re-enable the input so the user can retry by hand.
  property string pendingPassword: ""
  property int pamKicks: 0
  // quickshell answers one fault with both signals: error() and then
  // completed(Error). The error handler has already named it, so this stops
  // the completion handler relabelling a broken worker as a wrong password.
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
    // Covers the boot lock too: a worker wedged before its prompt never asks
    // for a password, so nothing else would notice.
    root.pamKicks = 0;
    root.pendingPassword = "";
    root.pamErrored = false;
    pamWatchdog.restart();
  }

  function requestManualLock() {
    if (lockContext.locked || snapshotCapture.running)
      return;
    root.snapshotPath = Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-lock-snapshot.png";
    snapshotCapture.running = true;
  }

  // respond() is dropped unless PAM is already asking, and a conversation that
  // has only just been forked has not asked yet - its prompt arrives a tick
  // later, over a socket. So a password is always held here first and handed
  // over by whichever comes second, this call or the prompt.
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
    // The bar comes back on the first frame of the fade, not after it. The
    // captured background unblurs underneath the returning session UI.
    Bus.sessionReady = true;
    reveal.animateOut();
  }

  function fail(reason) {
    // The dots are already gone - submit wiped them - so a refusal just
    // relabels the empty field and lets the count ride with it.
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
    // The field wipes the frame Enter lands; the dots go with it, and the
    // placeholder the field carries turns to Authenticating until the
    // conversation answers.
    root.password = "";
    root.pamKicks = 0;
    root.pamErrored = false;
    root.pendingPassword = root.submittedPassword;
    pamWatchdog.restart();
    // A give-up abort or a silent start failure leaves no conversation to
    // answer this password; fork one.
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

  // Capture before the session-lock protocol takes ownership of the output.
  // Boot locks bypass this and continue to use the configured wallpaper.
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
        Bus.sessionReady = true;
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
      // Whether the password was typed before this prompt or after it, the
      // prompt is the half that arrives second often enough to matter.
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
      // A worker that died or never came up is not a refused password, and
      // must not read as one: onError has already labelled this.
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
      // Clear it like a refusal, so the field invites another try rather
      // than stranding the user on a dead-end message.
      failTimeout.restart();
    }
  }

  Timer {
    id: pamWatchdog

    interval: 4000

    onTriggered: {
      // A conversation sitting at its prompt with nothing submitted is
      // waiting on the user, not wedged. Stand down rather than churn PAM
      // under an idle lock screen: killing the healthy conversation the user
      // is about to answer is what made a correct password look wrong.
      if (!root.busy && passwordPam.active && passwordPam.responseRequired)
        return;
      if (root.pamKicks >= 3) {
        // Three lost fork rolls. Kill the last worker, surface the failure,
        // and leave the input to the user; the next submit forks fresh.
        passwordPam.abort();
        root.pendingPassword = "";
        root.busy = false;
        root.statusIsError = true;
        root.status = "Authentication unavailable";
        return;
      }
      root.pamKicks += 1;
      passwordPam.abort();
      // Only a submitted password rides the replacement conversation; a kick
      // that lands while the user is still typing would otherwise submit the
      // half-typed field the moment the fresh prompt arrives. Held before the
      // fork, so the replacement's prompt cannot outrun it.
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

      // Keep an opaque base mounted for the complete secure-lock lifetime.
      // A transparent session-lock surface is composited as black by the
      // compositor during lock/unlock, which creates the unwanted black flash.
      color: Theme.base

      // Reveal once the compositor has created the surface. There is one of
      // these per screen and they share the one reveal clock, so a second
      // screen joins the ramp already in progress rather than restarting it.
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
