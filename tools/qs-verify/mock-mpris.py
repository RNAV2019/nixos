"""A stand-in for a music player on the harness's private session bus: an MPRIS player with four
tracks that the shell's own media controls drive: two with a cover each, one whose title and
artist are too long for any line, and one with no cover.

  mock-mpris.py ART_URL [ART_URL_2]     owns org.mpris.MediaPlayer2.qsv until killed

It starts playing the first track 1:36 into its 2:32. PlayPause, Play, Pause, Stop, Next,
Previous, Seek and SetPosition do what they say (Next and Previous step round the tracks), and
Shuffle and LoopStatus can be written, so everything on the control centre's media card has something to
turn. Driven from a script with busctl, e.g.
  busctl --user call org.mpris.MediaPlayer2.qsv /org/mpris/MediaPlayer2 \
    org.mpris.MediaPlayer2.Player PlayPause
The position stands still unless it is set: the shell runs its own clock between reports.

With QSV_PLAYER=stepped it keeps time as Sonora tells it instead, for the song's clock
(home/quickshell/Services/Lyrics.qml): the track really plays, the position it gives is renewed
once a second, a new track is "Playing" from the moment it is asked for but stands at 0 while it
loads (QSV_LOAD seconds, 1.5 unless said), and nothing says when the loading is over. Where the
track really is can be asked, which no real player answers:
  busctl --user call org.mpris.MediaPlayer2.qsv /org/mpris/MediaPlayer2 \
    org.mpris.MediaPlayer2.Player TruePosition
"""

import asyncio
import os
import sys
import time

from dbus_fast import BusType, Variant
from dbus_fast.aio import MessageBus
from dbus_fast.service import PropertyAccess, ServiceInterface, dbus_property, method, signal

ARTS = sys.argv[1:3] or [""]
TRACKS = [
    {"title": "Glass Harbour", "artist": "Mira Okafor", "album": "Tidewater", "length": 152, "art": ARTS[0]},
    {"title": "Night Bus Home", "artist": "The Lanterns", "album": "Last Stop", "length": 247, "art": ARTS[-1]},
    {
        "title": "The Long Way Round Through Every Town We Used To Know",
        "artist": "An Orchestra With A Rather Long Name And Its Many Friends",
        "album": "Detours",
        "length": 3725,
        "art": ARTS[0],
    },
    {"title": "Untitled Demo", "artist": "Nobody Yet", "album": "", "length": 61, "art": ""},
]
SECOND = 1_000_000  # MPRIS counts in microseconds
STEPPED = os.environ.get("QSV_PLAYER") == "stepped"
LOAD = float(os.environ.get("QSV_LOAD", "1.5"))


class Root(ServiceInterface):
    def __init__(self):
        super().__init__("org.mpris.MediaPlayer2")

    @method()
    def Raise(self):
        pass

    @method()
    def Quit(self):
        pass

    @dbus_property(access=PropertyAccess.READ)
    def CanQuit(self) -> "b":
        return False

    @dbus_property(access=PropertyAccess.READ)
    def CanRaise(self) -> "b":
        return False

    @dbus_property(access=PropertyAccess.READ)
    def HasTrackList(self) -> "b":
        return False

    @dbus_property(access=PropertyAccess.READ)
    def Identity(self) -> "s":
        return "qs-verify player"

    @dbus_property(access=PropertyAccess.READ)
    def DesktopEntry(self) -> "s":
        return "Music"

    @dbus_property(access=PropertyAccess.READ)
    def SupportedUriSchemes(self) -> "as":
        return []

    @dbus_property(access=PropertyAccess.READ)
    def SupportedMimeTypes(self) -> "as":
        return []


