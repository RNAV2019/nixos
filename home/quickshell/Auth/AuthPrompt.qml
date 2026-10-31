import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Ui

// The polkit prompt: the island grown into the login pill, with "<program> needs permission" in
// place of the name. It opens by itself when polkitd asks (Services/Polkit.qml), holds the
// keyboard exclusively until it is answered, and goes away on approval, Escape, a lock, or
// polkitd withdrawing the request. Another panel taking the island only moves it aside; the
// request is still pending, so the pill comes back when that panel lets go.
Variants {
  id: root

  model: Quickshell.screens

  IslandSurface {
    id: win

    key: "auth"
    exclusiveKeyboard: true
    // Only the pill is a target: a click off it reaches whatever is below, and never answers
    // or dismisses a request.
    passThrough: true

    openWidth: Theme.lockPillWidth
    openHeight: Theme.lockPillHeight
    openRadius: Theme.lockPillHeight / 2

    // ---- which output, and when ----

    // The output that was focused when the request arrived, else the first one.
    readonly property bool mine: {
      var screens = Quickshell.screens;
      for (var i = 0; i < screens.length; i++) {
        if (screens[i].name === Polkit.screenName)
          return win.screen !== null && win.screen.name === Polkit.screenName;
      }
      return win.screen === screens[0];
    }

    // Another panel holds the island here. The request waits behind it, as the transients do
    // behind this one.
    readonly property bool blocked: {
      var holder = Bus.holderKey(Bus.lookup(Bus.islandHolders, win.screen ? win.screen.name : "", null));
      return holder !== "" && holder !== win.key && !Bus.isTransient(holder);
    }

    readonly property bool wanted: Polkit.pending && win.mine && !Bus.locking && !win.blocked

    onWantedChanged: evaluateLater.restart()
    onOpenChanged: {
      // Closed by anything but the answer (a panel on another output took the island): still
      // wanted, so it comes back.
      if (!win.open)
        evaluateLater.restart();
    }
    Component.onCompleted: evaluateLater.restart()

    // Decided a turn later, never inside the change that prompted it; see Ui/TransientSurface.qml.
    Timer {
      id: evaluateLater

      interval: 0
      onTriggered: {
        if (win.wanted && !win.open)
          win.show();
        else if (!win.wanted && win.open)
          win.hide();
      }
    }

    // ---- the request, as the pill says it ----

    // The account asked for: the pill carries its picture, which is only the user's own.
    readonly property var identity: Polkit.identities.length > 0 ? Polkit.identities[Polkit.selectedIndex] : null
    readonly property bool isYou: win.identity !== null && win.identity.name === Account.userName

    property string password: ""

    function submit() {
      if (win.password.length === 0 || Polkit.checking)
        return;
      // The password is out of the field in the frame Enter lands.
      var text = win.password;
      win.password = "";
      Polkit.submit(text);
    }

    function cancel() {
      Polkit.cancel();
      win.hide();
    }

    // A new request (the queue moving on) starts from a clean field.
    function reset() {
      win.password = "";
      pill.focusInput();
    }

    onOpening: win.password = ""

    // Escape cancels the request, never just closes the pill: polkitd still has to be told no.
    onKeyPressed: function (event) {
      if (event.key === Qt.Key_Escape) {
        win.cancel();
        event.accepted = true;
      }
    }

    Connections {
      target: win

      // The surface takes its own focus a frame after it opens; the field takes it from that.
      function onOpenChanged() {
        if (win.open)
          Qt.callLater(pill.focusInput);
      }
    }

    Connections {
      target: Polkit

      function onFlowChanged() {
        if (win.open)
          win.reset();
      }

      function onPreviewChanged() {
        if (win.open)
          win.reset();
      }

      function onFailedCountChanged() {
        if (win.open && Polkit.failedCount > 0)
          pill.shakeOnce();
      }
    }

    // ---- the pill ----

    // Laid out at its own size; the growing island uncovers it. Escape reaches here from the
    // field, which leaves keys it does not use unaccepted.
    Item {
      anchors.fill: parent

      Keys.onEscapePressed: win.cancel()

      LoginPill {
        id: pill

        anchors.fill: parent
        // The island is the ground and the outline.
        framed: false

        title: Polkit.requester + Theme.authLabelSuffix
        initial: win.identity !== null && win.identity.displayName !== "" ? win.identity.displayName : Account.displayName
        facePath: win.isYou ? Account.facePath : ""
        faceRevision: Account.faceRevision
        password: win.password
        placeholder: Polkit.prompt
        // The failure is the pill's to word, and clears on the next key, so a keystroke is all
        // it takes to drop the error.
        failed: Polkit.errorText !== ""
        status: "Wrong password · try " + (Polkit.failedCount + 1)
        busy: Polkit.checking

        onPasswordEdited: text => {
          win.password = text;
          if (text.length > 0)
            Polkit.clearError();
        }
        onAccepted: win.submit()
      }
    }
  }
}
