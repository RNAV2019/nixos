pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import qs.Commons

// The shell's polkit authentication agent: it registers for the session, queues the requests
// polkitd sends (pkexec, Nautilus' admin actions, fwupd, ...) and keeps what the prompt in
// Auth/AuthPrompt.qml has to remember between one question and the next.
//
// The pinned Quickshell (0.3.2) hands over the action id, the message, the identities that may
// approve and the PAM conversation. It drops polkit's `details` map (program, command line,
// caller pid), so who is asking is read back out of the message, which pkexec's action text
// quotes, else taken from the action id. The prompt asks the user's own account when that may
// approve, else the first one listed; it offers no choice.
//
// Two traps in that API are handled here. `failed` latches true for the rest of the flow, and
// a failed try starts a fresh PAM session that clears its own message while it re-asks, so the
// error text is held in `errorText` until the next keystroke. And a flow that ends (cancelled,
// approved, withdrawn by polkitd) is deleted a beat later, so `closing` takes the prompt down
// at once instead of waiting for that.
Singleton {
  id: root

  readonly property alias registered: agent.isRegistered
  // The live conversation, or null when polkitd has asked nothing.
  readonly property var flow: agent.flow

  // A rehearsal in place of a request (Auth/AuthPreview.qml): the same properties, no polkitd.
  property var preview: null

  // Raised when a request ends in any way, so the prompt takes itself down at once.
  property bool closing: false
  readonly property bool pending: (preview !== null || flow !== null) && !closing

  // The output the prompt belongs on, taken when the request arrived, so the surface does not
  // follow the pointer to another monitor and leave the first one holding exclusive keys.
  property string screenName: ""

  // ---- what is being asked ----

  // What the prompt shows, taken from the live request while there is one and kept after it
  // ends, so the card's fade out is not played over blanked-out words.
  QtObject {
    id: held

    property string message: ""
    property string actionId: ""
    property var identities: []
    property int selectedIndex: 0
    property string prompt: "Password"
    property bool checking: false
  }

  Binding {
    target: held
    property: "message"
    value: root.preview ? root.preview.message : root.flow ? root.flow.message : ""
    when: root.pending
    restoreMode: Binding.RestoreNone
  }

  Binding {
    target: held
    property: "actionId"
    value: root.preview ? root.preview.actionId : root.flow ? root.flow.actionId : ""
    when: root.pending
    restoreMode: Binding.RestoreNone
  }

  Binding {
    target: held
    property: "identities"
    value: root.liveIdentities
    when: root.pending
    restoreMode: Binding.RestoreNone
  }

  Binding {
    target: held
    property: "selectedIndex"
    value: root.liveSelected
    when: root.pending
    restoreMode: Binding.RestoreNone
  }

  Binding {
    target: held
    property: "prompt"
    value: root.livePrompt
    when: root.pending
    restoreMode: Binding.RestoreNone
  }

  Binding {
    target: held
    property: "checking"
    value: root.liveChecking
    when: root.pending
    restoreMode: Binding.RestoreNone
  }

  // Everything the prompt reads about the request is held (see `held`): once it ends the flow
  // is gone a moment later, and the card is still on its way out, so it must keep its words.
  readonly property string message: held.message
  readonly property string actionId: held.actionId
  readonly property var identities: held.identities
  readonly property int selectedIndex: held.selectedIndex
  readonly property string prompt: held.prompt
  readonly property bool checking: held.checking

  // The program the action text quotes, "" when it quotes none.
  readonly property string program: {
    var m = /`([^`']+)['`]/.exec(root.message);
    return m ? m[1] : "";
  }

  // Who is asking, for the pill's label: the program's name, else the action's owner.
  readonly property string requester: {
    if (root.program !== "")
      return root.program.substring(root.program.lastIndexOf("/") + 1);
    return root.ownerOf(root.actionId);
  }

  // org.freedesktop.fwupd.update-internal -> fwupd. Reverse-DNS prefixes and "freedesktop" are
  // not the name, and policykit's one action that matters is pkexec.
  function ownerOf(id) {
    var parts = id.split(".");
    if (parts.length > 0 && ["org", "com", "net", "io", "dev"].indexOf(parts[0]) !== -1)
      parts.shift();
    if (parts.length > 1 && parts[0] === "freedesktop")
      parts.shift();
    if (parts.length === 0 || parts[0] === "")
      return "System";
    if (parts[0] === "policykit")
      return "pkexec";
    return parts[0];
  }

  // The accounts that may approve, as plain objects so a rehearsal can supply its own.
  readonly property var liveIdentities: {
    if (root.preview)
      return root.preview.identities;
    var list = [];
    if (root.flow) {
      for (var i = 0; i < root.flow.identities.length; i++) {
        var who = root.flow.identities[i];
        list.push({
          name: who.string,
          displayName: who.displayName,
          isGroup: who.isGroup
        });
      }
    }
    return list;
  }

  // Who is asked for: the user's own account if it may approve, else the first listed.
  function preferredIn(names) {
    var at = names.indexOf(Account.userName);
    return at >= 0 ? at : 0;
  }

  readonly property int liveSelected: {
    if (root.preview)
      return root.preferredIn(root.preview.identities.map(i => i.name));
    if (!root.flow)
      return 0;
    for (var i = 0; i < root.flow.identities.length; i++) {
      if (root.flow.identities[i] === root.flow.selectedIdentity)
        return i;
    }
    return 0;
  }

  // ---- the conversation ----

  // PAM is waiting on an answer; false before its first question and while it checks one.
  readonly property bool awaitingInput: root.preview ? root.previewAwaiting : root.flow ? root.flow.isResponseRequired : false
  property bool previewAwaiting: true

  // What PAM asks, without the trailing colon it ends its prompts with.
  readonly property string livePrompt: {
    var text = root.preview ? root.preview.prompt : root.flow ? root.flow.inputPrompt : "";
    text = (text || "").replace(/[\s:：]+$/, "");
    return text !== "" ? text : "Password";
  }

  // An answer is out and nothing has come back yet. Set by submit(), cleared by PAM asking
  // again (a wrong answer, or a second factor) or by the flow ending.
  property bool submitted: false
  readonly property bool liveChecking: root.pending && root.submitted

  // The error latched from the last failed try, until the next keystroke. `failedCount` counts
  // the failures of this request and shakes the pill again for each; a new request starts at 0.
  property string errorText: ""
  property int failedCount: 0

  // The error PAM gave during this try, if it gave one; used for the latch when a try fails.
  property string heardError: ""

  // An identity change is under way; see pickIdentity().
  property bool switching: false

  // An answer typed before PAM has asked again (right after a failure), sent as soon as it does.
  property string queued: ""
  property bool hasQueued: false

  readonly property string failureFallback: "Sorry, that didn't work. Please try again."

  function submit(text) {
    if (!root.pending || root.submitted)
      return;
    root.heardError = "";
    root.errorText = "";
    root.submitted = true;
    if (root.preview)
      return;
    if (root.flow.isResponseRequired) {
      root.flow.submit(text);
    } else {
      root.queued = text;
      root.hasQueued = true;
    }
  }

  function clearError() {
    root.errorText = "";
  }

  // The user's Cancel, Escape, a lock, or the prompt having nowhere to go. polkitd hears of it
  // and tells the requester no.
  function cancel() {
    root.closing = true;
    root.queued = "";
    root.hasQueued = false;
    if (root.preview)
      return;
    // Asking a finished flow to cancel would answer polkitd twice.
    if (root.flow && !root.flow.isCompleted && !root.flow.isCancelled)
      root.flow.cancelAuthenticationRequest();
  }

  // The first question is asked of the user's own account when it may approve, whoever polkitd
  // listed first. Choosing restarts the conversation, so it is done before anything is typed.
  function pickIdentity() {
    var list = root.flow.identities;
    for (var i = 0; i < list.length; i++) {
      if (list[i].string !== Account.userName)
        continue;
      if (list[i] !== root.flow.selectedIdentity) {
        // AuthFlow cancels the old PAM session to start the new one, and reports that as a failed
        // try, synchronously; it is not one.
        root.switching = true;
        root.flow.selectedIdentity = list[i];
        root.switching = false;
      }
      return;
    }
  }

  // A try failed: hold the reason where the prompt can keep showing it.
  function noteFailure() {
    root.submitted = false;
    root.errorText = root.heardError !== "" ? root.heardError : root.failureFallback;
    root.heardError = "";
    root.failedCount += 1;
  }

  onFlowChanged: {
    if (!root.flow)
      return;
    root.closing = false;
    root.submitted = false;
    root.failedCount = 0;
    root.errorText = "";
    root.heardError = "";
    root.queued = "";
    root.hasQueued = false;
    root.pickIdentity();
  }

  onPreviewChanged: {
    if (!root.preview)
      return;
    root.closing = false;
    root.submitted = false;
    root.failedCount = 0;
    root.errorText = "";
    root.heardError = "";
    root.previewAwaiting = true;
  }

  onAwaitingInputChanged: {
    if (!root.awaitingInput || root.preview)
      return;
    if (root.hasQueued) {
      var text = root.queued;
      root.queued = "";
      root.hasQueued = false;
      root.flow.submit(text);
    } else {
      root.submitted = false;
    }
  }

  PolkitAgent {
    id: agent

    onAuthenticationRequestStarted: {
      // Taken before the surfaces see the request, which they decide from.
      root.screenName = Monitors.focusedName;
      // Nobody is going to see a prompt over the lock screen, and nobody could answer one.
      if (Bus.locking)
        root.cancel();
    }
  }

  Connections {
    target: root.flow
    ignoreUnknownSignals: true

    function onAuthenticationFailed() {
      if (!root.switching)
        root.noteFailure();
    }

    function onAuthenticationSucceeded() {
      root.closing = true;
    }

    // polkitd withdrew it: the requester went away, or its own timeout ran out.
    function onAuthenticationRequestCancelled() {
      root.closing = true;
    }

    function onSupplementaryMessageChanged() {
      if (root.flow && root.flow.supplementaryIsError && root.flow.supplementaryMessage !== "")
        root.heardError = root.flow.supplementaryMessage;
    }
  }

  // A locking session closes every island surface; an auth flow left open under it would sit
  // in polkitd's queue with nothing to answer it.
  Connections {
    target: Bus

    function onSurfacesClosingForLock() {
      if (root.pending)
        root.cancel();
    }
  }
}
