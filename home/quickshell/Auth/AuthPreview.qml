import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services

// The authentication prompt on a rehearsal stage: a made-up request in place of polkitd's, so
// every state can be seen without a privileged action to ask for one. Driven over IPC
// (`qs ipc call authpreview ask pkexec|plain|long|identities`, then `checking`, `fail`,
// `hide`); typing and Escape are the real ones. `status` reports the live agent as JSON.
Scope {
  id: root

  function build(kind) {
    var you = {
      name: Account.userName,
      displayName: Account.displayName,
      isGroup: false
    };
    var req = {
      message: "Authentication is required to run `nixos-rebuild` as the super user",
      actionId: "org.freedesktop.policykit.exec",
      prompt: "Password:",
      identities: [you]
    };
    switch (kind) {
    case "plain":
      req.message = "Authentication is required to install firmware on the Framework Laptop";
      req.actionId = "org.freedesktop.fwupd.update-internal";
      break;
    case "long":
      req.message = "Authentication is required to run `/run/current-system/sw/bin/nixos-rebuild-with-a-very-long-name` as the super user";
      break;
    case "identities":
      // The user's own account is not first: it is the one the pill asks for.
      req.identities = [
        {
          name: "root",
          displayName: "System administrator",
          isGroup: false
        },
        you];
      break;
    }
    return req;
  }

  IpcHandler {
    target: "authpreview"

    function ask(kind: string): void {
      Polkit.screenName = Monitors.focusedName;
      Polkit.preview = root.build(kind);
    }

    // A try is out and nothing has come back.
    function checking(): void {
      if (Polkit.preview)
        Polkit.submitted = true;
    }

    // The try comes back wrong, as polkitd would say it.
    function fail(text: string): void {
      if (Polkit.preview) {
        Polkit.heardError = text;
        Polkit.noteFailure();
      }
    }

    function hide(): void {
      Polkit.cancel();
    }

    // What the service holds, as one line, for the test that drives a real polkitd.
    function status(): string {
      return JSON.stringify({
        registered: Polkit.registered,
        pending: Polkit.pending,
        checking: Polkit.checking,
        error: Polkit.errorText,
        failures: Polkit.failedCount,
        actionId: Polkit.actionId,
        message: Polkit.message,
        prompt: Polkit.prompt,
        selected: Polkit.selectedIndex,
        identity: Polkit.identities.length > 0 ? Polkit.identities[Polkit.selectedIndex].name : "",
        identities: Polkit.identities.map(i => i.name),
        shown: Bus.surfaceOpen("auth")
      });
    }
  }
}
