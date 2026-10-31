import QtQuick
import Quickshell
import Quickshell.Networking
import qs.Commons
import qs.Services

// Raises the Wi-Fi sign-in moment when NetworkManager's connectivity check finds a captive
// portal (modules/system/default.nix turns the check on). The moment stays until it is acted on
// or dismissed, and is withdrawn when the check passes. A dismissed one does not return for the
// same network, until the connection has been seen fully online or the network changes.
MomentSource {
  id: root

  kind: "wifi-signin"

  // For tests: "portal", "full", "none" or "limited" stand in for NetworkManager's verdict;
  // QUICKSHELL_FAKE_CONNECTIVITY starts the shell with one, and `fakeNetwork` names the network.
  property string fake: Quickshell.env("QUICKSHELL_FAKE_CONNECTIVITY") || ""
  property string fakeNetwork: Quickshell.env("QUICKSHELL_FAKE_NETWORK") || ""

  readonly property bool portal: fake !== "" ? fake === "portal" : Networking.connectivity === NetworkConnectivity.Portal
  readonly property bool online: fake !== "" ? fake === "full" : Networking.connectivity === NetworkConnectivity.Full

  // The network the portal is on; the check says nothing about which.
  readonly property string network: fake !== "" ? fakeNetwork : NetworkInfo.activeNetwork ? NetworkInfo.activeNetwork.name : ""

  // The network whose moment was dismissed ("" for none), and the one the moment on show is for.
  property string dismissedFor: ""
  property string momentFor: ""

  // NetworkManager's own probe address, which a portal redirects: where sign-in starts when no
  // page is known. The browser (Helium, the default) lands on the portal's login.
  readonly property string probe: "http://nmcheck.gnome.org/check_network_status.txt"

  onPortalChanged: root.sync()
  onNetworkChanged: root.sync()

  onOnlineChanged: {
    if (online)
      dismissedFor = "";
    root.sync();
  }

  function sync() {
    if (portal && network !== dismissedFor) {
      // The name can arrive after the verdict: raised again under the same key, it replaces itself.
      if (momentId === 0 || !queued() || momentFor !== network)
        root.raise();
    } else {
      root.withdraw();
    }
  }

  function raise() {
    var name = root.network;
    momentFor = name;
    show({
      attention: true,
      icon: IconPaths.wifi,
      iconColor: Theme.gold,
      title: name !== "" ? "Sign in to “" + name + "”" : "Sign in to this network",
      subtitle: "This network needs a login",
      dwell: 0,
      buttons: [
        {
          text: "Open sign-in page",
          kind: "primary",
          width: 140,
          action: function () {
            root.openPage();
          }
        }
      ]
    });
  }

  // Any dismissal that is not ours is the user's, by acting or swiping it away.
  onDismissed: root.dismissedFor = root.network

  // NetworkManager says which address it probes; the page itself is not something it keeps, so
  // the probe is what the browser opens, and the portal redirects it to its login.
  function openPage() {
    opener.exec(Launch.scoped(["sh", "-c", "uri=$(busctl --system get-property org.freedesktop.NetworkManager /org/freedesktop/NetworkManager org.freedesktop.NetworkManager ConnectivityCheckUri 2>/dev/null | cut -d'\"' -f2); exec xdg-open \"${uri:-$1}\"", "sh", root.probe], "xdg-open"));
  }

  property Command opener: Command {
    label: "Open sign-in page"
  }

  Component.onCompleted: root.sync()
}
