# KDE Connect's D-Bus as JSON lines for the shell (Services/Phone.qml); see phone-bridge.py.
{
  writers,
  python3Packages,
}:
writers.writePython3Bin "phone-bridge" {
  libraries = [python3Packages.dbus-fast];
  flakeIgnore = ["E501"];
} (builtins.readFile ./phone-bridge.py)
