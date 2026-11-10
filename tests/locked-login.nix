# The login flow of modules/system/session.nix, end to end on real Hyprland: greetd logs in on
# tty1 without a password and runs uwsm → start-hyprland → Hyprland --locked-cmd lock-session,
# and the Quickshell lock (home/quickshell/Lock/Lock.qml) is the login screen.
#
# Hyprland runs on the VM's virtio-gpu DRM with mesa llvmpipe. alice stands in for Ryan: fish
# as login shell, the real home/quickshell as ~/.config/quickshell, a minimal hyprland.lua
# (the real one is home-manager generated and loads plugins). Covers the tty1 autologin, the
# argv reaching Hyprland through uwsm, the boot lock and a typed unlock, crashes unlocked
# (SIGSEGV) and locked (SIGABRT) coming back locked under the watchdog, logout returning to a
# locked tty1 login, and a lock command that fails leaving the screen black and locked.
#
# Traps: the QEMU display is the only screen, so every screenshot is the real DRM output;
# PIL reads them (extraPythonPackages) to tell black, lock and desktop apart. hyprctl needs the
# instance of the current Hyprland pid; take it from `hyprctl instances -j`, since a crash
# leaves the old instance directory behind. The backdoor shell has DISPLAY=:0, which qs ipc
# matches instances by, so drop it and pass the instance's WAYLAND_DISPLAY. Hyprland's argv
# contains the lock-session path too, so match the script by its bash interpreter. Without
# hyprland-dialog on PATH the safe-mode Hyprland crashes at its first frame. The tty2 round
# trip runs last: here Hyprland never takes the seat back after Ctrl+Alt+F1, keys included.
# Debug loop without the sandbox: build .#checks.x86_64-linux.locked-login.driver and run
# its bin/nixos-test-driver -o <dir> (add --test-script to run a cut-down script).
# Run: nix build .#checks.x86_64-linux.locked-login -L
{pkgs}: let
  user = "alice";
  password = "alice-pw";

  # A colour of its own, so a screenshot tells the unlocked desktop from the lock and from
  # black. hyprland.start runs start-desktop as home/desktop.nix does.
  hyprlandLua = pkgs.writeText "hyprland.lua" ''
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.0 })
    hl.config({
      input = { kb_layout = "us" },
      misc = {
        background_color = "rgba(1f6f4fff)",
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
      },
    })
    hl.on("hyprland.start", function()
      hl.exec_cmd("start-desktop")
    end)
  '';
