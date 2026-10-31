"""KDE Connect as JSON lines, for the shell's Services/Phone.qml.

  phone-bridge events   watch kdeconnectd on the session bus and print the whole picture as
                        one JSON object per line, again whenever anything in it changes:
                        {"event": "state", "daemon": true, "devices": [{id, name, type,
                        reachable, paired, pairRequested, verification, link, addresses, battery:
                        {charge, charging} | null, cellular: {type, strength} | null,
                        notifications: [{id, app, title, text, time, icon, dismissable}]}]}

  Transfers come on the same stream, one line per change:
                        {"event": "transfer", "phase": "start" | "progress" | "finish",
                        "transfer": {id, protocol: "kdeconnect", direction: "in" | "out", state:
                        "in_progress" | "finished" | "failed" | "cancelled", peer, kind: "files",
                        files, saved_paths, total_bytes, bytes, percent | null, files_total,
                        files_done, error | null, started}}
                        They come from kdeconnectd's job tracker (see JobViews below), and from its
                        share plugin's shareReceived signal for a file nothing tracked.

Only devices that are paired and reachable, or are asking to pair, are listed. Quickshell has
no D-Bus client, which is why this exists; the phone panel's buttons call kdeconnectd
directly (busctl), so nothing here writes, apart from the one extra call
  busctl --user call org.kde.JobViewServer /JobViewServer org.kde.PhoneBridge cancel s ID
which asks the daemon to stop a transfer this process is showing.
"""

import asyncio
import json
import os
import signal
import sys
import time

from dbus_fast import BusType, Message, MessageType, NameFlag, RequestNameReply
from dbus_fast.aio import MessageBus
from dbus_fast.service import ServiceInterface, method, signal as dbus_signal

NAME = "org.kde.kdeconnect"
ROOT = "/modules/kdeconnect"
I_DAEMON = "org.kde.kdeconnect.daemon"
I_DEVICE = "org.kde.kdeconnect.device"
I_BATTERY = "org.kde.kdeconnect.device.battery"
I_CELL = "org.kde.kdeconnect.device.connectivity_report"
I_NOTIFS = "org.kde.kdeconnect.device.notifications"
I_NOTIF = "org.kde.kdeconnect.device.notifications.notification"
I_SHARE = "org.kde.kdeconnect.device.share"

# kdeconnectd has no progress on D-Bus of its own: it reports transfers through KIO's job
# tracker, which (KUiServerV2JobTracker, KDE Frameworks 6) asks whoever owns this name for a
# view per job. Plasma owns it in a Plasma session; here the bridge does, when nobody else does.
JOBVIEW_NAME = "org.kde.JobViewServer"
JOBVIEW_PATH = "/JobViewServer"
# KJob::KilledJobError, what a cancelled job terminates with.
KILLED = 1

# How many of a phone's notifications are passed on.
MAX_NOTIFICATIONS = 20

LINKS = {"LAN": "Wi-Fi", "Bluetooth (beta)": "Bluetooth", "Bluetooth": "Bluetooth"}


def log(*args):
    print(*args, file=sys.stderr, flush=True)


def plain(value):
    """A dbus-fast Variant, unwrapped."""
    return value.value if hasattr(value, "signature") and hasattr(value, "value") else value


# ---- transfers: the job tracker's server ----

# V2 setters name their units; V3's update() has a property for each.
V2_UNITS = {"bytes": "Bytes", "files": "Files", "dirs": "Directories", "items": "Items"}


class Job:
    """One job the tracker asked a view for, as the properties its updates have set."""

    def __init__(self, bridge, serial, desktop, hints):
        self.bridge = bridge
        self.path = f"{JOBVIEW_PATH}/JobView_{serial}"
        self.id = f"kdc:{int(time.time())}:{serial}"
        # Only kdeconnectd's jobs are shown; any other app's are accepted and ignored.
        self.mine = "kdeconnect" in desktop.lower()
        self.props = {}
        self.names = []
        self.paths = []
        self.started = int(time.time())
        self.done = None
        self.views = []
        self.shown = None
        self.last = 0.0
        self.flush = None
        self.update(hints)

    def update(self, props):
        self.props.update({k: plain(v) for k, v in props.items()})
        # The send job names the file in the first description field; the receive job names
        # the file being written, with its whole path, in the second.
        incoming = bool(self.props.get("destUrl"))
        value = self.props.get("descriptionValue2" if incoming else "descriptionValue1") or ""
        if value:
            name = os.path.basename(value)
            if name and name not in self.names:
                self.names.append(name)
                if incoming:
                    self.paths.append(value)
        self.bridge.job_changed(self)

    def terminate(self, code, message):
        self.done = (int(code), message or "")
        self.bridge.job_changed(self)

    def transfer(self):
        p = self.props
        incoming = bool(p.get("destUrl"))
        total = int(p.get("totalBytes") or 0)
        sent = int(p.get("processedBytes") or 0)
        percent = p.get("percent")
        error = None
        state = "in_progress"
        if self.done is not None:
            code, message = self.done
            state = "finished" if code == 0 else "cancelled" if code == KILLED else "failed"
            error = message or None
            if state == "finished":
                percent, sent = 100, max(sent, total)
        # The tracker sends 0 before it knows anything; with no byte total either, that says
        # nothing, so the shell is told there is no reading yet.
        if percent is not None and int(percent) == 0 and total == 0:
            percent = None
        text = " ".join(str(p.get(k) or "") for k in ("title", "descriptionValue1", "descriptionValue2"))
        peer = next((n for n in self.bridge.names.values() if n and n in text), "")
        return {
            "id": self.id,
            "protocol": "kdeconnect",
            "direction": "in" if incoming else "out",
            "state": state,
            "peer": peer,
            "kind": "files",
            "files": list(self.names),
            "saved_paths": list(self.paths) if incoming else [],
            "total_bytes": total,
            "bytes": sent,
            "percent": int(percent) if percent is not None else None,
            "files_total": int(p.get("totalFiles") or 0),
            "files_done": int(p.get("processedFiles") or 0),
            "error": error,
            "started": self.started,
        }


