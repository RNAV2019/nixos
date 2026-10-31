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
    {"op": "cellular", "dev", "type", "strength"}      "" and -1 are a phone that sends nothing
    {"op": "share_received", "dev", "url"}             the phone sent a file: shareReceived(url)
    {"op": "sftp", "dev", "grant", "mount"}            whether the phone allows file access, and
                                                       the directory its storage mounts at
    {"op": "job_start", "job", "dev", "direction": "out" | "in", "files": [...], "total",
     "dir", "desktop"}                                 what kdeconnectd's job tracker does when a
    {"op": "job_update", "job", "processed", "percent"}  transfer begins, moves and ends, through
    {"op": "job_end", "job", "code", "message"}          org.kde.JobViewServer's requestView
Every method the shell calls appends "<device> <interface>.<method> <args>" to CALLS_LOG.
"""

import asyncio
import json
import sys

from dbus_fast import BusType, Message, MessageFlag, MessageType, Variant
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


class Connectivity(ServiceInterface):
    def __init__(self, dev):
        super().__init__("org.kde.kdeconnect.device.connectivity_report")
        self.dev = dev

    def c(self):
        return devices[self.dev]["cellular"] or {"type": "", "strength": -1}

    @dbus_property(access=PropertyAccess.READ)
    def cellularNetworkType(self) -> "s":
        return self.c()["type"]

    @dbus_property(access=PropertyAccess.READ)
    def cellularNetworkStrength(self) -> "i":
        return self.c()["strength"]

    @signal()
    def refreshed(self, kind: "s", strength: "i") -> "si":
        return [kind, strength]


class Share(ServiceInterface):
    def __init__(self, dev):
        super().__init__("org.kde.kdeconnect.device.share")
        self.dev = dev

    @method()
    def shareUrls(self, urls: "as"):
        note(self.dev, "share.shareUrls", *urls)

    @signal()
    def shareReceived(self, url: "s") -> "s":
        return url


class Sftp(ServiceInterface):
    def __init__(self, dev):
        super().__init__("org.kde.kdeconnect.device.sftp")
        self.dev = dev

    def d(self):
        return devices[self.dev]

    @method()
    def mountAndWait(self) -> "b":
        note(self.dev, "sftp.mountAndWait")
        d = self.d()
        d["mounted"] = d.get("grant", True)
        return d["mounted"]

    @method()
    def isMounted(self) -> "b":
        return self.d().get("mounted", False)

    @method()
    def mountPoint(self) -> "s":
        return self.d().get("mount", "/tmp/mock-phone") if self.d().get("mounted") else ""

    @method()
    def getMountError(self) -> "s":
        return "" if self.d().get("grant", True) else "Permissions missing: filesystem access"

    @method()
    def unmount(self):
        note(self.dev, "sftp.unmount")
        self.d()["mounted"] = False

    @method()
    def startBrowsing(self) -> "b":
        note(self.dev, "sftp.startBrowsing")
        return True


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

TRACKER = "org.kde.JobViewServer"
# job id -> {"path", "dev", "direction", "dir", "state": the properties sent so far}
jobs = {}


async def tracker_call(path, iface, member, signature, body, wait=True):
    message = Message(
        destination=TRACKER,
        path=path,
        interface=iface,
        member=member,
        signature=signature,
        body=body,
        flags=MessageFlag.NONE if wait else MessageFlag.NO_REPLY_EXPECTED,
    )
    if not wait:
        await bus.send(message)
        return None
    reply = await bus.call(message)
    if reply.message_type == MessageType.ERROR:
        note("tracker.error", member, reply.body)
        return None
    return reply


def typed(props):
    """KDE's tracker sends sizes as t, percent as u, and the rest as strings or booleans."""
    kinds = {"percent": "u", "speed": "t", "elapsedTime": "t", "errorCode": "u", "suspended": "b"}
    out = {}
    for k, v in props.items():
        kind = "b" if isinstance(v, bool) else kinds.get(k) or ("t" if k.startswith(("total", "processed")) else "s")
        out[k] = Variant(kind, v)
    return out


