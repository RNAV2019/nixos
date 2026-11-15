import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import "Kinetic.js" as Kinetic

// The lyric stage: one screen given over to the words of what is playing, set in motion and
// recast in a new style for each part of the song. A key toggles it (`qs ipc call lyrics
// toggle`, ALT + L in home/desktop.nix); Escape or a click puts it away, and so does the session
// locking. It is a show, not a surface: it takes the whole of the focused screen above everything
// else, takes the keyboard while it is up, and keeps the machine from idling.
//
// Its keys: Space plays and pauses, the arrows skip, [ and ] slide the words against the
// player's clock a twentieth of a second at a time (kept, since a player's clock is as late
// tomorrow as today), S pins the next style and A hands the casting back to the song.
Scope {
  id: root

  property bool wanted: false
  // The screen it opened on, so it stays there if the focus moves; "" where the compositor
  // names none.
  property string screenName: ""
  readonly property bool shown: wanted && !Bus.locking

  // Tests: `qs ipc call lyrics pin 42.5` holds the song there (a negative number lets go),
  // `lyrics style Punch` plays everything in one style ("" casts again).
  property real pinned: -1
  property string forcedStyle: ""
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

  function cycleStyle(names) {
    var at = names.indexOf(root.forcedStyle);
    root.forcedStyle = names[(at + 1) % names.length];
    root.say(root.forcedStyle);
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

  Binding {
    target: Lyrics
    property: "wanted"
    value: root.shown
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
      // 0 away, 1 up: slowly in, briskly out.
      property real presence: here ? 1 : 0

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
        NumberAnimation {
          duration: win.here ? Theme.lyricFadeIn : Theme.lyricFadeOut
          easing.type: win.here ? Easing.InOutCubic : Easing.OutCubic
        }
      }

      IdleInhibitor {
        window: win
        enabled: win.here
      }

      // The desktop goes to black first, and the picture comes up out of the black.
      Rectangle {
        anchors.fill: parent
        color: Theme.lyricGround
        opacity: win.presence
      }

      LyricScene {
        id: scene

        anchors.fill: parent
        live: win.visible
        opacity: Kinetic.smooth(0.35, 1, win.presence)
        pinned: root.pinned
        forcedStyle: root.forcedStyle
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
          else if (event.key === Qt.Key_S)
            root.cycleStyle(scene.styleNames);
          else if (event.key === Qt.Key_A) {
            root.forcedStyle = "";
            root.say("Cast by the song");
          } else
            event.accepted = false;
        }
      }
    }
  }
}
