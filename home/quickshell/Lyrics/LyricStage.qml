import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import "Kinetic.js" as Kinetic

// The lyric stage: one screen given over to the words of what is playing, set in motion. A key
// toggles it (`qs ipc call lyrics toggle`, ALT + L in home/desktop.nix); Escape or a click puts
// it away, and so does the session locking. It comes the way a screensaver does: the desktop
// fades slowly to black, and the words come up out of the black over the last of it. It goes
// much faster than it came. It is a show, not a surface: it takes the whole of the focused
// screen above everything else, takes the keyboard while it is up, and keeps the machine from
// idling.
//
// Its keys: N and P step to the next and the previous style (Theme.lyricStyles; it opens in
// the first), Space plays and pauses, the arrows skip, [ and ] slide the words against the
// player's clock a twentieth of a second at a time (kept, since a player's clock is as late
// tomorrow as today).
Scope {
  id: root

  property bool wanted: false
  // The screen it opened on, so it stays there if the focus moves; "" where the compositor
  // names none.
  property string screenName: ""
  readonly property bool shown: wanted && !Bus.locking

  // The style the words are drawn in. It is kept while the shell runs, so the stage comes back
  // in the style it was left in.
  property string styleName: Theme.lyricStyles[0]

  // Tests: `qs ipc call lyrics pin 42.5` holds the song there (a negative number lets go), and
  // `lyrics fade 0.4` holds the way in at that point (0 the desktop, 1 the stage; a negative
  // number lets go), so the fade can be looked at standing still.
  property real pinned: -1
  property real pinnedFade: -1
  // Frames drawn since the shell started, which `lyrics frames` reports: a probe reads it twice
  // and divides the CPU time between by the difference.
  property int frames: 0

  readonly property real offset: Number(offsetStore.value) || 0

  function toggle() {
    if (!root.wanted)
      root.screenName = Monitors.focusedName;
    root.wanted = !root.wanted;
  }

  function close() {
    root.wanted = false;
  }

  function nudge(by) {
    var next = Math.round((root.offset + by) * 100) / 100;
    offsetStore.save(String(next));
    root.say((next > 0 ? "Words " + next.toFixed(2) + " s early" : next < 0 ? "Words " + (-next).toFixed(2) + " s late" : "Words on the player's clock"));
  }

  // The style `by` places on from the one in hand, round the list either way.
  function step(by) {
    var names = Theme.lyricStyles;
    var at = Math.max(0, names.indexOf(root.styleName));
    root.styleName = names[(at + by + names.length) % names.length];
    root.say(root.styleName);
  }

  // A style by name, as `lyrics style Drift` asks for one; a name there is no style of is
  // left alone.
  function pick(name) {
    if (Theme.lyricStyles.indexOf(name) >= 0)
      root.styleName = name;
  }

  // The readout's line, and a count that moves each time it is said.
  property string readout: ""
  property int said: 0

  function say(text) {
    root.readout = text;
    root.said++;
  }

  Connections {
    target: Bus

    function onLockingChanged() {
      if (Bus.locking)
        root.wanted = false;
    }
  }

  // The words are held until the stage has gone, so it leaves with them on it: without them it
  // would change to "Nothing to show" on its way out.
  property bool lingering: false

  onShownChanged: {
    if (root.shown)
      root.lingering = true;
    else
      linger.restart();
  }

  Timer {
    id: linger

    interval: Theme.lyricFadeOut + Theme.lyricCut
    onTriggered: root.lingering = root.shown
  }

  Binding {
    target: Lyrics
    property: "wanted"
    value: root.shown || root.lingering
  }

  PersistedValue {
    id: offsetStore

    name: "lyrics-offset"
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win

      required property var modelData

      readonly property bool here: root.shown && (root.screenName !== "" ? modelData.name === root.screenName : Monitors.isFocused(modelData))
      // 0 away, 1 up.
      property real presence: root.pinnedFade >= 0 && here ? root.pinnedFade : here ? 1 : 0

      screen: modelData
      visible: here || presence > 0.001
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "quickshell-lyrics"
      WlrLayershell.keyboardFocus: win.here && win.taking ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      Behavior on presence {
        // A point held for a look is gone to at once.
        enabled: root.pinnedFade < 0

        NumberAnimation {
          duration: win.here ? Theme.lyricFadeIn : Theme.lyricFadeOut
          easing.type: Easing.InOutSine
        }
      }

      IdleInhibitor {
        window: win
        enabled: win.here
      }

      // The desktop goes to black under the window, which is clear, so it is the desktop itself
      // that fades and not a picture of it.
      Rectangle {
        anchors.fill: parent
        color: Theme.lyricGround
        opacity: Kinetic.smooth(0, 0.8, win.presence)
      }

      // And the stage comes up out of the black over the last of the way.
      LyricScene {
        id: scene

        anchors.fill: parent
        opacity: Kinetic.smooth(0.6, 1, win.presence)
        visible: opacity > 0.001
        live: win.visible
        pinned: root.pinned
        styleName: root.styleName
        offset: root.offset
        pixelRatio: win.devicePixelRatio
        onTicked: root.frames++
      }

      // What a key just did, small and brief, under the picture, and gone with it.
      Text {
        id: readout

        // How far up the line is, before the stage's own fade.
        property real said: 0

        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - height - Theme.lyricReadoutSize * 3
        text: root.readout
        color: Theme.lyricInk
        font.family: Theme.uiFont
        font.pixelSize: Theme.lyricReadoutSize
        font.weight: Theme.weightMedium
        opacity: said * win.presence

        Connections {
          target: root

          function onSaidChanged() {
            readoutShow.restart();
          }
        }

        SequentialAnimation {
          id: readoutShow

          NumberAnimation {
            target: readout
            property: "said"
            to: 0.8
            duration: Theme.focusFade
          }

          PauseAnimation {
            duration: Theme.lyricReadoutHold
          }

          NumberAnimation {
            target: readout
            property: "said"
            to: 0
            duration: Theme.tintFade
          }
        }
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        cursorShape: Qt.BlankCursor
        onPressed: root.close()
      }

      // The keyboard is asked for a moment after the window maps, as a change on a surface that
      // is already there: the way the island's panels get it, which is the way known to work on
      // Hyprland. Qt then needs a target inside the window.
      property bool taking: false

      onHereChanged: {
        win.taking = false;
        if (win.here)
          take.restart();
      }

      Timer {
        id: take

        interval: Theme.lyricTakeKeys
        onTriggered: {
          win.taking = win.here;
          if (win.here)
            keys.forceActiveFocus();
        }
      }

      Item {
        id: keys

        focus: true

        Keys.onPressed: function (event) {
          event.accepted = true;
          if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q)
            root.close();
          else if (event.key === Qt.Key_N)
            root.step(1);
          else if (event.key === Qt.Key_P)
            root.step(-1);
          else if (event.key === Qt.Key_Space)
            Media.toggle();
          else if (event.key === Qt.Key_Right)
            Media.next();
          else if (event.key === Qt.Key_Left)
            Media.previous();
          else if (event.key === Qt.Key_BracketRight)
            root.nudge(Theme.lyricNudge);
          else if (event.key === Qt.Key_BracketLeft)
            root.nudge(-Theme.lyricNudge);
          else
            event.accepted = false;
        }
      }
    }
  }
}
