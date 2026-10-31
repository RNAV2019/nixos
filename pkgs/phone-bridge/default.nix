# KDE Connect's D-Bus as JSON lines for the shell (Services/Phone.qml); see phone-bridge.py.
{
  writers,
  python3Packages,
}:
writers.writePython3Bin "phone-bridge" {
  libraries = [python3Packages.dbus-fast];
  # F821 and F722: dbus-fast reads its D-Bus signatures from string annotations.
  flakeIgnore = ["E501" "F821" "F722"];
} (builtins.readFile ./phone-bridge.py)
