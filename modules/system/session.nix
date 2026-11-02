# greetd logs in on tty1 without a password and starts Hyprland, which locks before its
# first frame and runs the lock screen. The lock screen is the login screen.
{
  config,
  lib,
  pkgs,
  user,
  ...
}: {
  services.greetd = {
    enable = true;
    # default_session rather than initial_session: leaving Hyprland logs straight back in
    # to the lock screen, not to a greeter.
    settings.default_session = {
      inherit user;
      # Hyprland's own start-hyprland is a crash watchdog: it restarts a crashed Hyprland
      # with these arguments again, so the restarted session comes back locked too. uwsm
      # refuses arguments for desktop entries, so the compositor is given as a command line.
      # greetd runs it through sh on tty1, and uwsm logs to the journal anyway.
      command =
        lib.escapeShellArgs [
          (lib.getExe config.programs.uwsm.package)
          "start"
          "-e"
          "-D"
          "Hyprland"
          "-N"
          "Hyprland"
          "--"
          "${config.programs.hyprland.package}/bin/start-hyprland"
          "--"
          "--locked-cmd"
          (lib.getExe pkgs.lock-session)
        ]
        + " >/dev/null 2>&1";
    };
  };

  # Holding the power key for about 5 s powers off; Hyprland binds a short press to
  # lock-session. logind's "lock" action skips this greetd default_session, whose class
  # is greeter. The default powers off on any press.
  services.logind.settings.Login = {
    HandlePowerKey = "ignore";
    HandlePowerKeyLongPress = "poweroff";
  };
}
