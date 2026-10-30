import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services

// The authentication prompt on a rehearsal stage: a made-up request in place of polkitd's, so
// every state can be seen without a privileged action to ask for one. Driven over IPC
// (`qs ipc call authpreview ask pkexec|plain|code|info|identities|long`, then `checking`,
// `fail`, `hide`); typing, Tab and the buttons are the real ones.
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
      iconName: "",
      prompt: "Password:",
      echo: false,
      notice: "",
      noticeIsError: false,
      identities: [you],
      rows: [
        {
          label: "Program",
          value: "/run/current-system/sw/bin/nixos-rebuild"
        },
        {
          label: "Command",
          value: "nixos-rebuild switch --flake .#"
        },
        {
          label: "Run as",
          value: "root"
        },
        {
          label: "Caller",
          value: "fish · pid 41873"
        }
      ]
    };
    switch (kind) {
    case "plain":
      req.message = "Authentication is required to install firmware on the Framework Laptop";
      req.actionId = "org.freedesktop.fwupd.update-internal";
      req.rows = [
        {
          label: "Identity",
          value: Account.userName
        }
      ];
      break;
    case "long":
      req.message = "Authentication is required to run `/run/current-system/sw/bin/nixos-rebuild` as the super user, rebuilding every host in the flake and activating the result";
      break;
    case "code":
      req.message = "Authentication is required to change the system's network settings";
      req.actionId = "org.freedesktop.NetworkManager.settings.modify.system";
      req.prompt = "Verification code:";
      req.echo = true;
      break;
    case "info":
      req.notice = "Place your finger on the reader";
      break;
    case "identities":
      req.identities = [you,
        {
          name: "root",
          displayName: "System administrator",
          isGroup: false
        }
      ];
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
  }
}
