"""A stand-in for kdeconnectd on a private session bus, for tests: the same names, paths and
interfaces phone-bridge and the phone card use, driven from outside, and logging every call.

  mock-kdeconnectd CALLS_LOG        owns org.kde.kdeconnect until killed
  Control: org.mock.Control /control Apply(s json), ops:
    {"op": "device", "id", "name", "type", "reachable", "paired", "pairRequested", "links",
     "verification", "addresses", "battery": {"charge", "charging"} | null}
    {"op": "remove", "id"}
    {"op": "notify", "dev", "id", "app", "title", "text", "dismissable", "silent"}
    {"op": "unnotify", "dev", "id"}
    {"op": "battery", "dev", "charge", "charging"}
Every method the shell calls appends "<device> <interface>.<method> <args>" to CALLS_LOG.
"""

import asyncio
import json
import sys

from dbus_fast import BusType, Variant
from dbus_fast.aio import MessageBus
from dbus_fast.service import PropertyAccess, ServiceInterface, dbus_property, method, signal

ROOT = "/modules/kdeconnect"
CALLS = sys.argv[1] if len(sys.argv) > 1 else "/dev/null"
devices = {}
bus = None


def note(*parts):
    with open(CALLS, "a") as f:
        f.write(" ".join(str(p) for p in parts) + "\n")


class Daemon(ServiceInterface):
    def __init__(self):
        super().__init__("org.kde.kdeconnect.daemon")

    @method()
    def devices(self, onlyReachable: "b", onlyPaired: "b") -> "as":
        return [
            i
            for i, d in devices.items()
            if (d["reachable"] or not onlyReachable) and (d["paired"] or not onlyPaired)
        ]

    @dbus_property(access=PropertyAccess.READ)
    def pairingRequests(self) -> "as":
        return [i for i, d in devices.items() if d["pairRequested"]]

    @signal()
    def deviceListChanged(self):
        pass

    @signal()
    def pairingRequestsChanged(self):
        pass


class Device(ServiceInterface):
    def __init__(self, dev):
        super().__init__("org.kde.kdeconnect.device")
        self.dev = dev

    @dbus_property(access=PropertyAccess.READ)
    def name(self) -> "s":
        return devices[self.dev]["name"]

    @dbus_property(access=PropertyAccess.READ)
    def type(self) -> "s":
        return devices[self.dev]["type"]

    @dbus_property(access=PropertyAccess.READ)
    def isReachable(self) -> "b":
        return devices[self.dev]["reachable"]

    @dbus_property(access=PropertyAccess.READ)
    def isPaired(self) -> "b":
        return devices[self.dev]["paired"]

    @dbus_property(access=PropertyAccess.READ)
    def isPairRequestedByPeer(self) -> "b":
        return devices[self.dev]["pairRequested"]

    @dbus_property(access=PropertyAccess.READ)
    def verificationKey(self) -> "s":
        return devices[self.dev]["verification"]

    @dbus_property(access=PropertyAccess.READ)
    def reachableAddresses(self) -> "as":
        return devices[self.dev]["addresses"]

    @dbus_property(access=PropertyAccess.READ)
    def activeProviderNames(self) -> "as":
        return devices[self.dev]["links"]

    @method()
    def acceptPairing(self):
        note(self.dev, "device.acceptPairing")
        d = devices[self.dev]
        d["pairRequested"], d["paired"] = False, True
        changed()

    @method()
    def cancelPairing(self):
        note(self.dev, "device.cancelPairing")
        devices[self.dev]["pairRequested"] = False
        changed()

    @signal()
    def pairStateChanged(self, state: "i") -> "i":
        return state


class Battery(ServiceInterface):
    def __init__(self, dev):
        super().__init__("org.kde.kdeconnect.device.battery")
        self.dev = dev

    def b(self):
        return devices[self.dev]["battery"] or {"charge": -1, "charging": False}

    @dbus_property(access=PropertyAccess.READ)
    def charge(self) -> "i":
        return self.b()["charge"]

    @dbus_property(access=PropertyAccess.READ)
    def isCharging(self) -> "b":
        return self.b()["charging"]

    @dbus_property(access=PropertyAccess.READ)
    def hasBattery(self) -> "b":
        return devices[self.dev]["battery"] is not None

    @signal()
    def refreshed(self, charging: "b", charge: "i") -> "bi":
        return [charging, charge]


class FindMyPhone(ServiceInterface):
    def __init__(self, dev):
        super().__init__("org.kde.kdeconnect.device.findmyphone")
        self.dev = dev

    @method()
    def ring(self):
        note(self.dev, "findmyphone.ring")


class Clipboard(ServiceInterface):
    def __init__(self, dev):
        super().__init__("org.kde.kdeconnect.device.clipboard")
        self.dev = dev

    @method()
    def sendClipboard(self):
        note(self.dev, "clipboard.sendClipboard")