class Player(ServiceInterface):
    def __init__(self):
        super().__init__("org.mpris.MediaPlayer2.Player")
        self.track = 0
        self.status = "Playing"
        self.position = 96 * SECOND
        self.shuffle = False
        self.loop = "None"
        # Stepped: the track was at `base` seconds when the clock read `since`, and has run on
        # from there while playing (a `since` still to come is a track still loading).
        self.base = 96.0
        self.since = time.monotonic()

    def true(self):
        if self.status != "Playing":
            return self.base
        return self.base + max(0.0, time.monotonic() - self.since)

    def settle(self, base, wait=0.0):
        """Stepped: the track is at `base` now, and what it gives as its position says so."""
        self.base = base
        self.since = time.monotonic() + wait
        self.position = int(base * SECOND)

    async def step(self):
        """Stepped: renews the position given each time the track passes a whole second."""
        while True:
            at = self.true()
            if int(at) != self.position // SECOND:
                self.position = int(at * SECOND)
            await asyncio.sleep(0.02)

    def metadata(self):
        t = TRACKS[self.track]
        data = {
            "mpris:trackid": Variant("o", f"/org/qsv/track/{self.track}"),
            "mpris:length": Variant("x", t["length"] * SECOND),
            "xesam:title": Variant("s", t["title"]),
            "xesam:artist": Variant("as", [t["artist"]]),
            "xesam:album": Variant("s", t["album"]),
        }
        if t["art"]:
            data["mpris:artUrl"] = Variant("s", t["art"])
        return data

    def tell(self, **changed):
        self.emit_properties_changed(changed)

    def play(self, status):
        if status != self.status:
            if STEPPED:
                at = self.true()
                self.status = status
                self.settle(at)
            self.status = status
            self.tell(PlaybackStatus=status)

    def skip(self, by):
        self.track = (self.track + by) % len(TRACKS)
        if STEPPED:
            self.settle(0.0, LOAD)
            self.tell(Metadata=self.metadata())
            return
        self.position = 0
        self.tell(Metadata=self.metadata())
        self.Seeked(0)

    @method()
    def Next(self):
        self.skip(1)

    @method()
    def Previous(self):
        self.skip(-1)

    @method()
    def Pause(self):
        self.play("Paused")

    @method()
    def PlayPause(self):
        self.play("Paused" if self.status == "Playing" else "Playing")

    @method()
    def Stop(self):
        self.play("Stopped")

    @method()
    def Play(self):
        self.play("Playing")

    @method()
    def Seek(self, offset: "x"):
        if STEPPED:
            self.settle(max(0.0, self.true() + offset / SECOND))
        else:
            self.position = max(0, self.position + offset)
        self.Seeked(self.position)

    @method()
    def SetPosition(self, track: "o", position: "x"):
        if STEPPED:
            self.settle(max(0.0, position / SECOND))
        else:
            self.position = max(0, position)
        self.Seeked(self.position)

    @method()
    def TruePosition(self) -> "x":
        return int(self.true() * SECOND) if STEPPED else self.position

    @method()
    def OpenUri(self, uri: "s"):
        pass

    @signal()
    def Seeked(self, position: "x") -> "x":
        return position

    @dbus_property(access=PropertyAccess.READ)
    def PlaybackStatus(self) -> "s":
        return self.status

    @dbus_property()
    def LoopStatus(self) -> "s":
        return self.loop

    @LoopStatus.setter
    def LoopStatus(self, value: "s"):
        self.loop = value
        self.tell(LoopStatus=value)

    @dbus_property()
    def Rate(self) -> "d":
        return 1.0

    @Rate.setter
    def Rate(self, value: "d"):
        pass

    @dbus_property()
    def Shuffle(self) -> "b":
        return self.shuffle

    @Shuffle.setter
    def Shuffle(self, value: "b"):
        self.shuffle = value
        self.tell(Shuffle=value)

    @dbus_property(access=PropertyAccess.READ)
    def Metadata(self) -> "a{sv}":
        return self.metadata()

    @dbus_property()
    def Volume(self) -> "d":
        return 1.0

    @Volume.setter
    def Volume(self, value: "d"):
        pass

    @dbus_property(access=PropertyAccess.READ)
    def Position(self) -> "x":
        return self.position

    @dbus_property(access=PropertyAccess.READ)
    def MinimumRate(self) -> "d":
        return 1.0

    @dbus_property(access=PropertyAccess.READ)
    def MaximumRate(self) -> "d":
        return 1.0

    @dbus_property(access=PropertyAccess.READ)
    def CanGoNext(self) -> "b":
        return True

    @dbus_property(access=PropertyAccess.READ)
    def CanGoPrevious(self) -> "b":
        return True

    @dbus_property(access=PropertyAccess.READ)
    def CanPlay(self) -> "b":
        return True

    @dbus_property(access=PropertyAccess.READ)
    def CanPause(self) -> "b":
        return True

    @dbus_property(access=PropertyAccess.READ)
    def CanSeek(self) -> "b":
        return True

    @dbus_property(access=PropertyAccess.READ)
    def CanControl(self) -> "b":
        return True


async def main():
    bus = await MessageBus(bus_type=BusType.SESSION).connect()
    bus.export("/org/mpris/MediaPlayer2", Root())
    player = Player()
    bus.export("/org/mpris/MediaPlayer2", player)
    await bus.request_name("org.mpris.MediaPlayer2.qsv")
    if STEPPED:
        asyncio.get_event_loop().create_task(player.step())
    await asyncio.get_event_loop().create_future()


asyncio.run(main())
