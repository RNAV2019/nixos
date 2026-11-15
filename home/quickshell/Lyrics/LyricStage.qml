import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Services
import "Kinetic.js" as Kinetic

// The lyric stage: one screen given over to the words of what is playing, set in motion and
// recast in a new style for each part of the song. A key toggles it (`qs ipc call lyrics
// toggle`, ALT + L in home/desktop.nix); Escape or a click puts it away, and so does the session
// locking. It comes and goes the way a folding phone hands one screen to the other, without the
// tilt (Ryan wanted the blur and the fade and not the fold itself, 2026-11-15): the desktop goes
// out of focus from the top down and dark, and the stage comes the other way out of the same
// blur; leaving, they change places. It is a show, not a surface: it takes the whole of the
// focused screen above everything else, takes the keyboard while it is up, and keeps the machine
// from idling.
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
  // And `lyrics fold 0.4` holds the way in at that point (0 the desktop, 1 the stage; a negative
  // number lets go), so the fold can be looked at standing still.
  property real pinnedFold: -1
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

  // The words are held until the stage has gone, so it leaves with them on it: without them it
  // shows the song's name, and would change to that on its way out.
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
      // The desktop has been caught for the fold, or given up on, and the stage may come up.
      property bool caught: false
      // 0 away, 1 up.
      property real presence: root.pinnedFold >= 0 && here && caught ? root.pinnedFold : here && caught ? 1 : 0
      // On its way in or out.
      readonly property bool folding: presence > 0.001 && presence < 0.999

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
          easing.type: Easing.InOutSine
        }
      }

      IdleInhibitor {
        window: win
        enabled: win.here
      }

      // The desktop as it stood when the key was pressed: the way in needs a picture of it to
      // blur, since the real one behind the window cannot be. Taken the way the lock takes
      // its own (grim, stored not deflated, off the runtime dir), as the window maps and while it
      // is still clear, and thrown away when the window has gone.
      readonly property string shotPath: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-lyrics-" + modelData.name + ".png"

      Process {
        id: grab

        command: ["grim", "-l", "0", "-o", win.modelData.name, win.shotPath]

        onExited: function (code) {
          if (code === 0 && win.here && !win.caught)
            shot.source = "file://" + win.shotPath;
        }
      }

      Process {
        id: discard

        command: ["rm", "-f", win.shotPath]
      }

      Image {
        id: shot

        anchors.fill: parent
        visible: false
        cache: false
        asynchronous: true
        mipmap: true

        readonly property bool hasContent: status === Image.Ready

        onStatusChanged: if (status === Image.Ready && win.here)
          win.caught = true
      }

      onVisibleChanged: if (!visible) {
        shot.source = "";
        discard.running = true;
      }

      Timer {
        id: giveUp

        // With no picture to be had the stage comes up through plain black.
        interval: 500
        onTriggered: win.caught = true
      }

      // Black under everything once the stage is on its way. With no picture of the desktop it
      // is the whole way in and out.
      Rectangle {
        anchors.fill: parent
        color: Theme.lyricGround
        opacity: shot.hasContent ? (win.presence > 0.001 ? 1 : 0) : win.presence
      }

      // The desktop, going out of focus and dark as the stage comes, and back as it goes.
      ShaderEffect {
        anchors.fill: parent
        visible: shot.hasContent && win.presence > 0.001 && win.presence < 0.999
        opacity: 1 - Kinetic.smooth(0.3, 0.66, win.presence)

        property var source: shot
        property size pixels: Qt.size(width * win.devicePixelRatio, height * win.devicePixelRatio)
        property real fold: Kinetic.smooth(0, 0.66, win.presence)

        fragmentShader: Qt.resolvedUrl("../Shaders/lyricfold.frag.qsb")
      }

      LyricScene {
        id: scene

        anchors.fill: parent
        live: win.visible
        pinned: root.pinned
        forcedStyle: root.forcedStyle
        offset: root.offset
        pixelRatio: win.devicePixelRatio
        onTicked: root.frames++
      }

      // The stage as a picture, for the same blur to work on; on its way in or out, this is
      // what is seen of it. Up, the stage draws itself and this stands idle.
      ShaderEffectSource {
        id: stageTexture

        sourceItem: scene
        hideSource: win.presence < 0.999
        live: win.presence < 0.999 && win.visible
        mipmap: true
        visible: false
      }

      ShaderEffect {
        anchors.fill: parent
        visible: win.folding
        opacity: Kinetic.smooth(0.3, 0.72, win.presence)

        property var source: stageTexture
        property size pixels: Qt.size(width * win.devicePixelRatio, height * win.devicePixelRatio)
        property real fold: 1 - Kinetic.smooth(0.34, 1, win.presence)

        fragmentShader: Qt.resolvedUrl("../Shaders/lyricfold.frag.qsb")
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
        if (win.here) {
          take.restart();
          // With motion reduced there is no fold to take a picture for.
          win.caught = Theme.reduceMotion;
          if (!Theme.reduceMotion) {
            shot.source = "";
            grab.running = true;
            giveUp.restart();
          }
        } else {
          giveUp.stop();
        }
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