in
  pkgs.testers.runNixOSTest {
    name = "locked-login";

    extraPythonPackages = p: [p.pillow];

    nodes.machine = {
      config,
      lib,
      pkgs,
      ...
    }: {
      imports = [../modules/system/session.nix];
      _module.args.user = user;

      virtualisation.memorySize = 4096;
      virtualisation.cores = 4;
      virtualisation.qemu.options = ["-vga none" "-device virtio-gpu-pci,xres=1280,yres=800"];

      hardware.graphics.enable = true;
      fonts.packages = [pkgs.inter pkgs.jetbrains-mono];

      # As modules/system/default.nix.
      programs.hyprland = {
        enable = true;
        withUWSM = true;
      };
      programs.fish.enable = true;
      security.pam.services.quickshell-password = {
        unixAuth = true;
        nodelay = true;
      };

      users.users.${user} = {
        isNormalUser = true;
        uid = 1000;
        inherit password;
        shell = pkgs.fish;
        description = "Alice Test";
      };

      # What home-manager links for Ryan.
      systemd.tmpfiles.rules = [
        "d /home/${user}/.config 0755 ${user} users -"
        "d /home/${user}/.config/hypr 0755 ${user} users -"
        "L+ /home/${user}/.config/hypr/hyprland.lua - - - - ${hyprlandLua}"
        "L+ /home/${user}/.config/quickshell - - - - ${../home/quickshell}"
      ];

      environment.systemPackages = [
        pkgs.quickshell
        pkgs.lock-session
        pkgs.start-desktop
        pkgs.grim
        pkgs.jq
      ];
    };

    testScript = ''
      import json, os, shlex, time
      from PIL import Image

      USER = "${user}"
      PASSWORD = "${password}"
      LOCK_SESSION = "${pkgs.lib.getExe pkgs.lock-session}"
      RUNTIME = "/run/user/1000"

      # The backdoor shell has DISPLAY=:0, and qs ipc only talks to instances on the caller's display.
      def as_user(*argv, check=True, extra_env=()):
          cmd = " ".join(
              ["runuser", "-u", USER, "--", "env", "-u", "DISPLAY", f"XDG_RUNTIME_DIR={RUNTIME}", *extra_env]
              + [shlex.quote(a) for a in argv]
          )
          if check:
              return machine.succeed(cmd)
          return machine.execute(cmd)

      def hypr_pids():
          """Every Hyprland the watchdog started that is still alive (the child with --watchdog-fd)."""
          out = machine.succeed("pgrep -u ${user} -f '[-]-watchdog-fd' || true").split()
          return [int(p) for p in out]

      def argv(pid):
          return machine.succeed(f"cat /proc/{pid}/cmdline").split("\0")[:-1]

      def instance(pid):
          out = as_user("hyprctl", "instances", "-j")
          for inst in json.loads(out):
              if inst["pid"] == pid:
                  return inst
          raise Exception(f"no hyprctl instance for pid {pid}: {out}")

      def hyprctl(pid, *args, check=True):
          inst = instance(pid)
          return as_user(
              "hyprctl", *args, check=check,
              extra_env=(f"HYPRLAND_INSTANCE_SIGNATURE={inst['instance']}",),
          )

      def hypr_locked(pid):
          return json.loads(hyprctl(pid, "locked", "-j"))["locked"]

      def qs_secure(pid):
          """The lock of the Quickshell on this Hyprland's display."""
          rc, out = as_user(
              "qs", "ipc", "call", "lock", "secure", check=False,
              extra_env=(f"WAYLAND_DISPLAY={instance(pid)['wl_socket']}",),
          )
          return rc == 0 and out.strip() == "true"

      def qs_main():
          """The shell lock-session started (its PAM worker is a quickshell child of it)."""
          return machine.succeed(
              "systemctl --machine=${user}@.host --user show -p MainPID --value quickshell-shell || true"
          ).strip()

      def wait(pred, what, timeout=90, interval=1):
          deadline = time.time() + timeout
          last = None
          while time.time() < deadline:
              try:
                  v = pred()
                  if v:
                      return v
                  last = v
              except Exception as e:
                  last = e
              time.sleep(interval)
          diag(what)
          raise Exception(f"timed out waiting for {what}: {last}")

      def wait_new_hyprland(old_pids, what, timeout=120):
          def new():
              pids = [p for p in hypr_pids() if p not in old_pids]
              if len(pids) != 1:
                  return None
              # Its control socket is up.
              instance(pids[0])
              return pids[0]
          return wait(new, what, timeout)

      def stats(name):
          img = Image.open(os.path.join(machine.out_dir, name + ".png")).convert("RGB")
          raw = img.tobytes()
          px = [tuple(raw[i:i + 3]) for i in range(0, len(raw), 3)]
          n = len(px)
          nonblack = sum(1 for p in px if max(p) > 12) / n
          desktop = sum(1 for p in px if abs(p[0] - 0x1f) < 8 and abs(p[1] - 0x6f) < 8 and abs(p[2] - 0x4f) < 8) / n
          colours = len(img.getcolors(maxcolors=1 << 20) or [])
          return {"nonblack": round(nonblack, 4), "desktop": round(desktop, 4), "colours": colours}

      def shot(name, settle=3):
          time.sleep(settle)
          machine.screenshot(name)
          s = stats(name)
          print(f"screenshot {name}: {s}")
          return s

      def assert_lock_screen(name):
          s = shot(name)
          # The lock draws the canvas, the clock and the pill: plenty of colour, none of the desktop.
          assert s["desktop"] < 0.01, f"{name} shows the desktop: {s}"
          assert s["nonblack"] > 0.05 and s["colours"] > 50, f"{name} is not the lock screen: {s}"
          return s

      def unlock(pid):
          for attempt in range(3):
              time.sleep(3)
              machine.send_chars(PASSWORD + "\n", delay=0.05)
              try:
                  wait(lambda: not qs_secure(pid) and not hypr_locked(pid), "unlock", timeout=20)
                  return
              except Exception:
                  print(f"unlock attempt {attempt + 1} did not take")
          raise Exception("could not unlock")

      def diag(why):
          print(f"=== diagnostics: {why}")
          for cmd in [
              "loginctl list-sessions --no-legend",
              "ps -eo pid,ppid,user,cgroup:80,args --sort=pid | grep -v '\\[' | tail -n 60",
              "systemctl --machine=${user}@.host --user list-units --no-pager 'wayland-wm*' 'quickshell*' || true",
              "journalctl -b --no-pager -n 120 _UID=1000",
              "journalctl -b --no-pager -n 40 -u greetd",
              "for f in /run/user/1000/hypr/*/hyprland.log; do echo == $f; tail -n 60 $f; done",
              "cat /dev/vcs1 | tr -s ' '",
          ]:
              print(f"--- {cmd}")
              print(machine.execute(cmd)[1])
          try:
              machine.screenshot("diag")
          except Exception as e:
              print("screenshot failed:", e)
          print("=== end")

      def session_ids():
          out = machine.succeed("loginctl list-sessions --no-legend -j")
          return {s["session"]: s for s in json.loads(out)}

      def tty1_session():
          return [s for s in session_ids().values() if s.get("tty") == "tty1" and s["user"] == USER]

      def check_session(pid, safe_mode, locked_flag):
          a = argv(pid)
          print(f"Hyprland {pid} argv: {a}")
          i = a.index("--locked-cmd")
          assert a[i + 1] == LOCK_SESSION, a
          assert ("--safe-mode" in a) == safe_mode, a
          assert ("--locked" in a) == locked_flag, a
          cg = machine.succeed(f"cat /proc/{pid}/cgroup")
          print(f"Hyprland {pid} cgroup: {cg.strip()}")
          assert "wayland-wm@" in cg, cg

      machine.start()

      with subtest("greetd logs in on tty1 and starts Hyprland"):
          wait(tty1_session, "the tty1 autologin session", timeout=120)
          vcs1 = machine.succeed("cat /dev/vcs1")
          print("tty1 text before Hyprland:", repr(vcs1.rstrip()))
          print("tty1 text (squeezed):", " ".join(vcs1.split()))
          pid = wait_new_hyprland([], "Hyprland", timeout=120)
          check_session(pid, safe_mode=False, locked_flag=False)
          print(machine.succeed(f"cat /proc/$(ps -o ppid= {pid} | tr -d ' ')/cmdline | tr '\\0' ' '"))

      with subtest("the session comes up locked by Quickshell"):
          wait(lambda: qs_secure(pid), "Quickshell's lock to be secure", timeout=120)
          assert hypr_locked(pid)
          assert machine.succeed(f"test -e {RUNTIME}/quickshell-secured-{instance(pid)['instance']} && echo ok").strip() == "ok"
          print(machine.succeed("systemctl --machine=${user}@.host --user status quickshell-shell --no-pager | head -n 5"))
          assert_lock_screen("01-boot-locked")

      with subtest("typing the password unlocks"):
          unlock(pid)
          s = shot("04-unlocked")
          assert s["desktop"] > 0.5, f"unlocked desktop not shown: {s}"

      with subtest("an unlocked crash (SIGSEGV) comes back locked under the watchdog"):
          wm_unit = machine.succeed(f"cat /proc/{pid}/cgroup").strip().rsplit("/", 1)[-1]
          old_qs = qs_main()
          machine.succeed(f"kill -SEGV {pid}")
          pid2 = wait_new_hyprland([pid], "the restarted Hyprland", timeout=120)
          # The crash happened unlocked, so the watchdog adds --safe-mode only; --locked-cmd locks it.
          check_session(pid2, safe_mode=True, locked_flag=False)
          assert machine.succeed(f"cat /proc/{pid2}/cgroup").strip().endswith(wm_unit)
          assert hypr_locked(pid2), "restarted Hyprland is not locked"
          shot("05-segv-restart-early", settle=0)
          wait(lambda: qs_secure(pid2) and qs_main() not in ("", "0", old_qs), "a fresh Quickshell lock", timeout=120)
          print("quickshell before/after:", old_qs, qs_main())
          assert_lock_screen("06-segv-restart-locked")

      with subtest("a locked crash (SIGABRT) comes back locked, with --locked"):
          old_qs = qs_main()
          machine.succeed(f"kill -ABRT {pid2}")
          pid3 = wait_new_hyprland([pid, pid2], "the second restarted Hyprland", timeout=120)
          check_session(pid3, safe_mode=True, locked_flag=True)
          assert hypr_locked(pid3)
          wait(lambda: qs_secure(pid3) and qs_main() not in ("", "0", old_qs), "a fresh Quickshell lock", timeout=120)
          print("quickshell before/after:", old_qs, qs_main())
          assert_lock_screen("07-abrt-restart-locked")
          unlock(pid3)
          shot("08-safe-mode-unlocked")

      with subtest("logging out returns to a locked tty1 login"):
          old_sessions = set(session_ids())
          hyprctl(pid3, "dispatch", "hl.dsp.exit()")
          wait(lambda: [s for s in tty1_session() if s["session"] not in old_sessions], "a new tty1 session", timeout=120)
          pid4 = wait_new_hyprland([pid, pid2, pid3], "Hyprland after logout", timeout=120)
          check_session(pid4, safe_mode=False, locked_flag=False)
          wait(lambda: qs_secure(pid4), "the lock after logout", timeout=120)
          assert hypr_locked(pid4)
          assert_lock_screen("09-relogin-locked")
          print("tty1 text after logout:", " ".join(machine.succeed("cat /dev/vcs1").split()))

      with subtest("a failing lock command leaves the screen black and locked"):
          # Break the shell's config for the next login: quickshell starts and finds no shell.qml.
          machine.succeed("ln -sfn /nonexistent /home/${user}/.config/quickshell")
          old_sessions = set(session_ids())
          unlock(pid4)
          hyprctl(pid4, "dispatch", "hl.dsp.exit()")
          wait(lambda: [s for s in tty1_session() if s["session"] not in old_sessions], "a new tty1 session", timeout=120)
          pid5 = wait_new_hyprland([pid, pid2, pid3, pid4], "Hyprland with a broken shell", timeout=120)
          # lock-session gives up after its 10 s accept loop. Hyprland discards the output of what it
          # spawns, so the sign is the script having exited.
          wait(lambda: machine.succeed("pgrep -u ${user} -f 'bin/[b]ash [^ ]*lock-session/bin/lock-session' || true").strip() == "",
               "lock-session to give up", timeout=60, interval=0.5)
          print(machine.execute("journalctl -b --no-pager _UID=1000 | grep -E 'quickshell\\[' | tail -n 5")[1])
          assert hypr_locked(pid5), "Hyprland unlocked itself after the lock command failed"
          assert not qs_secure(pid5)
          # Within the 15 s of lock-session's hyprctl notify, in case Hyprland draws it over the lock.
          s = shot("10-lock-cmd-failed", settle=1)
          # Black but for the cursor: no desktop and no lock UI.
          assert s["desktop"] == 0 and s["nonblack"] < 0.005, f"screen not black after a failed lock command: {s}"
          # Keys reach nothing: typing the password changes nothing.
          machine.send_chars(PASSWORD + "\n")
          time.sleep(3)
          assert hypr_locked(pid5)
          s = shot("10b-lock-cmd-failed-later", settle=12)
          assert s["desktop"] == 0 and s["nonblack"] < 0.005, s
          print(machine.execute("journalctl -b --no-pager _UID=1000 | grep -E 'lock-session|quickshell' | tail -n 20")[1])

          # Recovery from another VT: lock-session again, with the config back, takes over the lock.
          machine.succeed("ln -sfn ${../home/quickshell} /home/${user}/.config/quickshell")
          inst = instance(pid5)
          as_user(
              LOCK_SESSION,
              extra_env=(
                  f"HYPRLAND_INSTANCE_SIGNATURE={inst['instance']}",
                  f"WAYLAND_DISPLAY={inst['wl_socket']}",
                  "XDG_CURRENT_DESKTOP=Hyprland",
              ),
          )
          assert qs_secure(pid5) and hypr_locked(pid5)
          assert_lock_screen("11-recovered-locked")
          unlock(pid5)
          s = shot("12-recovered-unlocked")
          assert s["desktop"] > 0.5, s

      def enables(pid):
          log = f"{RUNTIME}/hypr/{instance(pid)['instance']}/hyprland.log"
          return int(machine.succeed(f"grep -c 'Enabling seat' {log} || true").strip() or 0)

      def vt_round_trip(pid, name):
          """Ctrl+Alt+F2 from Hyprland, check tty2, Ctrl+Alt+F1 back. Seconds until Hyprland resumed, or None."""
          n = enables(pid)
          machine.send_key("ctrl-alt-f2")
          machine.wait_until_tty_matches("2", "login: ")
          time.sleep(5)
          machine.screenshot(f"{name}-tty2")
          print("tty2 text:", " ".join(machine.succeed("cat /dev/vcs2").split()))
          assert [s for s in session_ids().values() if s.get("tty") == "tty2"] == [], session_ids()
          assert "Password" not in machine.succeed("cat /dev/vcs2")
          assert "automatic login" not in machine.succeed("cat /dev/vcs2")
          t0 = time.time()
          machine.send_key("ctrl-alt-f1")
          wait(lambda: machine.succeed("cat /sys/class/tty/tty0/active").strip() == "tty1", "tty1 to be active again", timeout=20)
          deadline = time.time() + 20
          while time.time() < deadline:
              if enables(pid) > n:
                  return round(time.time() - t0, 1)
              time.sleep(0.5)
          return None

      # Last, because in this VM Hyprland 0.56.2 does not take the seat back after the round trip
      # (with or without the lock up), which leaves the keyboard dead for anything after it.
      with subtest("tty2 asks for a password and does not log in by itself"):
          print(machine.succeed("systemctl cat getty@tty2.service | grep ExecStart="))
          as_user("qs", "ipc", "call", "lock", "lock", extra_env=(f"WAYLAND_DISPLAY={instance(pid5)['wl_socket']}",))
          wait(lambda: qs_secure(pid5), "the manual lock", timeout=30)
          resumed = vt_round_trip(pid5, "13-locked")
          print(f"VT return to the locked session: Hyprland took the seat back after {resumed} s")
          assert qs_secure(pid5) and hypr_locked(pid5)
          shot("14-locked-after-vt-return")
          if resumed is None:
              print("WARNING: Hyprland did not take the seat back after Ctrl+Alt+F1; keys cannot reach the lock")
          else:
              unlock(pid5)
              shot("15-unlocked-after-vt-return")
    '';
  }
