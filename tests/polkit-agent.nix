# The shell's polkit agent (home/quickshell/Services/Polkit.qml, Auth/AuthPrompt.qml) against a
# real polkitd and a real PAM stack, in a VM so it can register for a session of its own: polkit
# allows one agent per session, and on the desktop that session is Ryan's.
#
# alice logs in on tty1 (a logind session), her profile starts a headless sway and the shell in
# it. `pkcheck --allow-user-interaction` stands in for pkexec (the requester), and wtype types
# the answers into the prompt. Covers a right password, a wrong one then a right one, Cancel,
# Escape, another identity, the requester dying, and the session locking under an open prompt.
# Run: nix build .#checks.x86_64-linux.polkit-agent -L
{pkgs}: let
  # The shell with no Hyprland to ask which output has the focus.
  shell = pkgs.runCommand "quickshell-polkit-test-config" {} ''
    cp -r ${../home/quickshell} $out
    chmod -R u+w $out
    sed -i 's/return screen !== null && Hyprland.focusedMonitor !== null && Hyprland.focusedMonitor.name === screen.name;/return true;/' $out/Commons/Monitors.qml
    grep -q 'return true;' $out/Commons/Monitors.qml
  '';

  swayConfig = pkgs.writeText "sway-polkit-test.conf" ''
    output HEADLESS-1 mode 1920x1080
    default_border none
    exec ${startShell}
  '';

  # Lock.qml locks a fresh shell unless the compositor has marked the session secured.
  startShell = pkgs.writeShellScript "start-shell" ''
    : > "$XDG_RUNTIME_DIR/quickshell-secured-$HYPRLAND_INSTANCE_SIGNATURE"
    exec ${pkgs.quickshell}/bin/quickshell -p ${shell} > /tmp/quickshell.log 2>&1
  '';