class JobViewV3(ServiceInterface):
    """What KDE Frameworks 6's tracker calls on the view it was given."""

    def __init__(self, job):
        super().__init__("org.kde.JobViewV3")
        self.job = job

    @method()
    def update(self, properties: "a{sv}"):
        self.job.update(properties)

    @method()
    def terminate(self, errorCode: "u", errorMessage: "s", hints: "a{sv}"):
        self.job.terminate(errorCode, errorMessage)

    @dbus_signal()
    def suspendRequested(self):
        pass

    @dbus_signal()
    def resumeRequested(self):
        pass

    @dbus_signal()
    def cancelRequested(self):
        pass


class JobViewV2(ServiceInterface):
    """The same view for the trackers before V3, which set one thing at a time."""

    def __init__(self, job):
        super().__init__("org.kde.JobViewV2")
        self.job = job

    @method()
    def terminate(self, errorMessage: "s"):
        self.job.terminate(KILLED if errorMessage else 0, errorMessage)

    @method()
    def setSuspended(self, suspended: "b"):
        self.job.update({"suspended": suspended})

    @method()
    def setTotalAmount(self, amount: "t", unit: "s"):
        self.job.update({f"total{V2_UNITS.get(unit, 'Items')}": amount})

    @method()
    def setProcessedAmount(self, amount: "t", unit: "s"):
        self.job.update({f"processed{V2_UNITS.get(unit, 'Items')}": amount})

    @method()
    def setPercent(self, percent: "u"):
        self.job.update({"percent": percent})

    @method()
    def setSpeed(self, bytesPerSecond: "t"):
        self.job.update({"speed": bytesPerSecond})

    @method()
    def setElapsedTime(self, elapsedTime: "t"):
        self.job.update({"elapsedTime": elapsedTime})

    @method()
    def setInfoMessage(self, message: "s"):
        self.job.update({"infoMessage": message})

    @method()
    def setDescriptionField(self, number: "u", name: "s", value: "s") -> "b":
        self.job.update({f"descriptionLabel{number + 1}": name, f"descriptionValue{number + 1}": value})
        return True

    @method()
    def clearDescriptionField(self, number: "u"):
        self.job.update({f"descriptionLabel{number + 1}": "", f"descriptionValue{number + 1}": ""})

    @method()
    def setDestUrl(self, destUrl: "v"):
        self.job.update({"destUrl": destUrl})

    @dbus_signal()
    def suspendRequested(self):
        pass

    @dbus_signal()
    def resumeRequested(self):
        pass

    @dbus_signal()
    def cancelRequested(self):
        pass


class JobViewServer(ServiceInterface):
    def __init__(self, bridge):
        super().__init__("org.kde.JobViewServerV2")
        self.bridge = bridge

    @method()
    def requestView(self, desktopEntry: "s", capabilities: "i", hints: "a{sv}") -> "o":
        return self.bridge.new_job(desktopEntry, hints)


class PhoneBridgeControl(ServiceInterface):
    """The one write the shell makes here: stop a transfer it is showing."""

    def __init__(self, bridge):
        super().__init__("org.kde.PhoneBridge")
        self.bridge = bridge

    @method()
    def cancel(self, id: "s"):
        self.bridge.cancel_job(id)