async def job_start(op):
    dev = devices[op["dev"]]
    files = op.get("files", [])
    incoming = op["direction"] == "in"
    folder = op.get("dir", "/tmp/Downloads")
    state = {
        "destUrl": "file://" + folder if incoming else "",
        "title": "Receiving file" if incoming else f"Sending to {dev['name']}",
        "descriptionLabel1": "Source" if incoming else "File",
        "descriptionValue1": dev["name"] if incoming else (files[0] if files else ""),
        "descriptionLabel2": "Destination" if incoming else "",
        "descriptionValue2": f"{folder}/{files[0]}" if incoming and files else "",
        "totalFiles": len(files),
        "processedFiles": 0,
    }
    if op.get("total"):
        state["totalBytes"] = op["total"]
    hints = dict(state) | {"immediate": True}
    reply = await tracker_call(
        "/JobViewServer",
        "org.kde.JobViewServerV2",
        "requestView",
        "sia{sv}",
        [op.get("desktop", "org.kde.kdeconnect.daemon"), 1, typed(hints)],
    )
    if reply is None:
        return
    path = reply.body[0]
    jobs[op["job"]] = {"path": path, "state": state}
    await tracker_call(path, "org.kde.JobViewV3", "update", "a{sv}", [typed(state)], wait=False)
    note("job.start", op["job"], op["direction"], *files)


async def job_update(op):
    job = jobs[op["job"]]
    props = {}
    if "processed" in op:
        props["processedBytes"] = op["processed"]
    if "percent" in op:
        props["percent"] = op["percent"]
    if "files_done" in op:
        props["processedFiles"] = op["files_done"]
    if "file" in op:
        folder = job["state"]["destUrl"].removeprefix("file://")
        props["descriptionValue2" if folder else "descriptionValue1"] = f"{folder}/{op['file']}" if folder else op["file"]
    job["state"].update(props)
    await tracker_call(job["path"], "org.kde.JobViewV3", "update", "a{sv}", [typed(props)], wait=False)


async def job_end(op):
    job = jobs.pop(op["job"])
    await tracker_call(
        job["path"], "org.kde.JobViewV3", "terminate", "usa{sv}", [op.get("code", 0), op.get("message", ""), {}], wait=False
    )
    note("job.end", op["job"], op.get("code", 0))


def on_signal(msg):
    if msg.message_type == MessageType.SIGNAL and msg.member == "cancelRequested":
        for name, job in jobs.items():
            if job["path"] == msg.path:
                note("job.cancelRequested", name)


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
        "connectivity_report": Connectivity(dev),
        "share": Share(dev),
        "sftp": Sftp(dev),
    }
    devices[dev]["ifaces"] = ifaces
    bus.export(base, ifaces["device"])
    for name in ("battery", "findmyphone", "clipboard", "notifications", "connectivity_report", "share", "sftp"):
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
                    "type": "phone",
                    "reachable": True,
                    "paired": True,
                    "pairRequested": False,
                    "verification": "",
                    "links": ["LAN"],
                    "addresses": ["192.168.1.42"],
                    "battery": None,
                    "cellular": None,
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
        elif kind == "cellular":
            d = devices[op["dev"]]
            d["cellular"] = {"type": op["type"], "strength": op.get("strength", -1)}
            d["ifaces"]["connectivity_report"].refreshed(op["type"], d["cellular"]["strength"])
        elif kind == "share_received":
            devices[op["dev"]]["ifaces"]["share"].shareReceived(op["url"])
        elif kind == "sftp":
            d = devices[op["dev"]]
            d["grant"] = op.get("grant", True)
            d["mount"] = op.get("mount", "/tmp/mock-phone")
            d["mounted"] = False
        elif kind in ("job_start", "job_update", "job_end"):
            fn = {"job_start": job_start, "job_update": job_update, "job_end": job_end}[kind]
            asyncio.ensure_future(fn(op))


async def main():
    global bus, daemon
    bus = await MessageBus(bus_type=BusType.SESSION).connect()
    daemon = Daemon()
    bus.export(ROOT, daemon)
    bus.export("/control", Control())
    bus.add_message_handler(on_signal)
    await bus.call(
        Message(
            destination="org.freedesktop.DBus",
            path="/org/freedesktop/DBus",
            interface="org.freedesktop.DBus",
            member="AddMatch",
            signature="s",
            body=["type='signal',member='cancelRequested'"],
        )
    )
    await bus.request_name("org.kde.kdeconnect")
    await bus.request_name("org.mock.Control")
    await asyncio.get_event_loop().create_future()


asyncio.run(main())
