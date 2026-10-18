"""A silent MPRIS player that is always halfway through the same track.

Gives the island and control centre a now-playing card to show; nothing is played.
usage: mpris-player.py ART_PATH
"""

import asyncio
import sys
import time

from dbus_next import Variant
from dbus_next.aio import MessageBus
from dbus_next.service import PropertyAccess, ServiceInterface, dbus_property, method

LENGTH = 214_000_000  # microseconds
START = 78_000_000
ART = "file://" + sys.argv[1]
t0 = time.monotonic()


class Root(ServiceInterface):
    def __init__(self):
        super().__init__("org.mpris.MediaPlayer2")

    @dbus_property(access=PropertyAccess.READ)
    def Identity(self) -> "s":
        return "Showcase"

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
    def SupportedUriSchemes(self) -> "as":
        return []

    @dbus_property(access=PropertyAccess.READ)
    def SupportedMimeTypes(self) -> "as":
        return []


class Player(ServiceInterface):
    def __init__(self):
        super().__init__("org.mpris.MediaPlayer2.Player")

    @method()
    def PlayPause(self):
        pass

    @method()
    def Play(self):
        pass

    @method()
    def Pause(self):
        pass

    @method()
    def Next(self):
        pass

    @method()
    def Previous(self):
        pass

    @method()
    def Seek(self, offset: "x"):
        pass

    @method()
    def SetPosition(self, track: "o", position: "x"):
        pass

    @dbus_property(access=PropertyAccess.READ)
    def PlaybackStatus(self) -> "s":
        return "Playing"

    @dbus_property(access=PropertyAccess.READ)
    def Metadata(self) -> "a{sv}":
        return {
            "mpris:trackid": Variant("o", "/org/mpris/MediaPlayer2/Track/1"),
            "mpris:length": Variant("x", LENGTH),
            "mpris:artUrl": Variant("s", ART),
            "xesam:title": Variant("s", "Clair de Lune"),
            "xesam:artist": Variant("as", ["Claude Debussy"]),
            "xesam:album": Variant("s", "Suite bergamasque"),
        }

    @dbus_property(access=PropertyAccess.READ)
    def Position(self) -> "x":
        return min(LENGTH, START + int((time.monotonic() - t0) * 1_000_000))

    @dbus_property(access=PropertyAccess.READ)
    def Rate(self) -> "d":
        return 1.0

    @dbus_property(access=PropertyAccess.READ)
    def MinimumRate(self) -> "d":
        return 1.0

    @dbus_property(access=PropertyAccess.READ)
    def MaximumRate(self) -> "d":
        return 1.0

    @dbus_property(access=PropertyAccess.READ)
    def Volume(self) -> "d":
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
    bus = await MessageBus().connect()
    bus.export("/org/mpris/MediaPlayer2", Root())
    bus.export("/org/mpris/MediaPlayer2", Player())
    await bus.request_name("org.mpris.MediaPlayer2.showcase")
    await asyncio.get_running_loop().create_future()


asyncio.run(main())