class Notifications(ServiceInterface):
    def __init__(self, dev):
        super().__init__("org.kde.kdeconnect.device.notifications")
        self.dev = dev

    @method()
    def activeNotifications(self) -> "as":
        return list(devices[self.dev]["notifications"])

    @signal()
    def notificationPosted(self, publicId: "s") -> "s":
        return publicId

    @signal()
    def notificationRemoved(self, publicId: "s") -> "s":
        return publicId

    @signal()
    def notificationUpdated(self, publicId: "s") -> "s":
        return publicId


class Notification(ServiceInterface):
    def __init__(self, dev, pub):
        super().__init__("org.kde.kdeconnect.device.notifications.notification")
        self.dev, self.pub = dev, pub

    def n(self):
        return devices[self.dev]["notifications"][self.pub]

    @dbus_property(access=PropertyAccess.READ)
    def appName(self) -> "s":
        return self.n()["app"]

    @dbus_property(access=PropertyAccess.READ)
    def title(self) -> "s":
        return self.n()["title"]

    @dbus_property(access=PropertyAccess.READ)
    def text(self) -> "s":
        return self.n()["text"]

    @dbus_property(access=PropertyAccess.READ)
    def ticker(self) -> "s":
        return self.n()["title"]

    @dbus_property(access=PropertyAccess.READ)
    def iconPath(self) -> "s":
        return self.n().get("icon", "")

    @dbus_property(access=PropertyAccess.READ)
    def hasIcon(self) -> "b":
        return bool(self.n().get("icon"))

    @dbus_property(access=PropertyAccess.READ)
    def dismissable(self) -> "b":
        return self.n().get("dismissable", True)

    @dbus_property(access=PropertyAccess.READ)
    def silent(self) -> "b":
        return self.n().get("silent", False)

    @method()
    def dismiss(self):
        note(self.dev, "notification.dismiss", self.pub)
        devices[self.dev]["notifications"].pop(self.pub, None)
        bus.unexport(f"{ROOT}/devices/{self.dev}/notifications/{self.pub}")
        devices[self.dev]["ifaces"]["notifications"].notificationRemoved(self.pub)


daemon = None


def changed():
    daemon.deviceListChanged()
    daemon.pairingRequestsChanged()


def ensure(dev):
    if "ifaces" in devices[dev]:
        return
    base = f"{ROOT}/devices/{dev}"
    ifaces = {
        "device": Device(dev),
        "battery": Battery(dev),
        "findmyphone": FindMyPhone(dev),
        "clipboard": Clipboard(dev),
        "notifications": Notifications(dev),
    }
    devices[dev]["ifaces"] = ifaces
    bus.export(base, ifaces["device"])
    for name in ("battery", "findmyphone", "clipboard", "notifications"):
        bus.export(f"{base}/{name}", ifaces[name])


class Control(ServiceInterface):
    def __init__(self):
        super().__init__("org.mock.Control")

    @method()
    def Apply(self, spec: "s"):
        op = json.loads(spec)
        kind = op["op"]
        if kind == "device":
            d = devices.setdefault(
                op["id"],
                {
                    "name": "",
                    "type": "smartphone",
                    "reachable": True,
                    "paired": True,
                    "pairRequested": False,
                    "verification": "",
                    "links": ["LAN"],
                    "addresses": ["192.168.1.42"],
                    "battery": None,
                    "notifications": {},
                },
            )
            d.update({k: v for k, v in op.items() if k != "op" and k != "id"})
            ensure(op["id"])
            changed()
        elif kind == "remove":
            devices.pop(op["id"], None)
            changed()
        elif kind == "notify":
            d = devices[op["dev"]]
            fresh = op["id"] not in d["notifications"]
            d["notifications"][op["id"]] = {
                k: op.get(k, "") for k in ("app", "title", "text", "icon")
            } | {"dismissable": op.get("dismissable", True), "silent": op.get("silent", False)}
            if fresh:
                bus.export(
                    f"{ROOT}/devices/{op['dev']}/notifications/{op['id']}",
                    Notification(op["dev"], op["id"]),
                )
                d["ifaces"]["notifications"].notificationPosted(op["id"])
            else:
                d["ifaces"]["notifications"].notificationUpdated(op["id"])
        elif kind == "unnotify":
            d = devices[op["dev"]]
            d["notifications"].pop(op["id"], None)
            bus.unexport(f"{ROOT}/devices/{op['dev']}/notifications/{op['id']}")
            d["ifaces"]["notifications"].notificationRemoved(op["id"])
        elif kind == "battery":
            d = devices[op["dev"]]
            d["battery"] = {"charge": op["charge"], "charging": op.get("charging", False)}
            d["ifaces"]["battery"].refreshed(d["battery"]["charging"], op["charge"])


async def main():
    global bus, daemon
    bus = await MessageBus(bus_type=BusType.SESSION).connect()
    daemon = Daemon()
    bus.export(ROOT, daemon)
    bus.export("/control", Control())
    await bus.request_name("org.kde.kdeconnect")
    await bus.request_name("org.mock.Control")
    await asyncio.get_event_loop().create_future()


asyncio.run(main())
