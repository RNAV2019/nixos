"""KDE Connect as JSON lines, for the shell's Services/Phone.qml.

  phone-bridge events   watch kdeconnectd on the session bus and print the whole picture as
                        one JSON object per line, again whenever anything in it changes:
                        {"event": "state", "daemon": true, "devices": [{id, name, type,
                        reachable, paired, pairRequested, verification, link, addresses, battery:
                        {charge, charging} | null, notifications: [{id, app, title, text,
                        time, icon, dismissable}]}]}
  phone-bridge adb ADDRESS...
                        the serial of the adb device (wireless debugging) at one of the phone's
                        addresses, or nothing; exit 1 when there is none
  phone-bridge shot SERIAL FILE
                        one adb screencap of that device, written to FILE atomically
  phone-bridge clip     what `wl-paste --watch` runs per clipboard change: read the new text
                        from stdin, print {"event": "clip", "text": ..., "secret": ...}

Only devices that are paired and reachable, or are asking to pair, are listed. Quickshell has
no D-Bus client, which is why this exists; the buttons on the phone card call kdeconnectd
directly (busctl), so nothing here writes.
"""

import asyncio
import json
import os
import subprocess
import sys
import time

from dbus_fast import BusType, Message, MessageType
from dbus_fast.aio import MessageBus

NAME = "org.kde.kdeconnect"
ROOT = "/modules/kdeconnect"
I_DAEMON = "org.kde.kdeconnect.daemon"
I_DEVICE = "org.kde.kdeconnect.device"
I_BATTERY = "org.kde.kdeconnect.device.battery"
I_NOTIFS = "org.kde.kdeconnect.device.notifications"
I_NOTIF = "org.kde.kdeconnect.device.notifications.notification"

# How many of a phone's notifications are passed on, and how much of a clip.
MAX_NOTIFICATIONS = 20
MAX_CLIP = 2000

LINKS = {"LAN": "Wi-Fi", "Bluetooth (beta)": "Bluetooth", "Bluetooth": "Bluetooth"}


def log(*args):
    print(*args, file=sys.stderr, flush=True)


def plain(value):
    """A dbus-fast Variant, unwrapped."""
    return value.value if hasattr(value, "signature") and hasattr(value, "value") else value


class Bridge:
    def __init__(self, bus):
        self.bus = bus
        self.dirty = asyncio.Event()
        # (device, public id) -> properties; dropped on removal or update.
        self.notifs = {}
        # (device, public id) -> when it was posted or last updated, seconds.
        self.posted = {}
        self.last = None

    async def call(self, path, iface, member, signature="", body=(), dest=NAME):
        reply = await self.bus.call(
            Message(
                destination=dest,
                path=path,
                interface=iface,
                member=member,
                signature=signature,
                body=list(body),
            )
        )
        if reply.message_type == MessageType.ERROR:
            raise RuntimeError(f"{iface}.{member}: {reply.body}")
        return reply.body

    async def props(self, path, iface):
        (all_props,) = await self.call(
            path, "org.freedesktop.DBus.Properties", "GetAll", "s", [iface]
        )
        return {k: plain(v) for k, v in all_props.items()}

    # ---- the picture ----

    async def notification(self, dev, pub):
        key = (dev, pub)
        if key not in self.notifs:
            self.notifs[key] = await self.props(f"{ROOT}/devices/{dev}/notifications/{pub}", I_NOTIF)
        return self.notifs[key]

    async def notifications(self, dev):
        path = f"{ROOT}/devices/{dev}/notifications"
        (ids,) = await self.call(path, I_NOTIFS, "activeNotifications")
        out = []
        for pub in ids:
            try:
                p = await self.notification(dev, pub)
            except Exception:
                continue
            if p.get("silent"):
                continue
            icon = p.get("iconPath") or ""
            posted = self.posted.get((dev, pub))
            out.append(
                {
                    "id": pub,
                    "app": p.get("appName") or "",
                    "title": p.get("title") or "",
                    "text": p.get("text") or p.get("ticker") or "",
                    "time": int(posted * 1000) if posted else None,
                    "icon": icon if p.get("hasIcon") and icon else "",
                    "dismissable": bool(p.get("dismissable")),
                }
            )
        out.sort(key=lambda n: n["time"] or 0, reverse=True)
        for pub in [k for k in self.notifs if k[0] == dev and k[1] not in ids]:
            self.notifs.pop(pub, None)
            self.posted.pop(pub, None)
        return out[:MAX_NOTIFICATIONS]

    async def device(self, dev):
        p = await self.props(f"{ROOT}/devices/{dev}", I_DEVICE)
        reachable = bool(p.get("isReachable"))
        paired = bool(p.get("isPaired"))
        asking = bool(p.get("isPairRequestedByPeer"))
        if not ((paired and reachable) or asking):
            return None
        links = [LINKS.get(n, n) for n in p.get("activeProviderNames") or []]
        d = {
            "id": dev,
            "name": p.get("name") or "",
            "type": p.get("type") or "",
            "reachable": reachable,
            "paired": paired,
            "pairRequested": asking,
            "verification": p.get("verificationKey") or "",
            "link": links[0] if links else "",
            "addresses": [a.removeprefix("::ffff:") for a in p.get("reachableAddresses") or []],
            "battery": None,
            "notifications": [],
        }
        if paired and reachable:
            try:
                b = await self.props(f"{ROOT}/devices/{dev}/battery", I_BATTERY)
                if b.get("hasBattery") and b.get("charge", -1) >= 0:
                    d["battery"] = {"charge": int(b["charge"]), "charging": bool(b.get("isCharging"))}
            except Exception:
                pass
            try:
                d["notifications"] = await self.notifications(dev)
            except Exception:
                pass
        return d

    async def snapshot(self):
        try:
            (ids,) = await self.call(ROOT, I_DAEMON, "devices", "bb", [False, False])
        except Exception:
            return {"event": "state", "daemon": False, "devices": []}
        devices = []
        for dev in sorted(ids):
            try:
                d = await self.device(dev)
            except Exception as err:
                log("device", dev, err)
                continue
            if d is not None:
                devices.append(d)
        return {"event": "state", "daemon": True, "devices": devices}

    # ---- signals ----

    def on_message(self, msg):
        if msg.message_type != MessageType.SIGNAL:
            return
        path = msg.path or ""
        if msg.member == "NameOwnerChanged":
            if msg.body and msg.body[0] == NAME:
                self.notifs.clear()
                self.dirty.set()
            return
        if not path.startswith(ROOT):
            return
        if msg.member in ("notificationPosted", "notificationUpdated") and msg.body:
            dev = path.split("/")[4] if path.count("/") >= 4 else ""
            self.posted[(dev, msg.body[0])] = time.time()
            self.notifs.pop((dev, msg.body[0]), None)
        elif msg.member == "notificationRemoved" and msg.body:
            dev = path.split("/")[4] if path.count("/") >= 4 else ""
            self.notifs.pop((dev, msg.body[0]), None)
        self.dirty.set()

    async def run(self):
        self.bus.add_message_handler(self.on_message)
        for rule in (
            f"type='signal',sender='{NAME}'",
            "type='signal',sender='org.freedesktop.DBus',member='NameOwnerChanged',"
            f"arg0='{NAME}'",
        ):
            await self.call(
                "/org/freedesktop/DBus",
                "org.freedesktop.DBus",
                "AddMatch",
                "s",
                [rule],
                dest="org.freedesktop.DBus",
            )
        # Asking for the devices starts kdeconnectd through its D-Bus service file if it is not
        # running; when it cannot be started the answer is "daemon: false" and we ask again.
        while True:
            state = await self.snapshot()
            line = json.dumps(state, separators=(",", ":"), sort_keys=True)
            if line != self.last:
                self.last = line
                print(line, flush=True)
            if state["daemon"]:
                await self.dirty.wait()
            else:
                try:
                    await asyncio.wait_for(self.dirty.wait(), 10)
                except asyncio.TimeoutError:
                    pass
            # A burst of signals (a phone posting several notifications) is one look.
            await asyncio.sleep(0.08)
            self.dirty.clear()


