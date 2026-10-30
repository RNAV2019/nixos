import QtQuick
import Quickshell
import Quickshell.Io
import qs.Activities
import qs.Auth
import qs.Bar
import qs.Calendar
import qs.Capture
import qs.Commons
import qs.Control
import qs.Dictation
import qs.Launcher
import qs.Lock
import qs.Nearby
import qs.Notifications
import qs.Osd
import qs.Overview
import qs.Power
import qs.Recorder
import qs.Services
import qs.Session
import qs.Theme
import qs.Wallpaper

ShellRoot {
  // Singletons start on first use; this one has to be running before the panel opens, to
  // put a remembered monitor back where it was.
  Component.onCompleted: Displays.restoreAll()

  Bar {}
  PillSlide {}
  SatelliteCards {}
  Moments {}
  ActivitySources {
    id: activitySources
  }
  AuthPrompt {}
  AuthPreview {}
  CalendarPanel {}
  CaptureTray {}
  DictationPill {}
  ControlCenter {}
  Launcher {}
  NearbyPanel {}
  SharingPill {}
  Notifications {}
  Osd {}
  Overview {}
  Profiles {}
  RecorderPicker {}
  ScreenToolsPanel {}
  SessionMenu {}
  WallpaperPicker {}
  ThemePicker {}
  Lock {
    id: lockScreen
  }
  LockPreview {}

  // The island surfaces with the same toggle/close pair; the recorder, theme, session, nearby
  // and screen tools targets stay handwritten below, since they differ, and the auth prompt takes
  // no toggle: polkitd opens it, and only an answer closes it.
  Variants {
    model: Bus.islandKeys.filter(k => k !== "theme" && k !== "session" && k !== "recorder" && k !== "nearby" && k !== "screentools" && k !== "auth")

    IpcHandler {
      required property string modelData

      target: modelData

      function toggle(): void {
        Bus.toggleSurface(modelData);
      }

      function close(): void {
        Bus.closeSurface(modelData);
      }
    }
  }

  IpcHandler {
    target: "theme"

    function toggle(): void {
      Bus.toggleSurface("theme");
    }

    function close(): void {
      Bus.closeSurface("theme");
    }

    // theme-switch calls this once the name is written; see Theme.reload().
    function sync(): void {
      Theme.reload();
    }
  }

  IpcHandler {
    target: "session"

    function toggle(): void {
      Bus.toggleSurface("session");
    }
  }

  // The recorder's key is busy-aware: while a recording runs, the same key stops it and
  // only an idle recorder opens the picker. See Recorder.toggle() and the pill's tile.
  IpcHandler {
    target: "recorder"

    function toggle(): void {
      if (Recorder.busy)
        Recorder.stop();
      else
        Bus.toggleSurface("recorder");
    }

    function close(): void {
      Bus.closeSurface("recorder");
    }
  }

  // Nearby also takes files, the same path a drop on the island does: `qs ipc call
  // nearby send <path>` opens the panel in Send mode with the file staged.
  IpcHandler {
    target: "nearby"

    function toggle(): void {
      Bus.toggleSurface("nearby");
    }

    function close(): void {
      Bus.closeSurface("nearby");
    }

    function send(path: string): void {
      Nearby.requestSend([path]);
    }

    // Jump straight to the receive view: `qs ipc call nearby receive`.
    function receive(): void {
      Nearby.requestReceive();
    }
  }

  // The screen tools open on a key; `run` fires one directly (the colour picker has its own
  // shortcut), closing the surface first if it is up.
  IpcHandler {
    target: "screentools"

    function toggle(): void {
      Bus.toggleSurface("screentools");
    }

    function close(): void {
      Bus.closeSurface("screentools");
    }

    function run(tool: string): void {
      ScreenTools.start(tool);
    }
  }

  // Screenshots: each is saved, copied and shown in the tray. See Services/Captures.qml.
  IpcHandler {
    target: "capture"

    function region(): void {
      Captures.begin("region");
    }

    function window(): void {
      Captures.begin("window");
    }

    function output(): void {
      Captures.begin("output");
    }

    function screen(): void {
      Captures.begin("screen");
    }
  }

  // The tray's buttons, for a key to be bound to later.
  IpcHandler {
    target: "captures"

    function annotate(): void {
      Captures.annotate();
    }

    function copy(): void {
      Captures.copy();
    }

    function send(): void {
      Captures.send();
    }

    function open(): void {
      Captures.open();
    }

    function step(): void {
      Captures.step();
    }

    function dismiss(): void {
      Captures.dismiss();
    }

    // `delete` is a reserved word in QML, so the IPC call is `remove`.
    function remove(): void {
      Captures.remove();
    }
  }

  // Route the keys through here so the OSD flashes on every press, not just on changes.
  IpcHandler {
    target: "brightness"

    function up(): void {
      Brightness.step(true);
    }

    function down(): void {
      Brightness.step(false);
    }
  }

  IpcHandler {
    target: "volume"

    function up(): void {
      Volume.step(true);
    }

    function down(): void {
      Volume.step(false);
    }
  }

  IpcHandler {
    target: "lock"

    function lock(): void {
      Bus.lockRequested();
    }

    function secure(): bool {
      return lockScreen.secure;
    }
  }

  IpcHandler {
    target: "clock"

    function refresh(): void {
      Bus.clockRefreshed();
    }
  }

  // `qs ipc call timer start 10m Pasta`; "90s", "10m", "1h30m" or a bare number of minutes.
  // Quickshell IPC has no optional arguments, so a label-less timer is `quick 10m` (or `start
  // 10m ""`). pause, resume, add and cancel take a timer id, 0 for every timer; `list` prints them.
  IpcHandler {
    target: "timer"

    function quick(duration: string): string {
      var id = Timers.start(duration, "");
      return id > 0 ? "started " + id : "not a duration: " + duration;
    }

    function start(duration: string, label: string): string {
      var id = Timers.start(duration, label);
      return id > 0 ? "started " + id : "not a duration: " + duration;
    }

    function pause(id: int): void {
      Timers.pause(id);
    }

    function resume(id: int): void {
      Timers.resume(id);
    }

    function add(id: int, duration: string): void {
      Timers.add(id, duration);
    }

    function cancel(id: int): void {
      Timers.cancel(id);
    }

    function list(): string {
      return Timers.describe();
    }
  }

  IpcHandler {
    target: "pomodoro"

    function start(): void {
      Pomodoro.start();
    }

    function pause(): void {
      Pomodoro.pause();
    }

    function resume(): void {
      Pomodoro.resume();
    }

    function skip(): void {
      Pomodoro.skip();
    }

    function stop(): void {
      Pomodoro.stop();
    }

    function status(): string {
      return Pomodoro.describe();
    }
  }

  // Test and automation hooks for the island's live activities.
  IpcHandler {
    target: "activities"

    // Stand-in satellites: phone, event, alert, build; `clear` removes them.
    function demo(name: string): void {
      if (name === "clear")
        Activities.clearDemos();
      else
        Activities.addDemo(name);
    }

    // The plugged-in moment as if the charger had just gone in: `plug 78 80`.
    // A negative percent shows the real battery.
    function plug(percent: int, minutes: int): void {
      activitySources.plugged.simulatePlug(percent, minutes);
    }

    // The charger as a state change the watcher sees for itself: 1 in, 0 out, -1 the real battery.
    function charger(state: int): void {
      activitySources.plugged.fake = state;
    }

    // A moment with a title, for looking at how they queue.
    function moment(title: string, attention: bool): void {
      Activities.raiseMoment({
        kind: "test",
        attention: attention,
        icon: IconPaths.check,
        title: title,
        subtitle: attention ? "Needs you" : "For your information",
        buttons: [
          {
            text: "Dismiss",
            kind: "primary"
          }
        ]
      });
    }

    function dismissMoments(): void {
      Activities.dismissAllMoments();
    }

    function list(): string {
      return Activities.ordered.map(a => a.key + "\t" + a.kind + (a.pinned ? "\tpinned" : "") + (a.attention ? "\tattention" : "")).join("\n");
    }
  }
}
