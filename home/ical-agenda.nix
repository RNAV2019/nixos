{pkgs}:
# The calendar's backend. It replaces gcalcli, whose OAuth client and refresh token lived
# in a config folder of its own; a secret iCal address is one line in secrets/secrets.yaml.
#
# The output is deliberately the TSV gcalcli printed, header row and all, so the QML
# service parses it exactly as before.
pkgs.writers.writePython3Bin "ical-agenda" {
  libraries = with pkgs.python3Packages; [icalendar recurring-ical-events];
} ''
  """Print a tab-separated agenda from Google Calendar secret iCal feeds."""

  import argparse
  import datetime
  import hashlib
  import os
  import pathlib
  import re
  import sys
  import urllib.error
  import urllib.request

  import icalendar
  import recurring_ical_events

  COLUMNS = [
      "start_date",
      "start_time",
      "end_date",
      "end_time",
      "title",
      "calendar",
      "location",
  ]

  # Feeds are cached on disk for this long; --refresh asks for current
  # data.
  CACHE_SECONDS = 600

  FETCH_TIMEOUT = 20


  def fail(message):
      print("ical-agenda: " + message, file=sys.stderr)
      raise SystemExit(1)


  def config_home():
      return pathlib.Path(
          os.environ.get("XDG_CONFIG_HOME")
          or (pathlib.Path.home() / ".config")
      )


  def cache_home():
      return pathlib.Path(
          os.environ.get("XDG_CACHE_HOME")
          or (pathlib.Path.home() / ".cache")
      )


  def read_urls():
      """The secret addresses, one per line. Blank lines and # are comments."""
      path = pathlib.Path(
          os.environ.get("QS_CALENDAR_URLS")
          or (config_home() / "quickshell-calendar" / "ical-urls")
      )
      try:
          raw = path.read_text(encoding="utf-8")
      except OSError:
          raw = ""

      urls = []
      for line in raw.splitlines():
          line = line.strip()
          if line and not line.startswith("#"):
              urls.append(line)

      if not urls:
          fail("no calendar addresses in " + str(path))
      return urls


  def fetch(url, refresh):
      """The feed's text, from the cache when it is fresh enough."""
      key = hashlib.sha256(url.encode("utf-8")).hexdigest()
      cached = cache_home() / "quickshell" / "ical" / (key + ".ics")

      if not refresh:
          try:
              age = datetime.datetime.now().timestamp() - cached.stat().st_mtime
              if age < CACHE_SECONDS:
                  return cached.read_text(encoding="utf-8")
          except OSError:
              pass

      try:
          with urllib.request.urlopen(url, timeout=FETCH_TIMEOUT) as response:
              body = response.read().decode("utf-8", "replace")
      except (urllib.error.URLError, OSError, ValueError) as error:
          fail("could not fetch " + url + ": " + str(error))

      # Written through a neighbour, so a fetch that dies half way leaves
      # no truncated feed.
      try:
          cached.parent.mkdir(parents=True, exist_ok=True)
          partial = cached.with_suffix(".part")
          partial.write_text(body, encoding="utf-8")
          partial.replace(cached)
      except OSError:
          pass

      return body


  def one_line(value):
      """A field the TSV can carry: no tabs, no newlines, no double spaces."""
      return re.sub(r"\s+", " ", str(value or "")).strip()


  def local(moment):
      """A datetime in the machine's own zone, so days land where they read."""
      if moment.tzinfo is None:
          return moment
      return moment.astimezone()


  def render(component, name):
      start = component.get("DTSTART").dt
      end_field = component.get("DTEND")
      end = end_field.dt if end_field is not None else start

      # An all-day event is the one whose DTSTART is a plain date. gcalcli
      # left both times empty and the QML service still reads it that way.
      all_day = not isinstance(start, datetime.datetime)

      if all_day:
          start_date, start_time = start, ""
          end_date, end_time = end, ""
      else:
          start, end = local(start), local(end)
          start_date = start.date()
          start_time = start.strftime("%H:%M")
          end_date = end.date()
          end_time = end.strftime("%H:%M")

      return {
          "start_date": start_date.isoformat(),
          "start_time": start_time,
          "end_date": end_date.isoformat(),
          "end_time": end_time,
          "title": one_line(component.get("SUMMARY")),
          "calendar": name,
          "location": one_line(component.get("LOCATION")),
      }


  def calendar_name(feed):
      # Google names the feed; a hand-rolled .ics need not. The shell's
      # per-calendar colour only has to be stable, not meaningful.
      return one_line(feed.get("X-WR-CALNAME")) or "Calendar"


  def day(text, label):
      try:
          return datetime.date.fromisoformat(text)
      except ValueError:
          fail(label + " is not a YYYY-MM-DD date: " + text)


  def main():
      parser = argparse.ArgumentParser(
          prog="ical-agenda",
          description=__doc__,
      )
      parser.add_argument(
          "--refresh",
          action="store_true",
          help="re-download the feeds instead of using the cache",
      )
      parser.add_argument("start", help="first day of the window, YYYY-MM-DD")
      parser.add_argument("end", help="last day of the window, inclusive")
      args = parser.parse_args()

      # The window is inclusive at both ends: a month with a week of
      # padding either side.
      first = day(args.start, "start")
      last = day(args.end, "end")
      if last < first:
          fail("the window ends before it starts")
      window_end = last + datetime.timedelta(days=1)

      rows = []
      for url in read_urls():
          feed = icalendar.Calendar.from_ical(fetch(url, args.refresh))
          name = calendar_name(feed)
          occurrences = recurring_ical_events.of(feed).between(
              first, window_end
          )
          for component in occurrences:
              rows.append(render(component, name))

      rows.sort(key=lambda row: (row["start_date"], row["start_time"]))

      out = sys.stdout
      print("\t".join(COLUMNS), file=out)
      for row in rows:
          print("\t".join(row[column] for column in COLUMNS), file=out)


  main()
''