async def events():
    bus = await MessageBus(bus_type=BusType.SESSION).connect()
    await Bridge(bus).run()


# ---- the clipboard ----


def clip():
    text = sys.stdin.read()
    secret = False
    try:
        types = subprocess.run(
            ["wl-paste", "--list-types"], capture_output=True, text=True, timeout=2
        ).stdout.split()
        # Password managers mark what they copy; it is never shown on a card.
        secret = "x-kde-passwordManagerHint" in types
    except Exception:
        pass
    print(
        json.dumps(
            {"event": "clip", "text": "" if secret else text[:MAX_CLIP], "secret": secret},
            separators=(",", ":"),
        ),
        flush=True,
    )


# ---- the optional screen preview ----


def adb(*args, timeout=8):
    return subprocess.run(["adb", *args], capture_output=True, text=True, timeout=timeout).stdout


def adb_serial(addresses):
    """The wireless-debugging device that is at one of `addresses`, by its ip:port serial or,
    for one found by mDNS, the address `adb mdns services` knows it by."""
    want = {a.removeprefix("::ffff:") for a in addresses}
    serials = [
        line.split("\t")[0]
        for line in adb("devices").splitlines()[1:]
        if line.endswith("\tdevice")
    ]
    for serial in serials:
        if serial.rpartition(":")[0] in want:
            return serial
    if any(s.startswith("adb-") for s in serials):
        for line in adb("mdns", "services").splitlines():
            parts = line.split("\t")
            if len(parts) < 3 or parts[2].rpartition(":")[0] not in want:
                continue
            for serial in serials:
                if serial == parts[0] or serial.startswith(parts[0] + "."):
                    return serial
    return None


def shot(serial, out):
    os.makedirs(os.path.dirname(out), mode=0o700, exist_ok=True)
    part = out + ".part"
    try:
        with open(part, "wb") as f:
            run = subprocess.run(
                ["adb", "-s", serial, "exec-out", "screencap", "-p"],
                stdout=f,
                stderr=subprocess.DEVNULL,
                timeout=8,
            )
        with open(part, "rb") as f:
            png = f.read(8) == b"\x89PNG\r\n\x1a\n"
        if run.returncode != 0 or not png:
            raise RuntimeError("no screenshot")
        os.replace(part, out)
    except Exception:
        if os.path.exists(part):
            os.remove(part)
        sys.exit(1)


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "events":
        asyncio.run(events())
    elif mode == "clip":
        clip()
    elif mode == "adb":
        serial = adb_serial(sys.argv[2:])
        if serial is None:
            sys.exit(1)
        print(serial)
    elif mode == "shot" and len(sys.argv) == 4:
        shot(sys.argv[2], sys.argv[3])
    else:
        print(__doc__, file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
