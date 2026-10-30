import QtQuick
import Quickshell
import qs.Commons
import qs.Services

// The phone (Services/Phone.qml) as the pinned satellite while it is paired and reachable: its
// battery as the ring, accent; the charging handset when it is on the charger; love at 20 % or
// less on its own battery. And the moment that asks whether to pair when a device requests it.
Scope {
  id: root

  // ---- the satellite ----

  Activity {
    id: act

    kind: "phone"
    key: "phone"
    pinned: true
    active: Phone.connected

    icon: Phone.charging ? IconPaths.smartphoneCharging : IconPaths.smartphone
    ring: Phone.hasBattery ? Phone.charge / 100 : -1
    ringColor: Phone.low ? Theme.love : Theme.accent

    chipColor: Theme.accent
    title: Phone.name
    subtitle: Phone.caption
    value: Phone.hasBattery ? Phone.charge + "%" : ""

    card: Component {
      PhoneCard {}
    }
  }

  // ---- the pairing request ----

  // Moment ids by device id, so a request answered elsewhere (on the phone, or from the
  // notification kdeconnectd shows itself) takes its moment away.
  property var raised: ({})

  readonly property var asking: Phone.pairing

  onAskingChanged: {
    var open = {};
    for (var i = 0; i < asking.length; i++) {
      var d = asking[i];
      open[d.id] = true;
      if (root.raised[d.id] === undefined)
        root.raise(d);
    }
    for (var id in root.raised) {
      if (open[id] !== true) {
        Activities.dismissMoment(root.raised[id]);
        var next = Object.assign({}, root.raised);
        delete next[id];
        root.raised = next;
      }
    }
  }

  function raise(d) {
    var id = d.id;
    var moment = Activities.raiseMoment({
      kind: "phone-pair",
      key: "phone-pair:" + id,
      attention: true,
      icon: IconPaths.smartphone,
      iconColor: Theme.accent,
      title: "Pair with " + (d.name !== "" ? d.name : "a new device") + "?",
      subtitle: d.verification !== "" ? "Check the phone shows " + d.verification : "KDE Connect pairing request",
      dwell: 0,
      buttons: [
        {
          text: "Reject",
          kind: "secondary",
          width: 68,
          action: function () {
            Phone.rejectPairing(id);
          }
        },
        {
          text: "Accept",
          kind: "primary",
          width: 68,
          action: function () {
            Phone.acceptPairing(id);
          }
        }
      ]
    });
    var next = Object.assign({}, root.raised);
    next[id] = moment;
    root.raised = next;
  }
}
