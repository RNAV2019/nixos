"""A stand-in for a music player on the harness's private session bus: an MPRIS player with four
tracks that the shell's own media controls drive: two with a cover each, one whose title and
artist are too long for any line, and one with no cover.

  mock-mpris.py ART_URL [ART_URL_2]     owns org.mpris.MediaPlayer2.qsv until killed

It starts playing the first track 1:36 into its 2:32. PlayPause, Play, Pause, Stop, Next,
Previous, Seek and SetPosition do what they say (Next and Previous step round the tracks), and
Shuffle and LoopStatus can be written, so everything in the Now playing panel has something to
turn. Driven from a script with busctl, e.g.
  busctl --user call org.mpris.MediaPlayer2.qsv /org/mpris/MediaPlayer2 \
    org.mpris.MediaPlayer2.Player PlayPause
The position stands still unless it is set: the shell runs its own clock between reports.
"""

import asyncio
import sys

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
            self.status = status
            self.tell(PlaybackStatus=status)

    def skip(self, by):
        self.track = (self.track + by) % len(TRACKS)
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
        self.position = max(0, self.position + offset)
        self.Seeked(self.position)

    @method()
    def SetPosition(self, track: "o", position: "x"):
        self.position = max(0, position)
        self.Seeked(self.position)

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
    bus.export("/org/mpris/MediaPlayer2", Player())
    await bus.request_name("org.mpris.MediaPlayer2.qsv")
    await asyncio.get_event_loop().create_future()


asyncio.run(main())
