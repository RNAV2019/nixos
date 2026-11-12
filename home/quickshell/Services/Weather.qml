pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// The weather where the machine is, for the island's hover card: the temperature and what the
// sky is doing, from Open-Meteo, which asks for no key. The place is private, so it is never
// in the config: `qs ipc call weather set <lat> <lon>` keeps it in the state dir, `clear` forgets
// it, and with none stored nothing is fetched and `available` stays false. Read again every
// quarter of an hour, when the machine wakes and when the place changes; a reading that cannot
// be renewed is kept for two hours and then dropped.
Singleton {
  id: root

  readonly property bool available: root.located && root.reading !== null
  // Whole degrees Celsius.
  readonly property int temperature: root.reading ? root.reading.temperature : 0
  // The WMO weather code, and whether the sun is up.
  readonly property int code: root.reading ? root.reading.code : 0
  readonly property bool isDay: root.reading ? root.reading.isDay : true
  readonly property string glyph: root.glyphFor(root.code, root.isDay)

  // "lat,lon" as it was given; empty with no place stored.
  readonly property string location: place.value
  readonly property var coordinates: root.parse(root.location)
  readonly property bool located: root.coordinates !== null

  // { temperature, code, isDay } of the last answer, and when it came.
  property var reading: null
  property real readAt: 0

  readonly property int refreshEvery: 15 * 60 * 1000
  readonly property int keepFor: 2 * 60 * 60 * 1000

  // Two decimals are about a kilometre: all a forecast needs, and all the service is told.
  readonly property string url: {
    if (!root.located)
      return "";
    return "https://api.open-meteo.com/v1/forecast?latitude=" + root.coordinates.lat.toFixed(2) + "&longitude=" + root.coordinates.lon.toFixed(2) + "&current=temperature_2m,weather_code,is_day&timezone=auto";
  }

  function parse(text) {
    var parts = String(text).split(",");
    if (parts.length !== 2)
      return null;
    var lat = Number(parts[0]), lon = Number(parts[1]);
    if (parts[0].trim() === "" || parts[1].trim() === "" || isNaN(lat) || isNaN(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180)
      return null;
    return {
      lat: lat,
      lon: lon
    };
  }

  // The WMO code as a Material Symbols name. Only clear and part-cloudy skies have a night form.
  function glyphFor(code, day) {
    if (code === 0)
      return day ? Icons.weatherClear : Icons.weatherClearNight;
    if (code <= 2)
      return day ? Icons.weatherPartCloud : Icons.weatherPartCloudNight;
    if (code === 3)
      return Icons.weatherCloud;
    if (code === 45 || code === 48)
      return Icons.weatherFog;
    if ((code >= 71 && code <= 77) || code === 85 || code === 86)
      return Icons.weatherSnow;
    if (code >= 95)
      return Icons.weatherThunder;
    // Drizzle, rain and showers, and whatever a later table adds.
    return Icons.weatherRain;
  }

  function set(lat, lon) {
    var next = String(lat).trim() + "," + String(lon).trim();
    if (root.parse(next) === null) {
      console.warn("Weather: not a place: " + lat + " " + lon);
      return;
    }
    place.save(next);
  }

  function clear() {
    place.save("");
  }

  function refresh() {
    if (root.located)
      fetch.run();
  }

  // A reading for another place is not this one's.
  onUrlChanged: {
    root.reading = null;
    root.refresh();
  }

  function take(text) {
    var current = null;
    try {
      current = JSON.parse(text).current;
    } catch (e) {}
    if (!current || typeof current.temperature_2m !== "number" || typeof current.weather_code !== "number") {
      root.lost("no reading in the answer");
      return;
    }
    root.reading = {
      temperature: Math.round(current.temperature_2m),
      code: current.weather_code,
      isDay: current.is_day !== 0
    };
    root.readAt = Date.now();
  }

  // Said the way Services/Command.qml says a failure; the last reading stands while it is young.
  function lost(why) {
    console.warn("Weather fetch failed" + (why !== "" ? ": " + why : ""));
    if (root.reading !== null && Date.now() - root.readAt > root.keepFor)
      root.reading = null;
  }

  PersistedValue {
    id: place

    name: "weather-location"
  }

  // curl, never the GUI thread: it gives up by itself after ten seconds, and an answer for a
  // place since changed is dropped (the queued run asks for the new one).
  QueuedProcess {
    id: fetch

    property string errText: ""

    stamp: root.url
    command: ["curl", "--silent", "--show-error", "--fail", "--max-time", "10", root.url]

    stdout: StdioCollector {
      onStreamFinished: if (!fetch.stale && text.trim() !== "")
        root.take(text)
    }

    stderr: StdioCollector {
      onStreamFinished: fetch.errText = text.trim()
    }

    onExited: function (code) {
      if (!fetch.stale && code !== 0)
        root.lost("curl (" + code + ")" + (fetch.errText !== "" ? ": " + fetch.errText : ""));
    }
  }

  Timer {
    interval: root.refreshEvery
    repeat: true
    running: root.located
    onTriggered: root.refresh()
  }

  // Back from sleep the reading is as old as the sleep was.
  Connections {
    target: Bus

    function onClockRefreshed() {
      if (root.reading !== null && Date.now() - root.readAt > root.keepFor)
        root.reading = null;
      root.refresh();
    }
  }
}
