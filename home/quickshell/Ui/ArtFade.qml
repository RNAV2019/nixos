import QtQuick
import qs.Commons

// A picture that changes without a cut. A new `source` loads behind the one on screen, which
// is held until the new one is ready and then covered by it on a fade; a source that goes
// away, or fails, fades out the same way. `presence` is how much picture there is, 0 with
// none and 1 with one: the owner fades this item (or what it feeds, like a blur) by it, over
// whatever it draws when there is no picture.
Item {
  id: root

  property string source: ""
  property int fillMode: Image.PreserveAspectCrop
  // The size the picture is decoded at; left empty, its own.
  property size sourceSize: Qt.size(0, 0)

  readonly property bool hasArt: source !== "" && art.status === Image.Ready
  readonly property real presence: leaving ? 1 - mix : carrying ? 1 : mix

  // The fade's clock, 0 to 1: the new picture over the held one, a first picture in, or the
  // held one out.
  property real mix: 0
  // The picture before is held under the one arriving.
  property bool carrying: false
  // There is no picture to come: the held one is on its way out.
  property bool leaving: false
  property bool armed: false
  // The source of the picture that has wholly arrived.
  property string settled: ""

  function sync() {
    fade.stop();
    // What is on screen now is what the next one covers. One still loading was never seen, so
    // whatever is already held stays.
    if (art.status === Image.Ready && art.source.toString() !== "") {
      held.source = art.source;
      carrying = true;
      leaving = false;
    } else if (leaving && root.source !== "") {
      // A picture after all, while the last was on its way out: it stays for this one to cover.
      carrying = true;
      leaving = false;
    }
    mix = 0;
    art.source = root.source;
    if (root.source === "")
      root.leave();
  }

  function leave() {
    carrying = false;
    if (held.source.toString() === "")
      return;
    leaving = true;
    mix = 0;
    fade.restart();
  }

  onSourceChanged: {
    if (armed)
      sync();
  }

  Component.onCompleted: {
    armed = true;
    sync();
  }

  Image {
    id: held

    // Never a part of its own in a content morph (Ui/MorphScan.js): it is the picture above's past.
    readonly property bool morphIgnore: true

    anchors.fill: parent
    fillMode: root.fillMode
    cache: true
    visible: source.toString() !== ""
  }

  Image {
    id: art

    anchors.fill: parent
    fillMode: root.fillMode
    asynchronous: true
    cache: true
    opacity: root.carrying ? root.mix : 1
    visible: status === Image.Ready

    onStatusChanged: {
      if (status === Image.Ready) {
        // The same picture again, reloaded for its window's device-pixel ratio (a window's first
        // map at a fractional scale): it is up already, and does not fade in a second time.
        if (source.toString() === root.settled && !root.carrying && !root.leaving) {
          root.mix = 1;
          return;
        }
        root.leaving = false;
        root.mix = 0;
        fade.restart();
      } else if (status === Image.Error) {
        root.leave();
      }
    }
  }

  Binding {
    target: held
    property: "sourceSize"
    value: root.sourceSize
    when: root.sourceSize.width > 0
  }

  Binding {
    target: art
    property: "sourceSize"
    value: root.sourceSize
    when: root.sourceSize.width > 0
  }

  NumberAnimation {
    id: fade

    target: root
    property: "mix"
    from: 0
    to: 1
    duration: Theme.duration(Theme.tintFade)
    easing.type: Easing.OutQuad

    onFinished: {
      held.source = "";
      root.carrying = false;
      if (root.leaving) {
        root.leaving = false;
        root.mix = 0;
        root.settled = "";
      } else {
        root.settled = art.source.toString();
      }
    }
  }
}