class Bridge:
    def __init__(self, bus):
        self.bus = bus
        # id -> name of every device seen, for naming who a transfer is with.
        self.names = {}
        self.jobs = {}
        self.serial = 0
        # Paths of files a job has written lately, so shareReceived does not list them twice.
        self.saved = {}
        self.serving = False
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

    # ---- transfers ----

    def emit(self, phase, transfer):
        line = {"event": "transfer", "phase": phase, "transfer": transfer}
        print(json.dumps(line, separators=(",", ":"), sort_keys=True), flush=True)

    async def serve(self):
        """Own the tracker's name, unless another server (Plasma's) already does."""
        if self.serving:
            return
        reply = await self.bus.request_name(JOBVIEW_NAME, NameFlag.DO_NOT_QUEUE)
        if reply != RequestNameReply.PRIMARY_OWNER:
            log(f"{JOBVIEW_NAME} is owned elsewhere: transfers will not be shown")
            return
        self.bus.export(JOBVIEW_PATH, JobViewServer(self))
        self.bus.export(JOBVIEW_PATH, PhoneBridgeControl(self))
        self.serving = True

    async def release(self):
        if self.serving:
            self.serving = False
            try:
                await self.bus.release_name(JOBVIEW_NAME)
            except Exception:
                pass

    def new_job(self, desktop, hints):
        self.serial += 1
        job = Job(self, self.serial, desktop, hints)
        self.jobs[job.path] = job
        job.views = [JobViewV3(job), JobViewV2(job)]
        for view in job.views:
            self.bus.export(job.path, view)
        return job.path

    def job_changed(self, job):
        if not job.mine:
            if job.done is not None:
                self.drop(job)
            return
        t = job.transfer()
        for path in t["saved_paths"]:
            self.saved[path] = time.time()
        if job.done is not None:
            self.drop(job)
            self.emit("finish", t)
        elif job.last == 0.0:
            job.last = time.monotonic()
            job.shown = t
            self.emit("start", t)
        else:
            self.throttle(job)

    def throttle(self, job):
        """Progress at most every 200 ms; the reading that lands inside the gap goes after it."""
        if job.flush is not None:
            return
        wait = job.last + 0.2 - time.monotonic()
        if wait <= 0:
            self.progress(job)
            return

        def later():
            job.flush = None
            if job.done is None:
                self.progress(job)

        job.flush = asyncio.get_event_loop().call_later(wait, later)

    def progress(self, job):
        job.last = time.monotonic()
        t = job.transfer()
        if t != job.shown:
            job.shown = t
            self.emit("progress", t)

    def drop(self, job):
        if job.flush is not None:
            job.flush.cancel()
        self.jobs.pop(job.path, None)
        self.bus.unexport(job.path)

    def cancel_job(self, id):
        for job in self.jobs.values():
            if job.id == id:
                for view in job.views:
                    view.cancelRequested()

    def received(self, dev, url):
        """A file arrived. When a tracked job wrote it, the job already said so."""
        path = url[7:] if url.startswith("file://") else url
        if any(p == path for p in self.saved) or any(path in j.paths for j in self.jobs.values()):
            return
        self.saved[path] = time.time()
        now = int(time.time())
        self.emit(
            "finish",
            {
                "id": f"kdc:file:{now}:{abs(hash(path)) % 100000}",
                "protocol": "kdeconnect",
                "direction": "in",
                "state": "finished",
                "peer": self.names.get(dev, ""),
                "kind": "files",
                "files": [os.path.basename(path)],
                "saved_paths": [path],
                "total_bytes": 0,
                "bytes": 0,
                "percent": 100,
                "files_total": 1,
                "files_done": 1,
                "error": None,
                "started": now,
            },
        )

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
        self.names[dev] = p.get("name") or ""
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
            "cellular": None,
            "notifications": [],
        }
        if paired and reachable:
            try:
                b = await self.props(f"{ROOT}/devices/{dev}/battery", I_BATTERY)
                if b.get("hasBattery") and b.get("charge", -1) >= 0:
                    d["battery"] = {"charge": int(b["charge"]), "charging": bool(b.get("isCharging"))}
            except Exception:
                pass
            # The phone's mobile network: "5G", "LTE"... and 0-4 bars; -1 bars is no signal
            # report yet, and an empty type is no SIM. The plugin is off on some phones.
            try:
                c = await self.props(f"{ROOT}/devices/{dev}/connectivity_report", I_CELL)
                kind = c.get("cellularNetworkType") or ""
                if kind:
                    d["cellular"] = {"type": kind, "strength": int(c.get("cellularNetworkStrength", -1))}
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
            elif msg.body and msg.body[0] == JOBVIEW_NAME and not msg.body[2]:
                asyncio.ensure_future(self.serve())
            return
        if not path.startswith(ROOT):
            return
        if msg.interface == I_SHARE and msg.member == "shareReceived" and msg.body:
            dev = path.split("/")[4] if path.count("/") >= 4 else ""
            self.received(dev, msg.body[0])
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
            "type='signal',sender='org.freedesktop.DBus',member='NameOwnerChanged',"
            f"arg0='{JOBVIEW_NAME}'",
        ):
            await self.call(
                "/org/freedesktop/DBus",
                "org.freedesktop.DBus",
                "AddMatch",
                "s",
                [rule],
                dest="org.freedesktop.DBus",
            )
        await self.serve()
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
    bridge = Bridge(bus)
    task = asyncio.ensure_future(bridge.run())
    # Let go of the tracker's name on the way out, so a Plasma session could take it over.
    for sig in (signal.SIGTERM, signal.SIGINT):
        asyncio.get_event_loop().add_signal_handler(sig, task.cancel)
    try:
        await task
    except asyncio.CancelledError:
        pass
    finally:
        await bridge.release()


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "events":
        asyncio.run(events())
    else:
        print(__doc__, file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
