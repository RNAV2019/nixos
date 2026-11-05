"""A stand-in media player on the private session bus, for tests: org.mpris.MediaPlayer2.mock,
playing a four-minute track at 90 s, so the control centre's media card has a player.

  mock-mpris.py [Playing|Paused]    owns the name until killed

The position is fixed (MPRIS never pushes it; the shell counts on from what it read).
"""

import asyncio
import sys

from dbus_fast import BusType, Variant
from dbus_fast.aio import MessageBus
from dbus_fast.service import PropertyAccess, ServiceInterface, dbus_property, method

STATUS = sys.argv[1] if len(sys.argv) > 1 else "Playing"


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
        return "Mock Player"


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
    def Stop(self):
        pass

    @method()
    def Seek(self, offset: "x"):
        pass

    @method()
    def SetPosition(self, track: "o", position: "x"):
        pass

    @dbus_property(access=PropertyAccess.READ)
    def PlaybackStatus(self) -> "s":
        return STATUS

    @dbus_property(access=PropertyAccess.READ)
    def Metadata(self) -> "a{sv}":
        return {
            "mpris:trackid": Variant("o", "/org/mock/track/1"),
            "mpris:length": Variant("x", 240_000_000),
            "xesam:title": Variant("s", "Mock Track"),
            "xesam:artist": Variant("as", ["Mock Artist"]),
            "xesam:album": Variant("s", "Mock Album"),
        }

    @dbus_property(access=PropertyAccess.READ)
    def Position(self) -> "x":
        return 90_000_000

    @dbus_property(access=PropertyAccess.READ)
    def Volume(self) -> "d":
        return 1.0

    @dbus_property(access=PropertyAccess.READ)
    def Rate(self) -> "d":
        return 1.0

    @dbus_property(access=PropertyAccess.READ)
    def CanControl(self) -> "b":
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
    def CanGoNext(self) -> "b":
        return True

    @dbus_property(access=PropertyAccess.READ)
    def CanGoPrevious(self) -> "b":
        return True


async def main():
    bus = await MessageBus(bus_type=BusType.SESSION).connect()
    bus.export("/org/mpris/MediaPlayer2", Root())
    bus.export("/org/mpris/MediaPlayer2", Player())
    await bus.request_name("org.mpris.MediaPlayer2.mock")
    await asyncio.get_event_loop().create_future()


asyncio.run(main())
