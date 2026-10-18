# Calendar backend reading secret iCal URLs. Prints the same TSV gcalcli did, which
# the QML service parses.
{
  writers,
  python3Packages,
}:
writers.writePython3Bin "ical-agenda" {
  libraries = with python3Packages; [icalendar recurring-ical-events];
} (builtins.readFile ./ical-agenda.py)