in
  pkgs.testers.runNixOSTest {
    name = "polkit-agent";

    nodes.machine = {pkgs, ...}: {
      virtualisation.memorySize = 3072;
      virtualisation.cores = 4;

      security.polkit.enable = true;
      hardware.graphics.enable = true;
      fonts.packages = [pkgs.inter pkgs.jetbrains-mono];

      # Two administrators, so the prompt has an identity to choose. polkit's admin identities
      # are the wheel group.
      users.users.alice = {
        isNormalUser = true;
        extraGroups = ["wheel"];
        password = "alice-pw";
        description = "Alice Test";
      };
      users.users.bob = {
        isNormalUser = true;
        extraGroups = ["wheel"];
        password = "bob-pw";
        description = "Bob Test";
      };

      # alice's session: a tty autologin, which logind makes a session of its own.
      services.getty.autologinUser = "alice";
      programs.bash.loginShellInit = ''
        if [ "$(tty)" = /dev/tty1 ]; then
          export WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1
          export HYPRLAND_INSTANCE_SIGNATURE=vmtest
          exec ${pkgs.sway}/bin/sway -c ${swayConfig}
        fi
      '';

      environment.systemPackages = [pkgs.sway pkgs.grim pkgs.wtype pkgs.quickshell pkgs.jq];
    };

    testScript = ''
      import json, time

      ENV = "XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1"
      QS = "${pkgs.quickshell}/bin/quickshell ipc -p ${shell} call authpreview"

      def as_alice(cmd):
          return machine.succeed(f"su alice -s /bin/sh -c '{ENV} {cmd}'")

      def status():
          return json.loads(as_alice(f"{QS} status"))

      def wait_status(pred, what, timeout=30):
          deadline = time.time() + timeout
          last = None
          while time.time() < deadline:
              try:
                  last = status()
                  if pred(last):
                      return last
              except Exception as e:
                  last = str(e)
              time.sleep(0.5)
          raise Exception(f"timed out waiting for {what}: {last}")

      def prompt_up():
          """The prompt is open and has had time to be drawn and take the keyboard."""
          st = wait_status(lambda s: s["pending"] and s["shown"], "the prompt")
          time.sleep(2)
          return st

      def keys(*names):
          # wtype's first key of a call can be lost in a headless compositor; lead with a Shift tap.
          args = " ".join(f"-k {n}" for n in ("Shift_L",) + names)
          as_alice(f"${pkgs.wtype}/bin/wtype -d 30 {args}")

      def type_text(text):
          as_alice(f"${pkgs.wtype}/bin/wtype -d 30 -k Shift_L {text}")

      def shot(name):
          time.sleep(1.5)
          as_alice(f"${pkgs.grim}/bin/grim /tmp/{name}.png")
          machine.copy_from_machine(f"/tmp/{name}.png")

      counter = [0]

      def request():
          """pkcheck as the requester, from inside alice's session: a process of the sway session."""
          counter[0] += 1
          n = counter[0]
          machine.succeed(
              f"""cat > /tmp/req{n}.sh <<'SCRIPT'
      #!/bin/sh
      pkcheck --action-id org.freedesktop.policykit.exec --process $$ --allow-user-interaction > /tmp/pk{n}.out 2>&1
      echo $? > /tmp/pk{n}.rc
      SCRIPT
      chmod 755 /tmp/req{n}.sh"""
          )
          as_alice(
              "${pkgs.sway}/bin/swaymsg -s $(ls /run/user/1000/sway-ipc.*.sock | head -1) "
              f"exec /tmp/req{n}.sh"
          )
          return n

      def diag(why):
          """What the shell and polkitd think, and the card as it looks, printed for a failed run."""
          print(f"=== diagnostics: {why}")
          try:
              print(status())
          except Exception as e:
              print("status failed:", e)
          print(machine.execute("tail -n 40 /tmp/quickshell.log")[1])
          print(machine.execute("journalctl -b --no-pager | grep -i -E 'pam|polkit|helper|unix_chkpwd|alice' | tail -n 40")[1])
          print(machine.execute("ls -la /run/wrappers/bin/ | head -20; id alice; getent shadow alice | cut -c1-12")[1])
          print(machine.execute("loginctl list-sessions; ls /tmp/pk*.out /tmp/pk*.rc; cat /tmp/pk*.out /tmp/pk*.rc")[1])
          as_alice("${pkgs.grim}/bin/grim /tmp/diag.png")
          print("=== diag.png (base64)")
          print(machine.succeed("base64 -w0 /tmp/diag.png"))
          print("=== end")

      def result(n, timeout=30):
          try:
              machine.wait_for_file(f"/tmp/pk{n}.rc", timeout=timeout)
          except Exception:
              diag(f"request {n} never finished")
              raise
          return int(machine.succeed(f"cat /tmp/pk{n}.rc").strip())

      machine.start()
      machine.wait_for_unit("multi-user.target")
      machine.wait_until_succeeds("loginctl list-sessions --no-legend | grep -q alice", timeout=60)
      machine.wait_until_succeeds("test -S /run/user/1000/wayland-1", timeout=60)

      with subtest("the shell registers its agent for alice's session"):
          st = wait_status(lambda s: s["registered"], "agent registration", timeout=90)
          print(st)

      with subtest("a request opens the prompt; the right password approves it"):
          n = request()
          st = prompt_up()
          assert st["actionId"] == "org.freedesktop.policykit.exec", st
          assert sorted(st["identities"]) == ["alice", "bob"], st
          shot("1-prompt")
          type_text("alice-pw")
          shot("2-typed")
          keys("Return")
          assert result(n) == 0, machine.succeed(f"cat /tmp/pk{n}.out")
          wait_status(lambda s: not s["pending"] and not s["shown"], "the prompt to close")

      with subtest("a wrong password latches the error and asks again; the right one approves"):
          n = request()
          prompt_up()
          type_text("not-the-password")
          keys("Return")
          st = wait_status(lambda s: s["failures"] == 1 and s["error"] != "", "the failure")
          assert st["pending"] and st["shown"], st
          assert not st["checking"], st
          shot("3-failed")
          type_text("alice-pw")
          keys("Return")
          assert result(n) == 0, machine.succeed(f"cat /tmp/pk{n}.out")
          wait_status(lambda s: not s["pending"] and not s["shown"], "the prompt to close")

      with subtest("Cancel with Escape tells the requester no, and closes"):
          n = request()
          prompt_up()
          keys("Escape")
          rc = result(n)
          assert rc != 0, rc
          wait_status(lambda s: not s["pending"] and not s["shown"], "the prompt to close")
          print("pkcheck exit after Escape:", rc)

      with subtest("another administrator can be chosen and authenticates with their own password"):
          n = request()
          prompt_up()
          # Field -> details plate -> identity chooser; Right moves to the next account.
          keys("Tab", "Tab", "Right")
          st = wait_status(lambda s: s["selected"] == 1 and s["pending"], "bob selected")
          # Switching accounts restarts PAM, which AuthFlow reports as a failed try; it is not one.
          assert st["failures"] == 0 and st["error"] == "", st
          shot("4-bob")
          keys("Tab", "Tab", "Tab")
          type_text("bob-pw")
          keys("Return")
          assert result(n) == 0, machine.succeed(f"cat /tmp/pk{n}.out")
          wait_status(lambda s: not s["pending"] and not s["shown"], "the prompt to close")

      with subtest("the requester going away withdraws the prompt"):
          n = request()
          prompt_up()
          machine.succeed("pkill -x pkcheck")
          wait_status(lambda s: not s["pending"] and not s["shown"], "the prompt to withdraw")

      with subtest("locking the session under an open prompt cancels it and the lock shows"):
          n = request()
          prompt_up()
          as_alice("${pkgs.quickshell}/bin/quickshell ipc -p ${shell} call lock lock")
          rc = result(n)
          assert rc != 0, rc
          wait_status(lambda s: not s["pending"] and not s["shown"], "the prompt to close for the lock")
          time.sleep(2)
          shot("5-locked")
          # A request that arrives while locked is refused at once, not queued behind the lock.
          n = request()
          assert result(n) != 0
          assert not status()["pending"]
    '';
  }
