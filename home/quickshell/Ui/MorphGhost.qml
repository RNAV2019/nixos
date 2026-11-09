import QtQuick
import qs.Commons
import "Motion.js" as Motion

// One ghost of a content morph (Ui/MorphLayer.qml): a pair flying from the panel before's anchor
// (`entry.a`) to this panel's (`entry.b`), or a leaver of the panel before, cut where it stands.
// Its parts pair by name and are drawn by Ui/MorphPart.qml. In the window's coordinates.
Item {
  id: ghost

  property var entry
  property int entryIndex: -1
  property var host

  // The pair's progress; a leaver stays where it was.
  // A little ahead of the shape, so a long flight lands with the reveal rather than after it.
  // A carousel's tile quicker still: its neighbours are at their places from the start.
  readonly property real q: entry.out || !host ? 0 : 1 - Math.pow(1 - Math.max(0, Math.min(1, host.progress)), entry.a.role === "carousel" ? 5 : 1.5)

  readonly property var rectA: entry.a.rect
  // Where the pair lands; MorphLayer.refresh() moves it when this panel's layout settles late.
  property var target: entry.b

  readonly property var rectB: target ? target.rect : entry.a.rect
  // A pair that stays put (a moment for a moment, a pill that widens a little where it is; a header
  // centred in a far wider card does travel, on its start edge): its parts
  // change where each side has them rather than riding it (MorphPart).
  readonly property bool inPlace: Motion.travel(rectA, rectB) < 30 && (Math.abs(rectA.x - rectB.x) < 24 || entry.a.role === "pill" || host && host.inPlace)
  // Kept inside the card: a flier heading past the card's growing edge rides that edge instead of
  // being cut by it, as far in from it as it is from the card's edge where it sets off and where it
  // lands, between the two as it goes (a header keeps its padding, not glued to the rim, and is
  // not pushed off where it started).
  // Where it would be with no card to keep inside; `rect` less this is how far the card pushed it.
  readonly property var free: Motion.lerpRect(rectA, rectB, q)
  readonly property var rect: {
    var r = free;
    // Inside another pair it goes where that one goes, wherever the card keeps it.
    var over = host && entry.parentIndex >= 0 ? host.ghostAt(entry.parentIndex) : null;
    if (over)
      return {
        x: r.x + over.rect.x - over.free.x,
        y: r.y + over.rect.y - over.free.y,
        w: r.w,
        h: r.h
      };
    var c = host ? host.cardRect : null;
    if (!c || c.width <= 0 || entry.out)
      return r;
    var e = host.cardEnd, s = host.clockRunning && host.cardBegin.width > 0 ? host.cardBegin : c;
    var pad = function (v) {
      return Math.max(0, Math.min(24, v));
    };
    // The inset on each side, from where it sets off to where it lands.
    var inset = function (ra, rb, side) {
      var at = function (card, r) {
        if (!card || card.width <= 0)
          return 6;
        return pad(side === 0 ? r.x - card.x : side === 1 ? card.x + card.width - r.x - r.w : side === 2 ? r.y - card.y : card.y + card.height - r.y - r.h);
      };
      return Motion.lerp(at(s, ra), at(e, rb), q);
    };
    var l = inset(rectA, rectB, 0), rt = inset(rectA, rectB, 1);
    var tp = inset(rectA, rectB, 2), bt = inset(rectA, rectB, 3);
    var y = Math.min(r.y, c.y + c.height - bt - r.h);
    // Wider than the card just now (a header row on a card still growing): its start edge rides
    // in, and the card's reveal crops the far end.
    var x = Math.max(Math.min(r.x, c.x + c.width - rt - r.w), c.x + l);
    return {
      x: x,
      y: r.h > c.height - tp - bt ? r.y : Math.max(y, Math.min(r.y, c.y + tp)),
      w: r.w,
      h: r.h
    };
  }

  // Whether this pair's own contents, on their way to where they land, still have to cross a part that
  // arrives inside it (a title on its way past the back button it lands beside): that part waits.
  function crossedBy(p) {
    if (!target || inPlace)
      return false;
    var dx = rectA.x - rectB.x, dy = rectA.y - rectB.y;
    return target.parts.some(function (t) {
      if (t.folded || t === p || t.type === "rect" || t.type === "image")
        return false;
      var x0 = Math.min(t.x, t.x + dx), y0 = Math.min(t.y, t.y + dy);
      var x1 = Math.max(t.x, t.x + dx) + t.w, y1 = Math.max(t.y, t.y + dy) + t.h;
      return p.x < x1 && p.x + p.w > x0 && p.y < y1 && p.y + p.h > y0;
    });
  }

  // How far along this pair is once its title (MorphPart), moving across the header from where the old
  // one sat to where the new one lands, has passed a part arriving on its way; 0 if it does not.
  function wordsClear(p) {
    if (!target || entry.a.role !== "header")
      return 0;
    var t = find(target.parts, "text:title"), old = find(entry.a.parts, "text:title");
    if (!t || !old)
      return 0;
    // All of what the part came in with together (a button's disc and its arrow), and a gap to spare.
    var group = p.name.split("/")[0], end = -Infinity;
    target.parts.forEach(function (o) {
      if (o.folded && o.name.split("/")[0] === group)
        end = Math.max(end, o.x - rectB.x + o.w);
    });
    var from = old.x - rectA.x, to = t.x - rectB.x;
    if (to <= from || end <= from || end > to + 2)
      return 0;
    end = Math.min(end + 4, to);
    // The title goes on 1 - (1 - q)^5.
    return 1 - Math.pow(1 - Math.min(1, (end - from) / (to - from)), 0.2);
  }

  // The panel before drew this pair on a plate of its own (a row's card).
  readonly property bool platedA: entry.a.parts.some(function (p) {
    return !p.folded && (p.type === "rect" || p.type === "image") && p.w >= 0.6 * rectA.w && p.h >= 0.5 * rectA.h;
  })

  // A plate both sides draw that changes colour a long way (a chosen tile's fill going): the words on
  // it keep the old ink until it is half way, so they are never dark on dark. Words with no such
  // plate under them each keep their own.
  readonly property bool plateTurns: {
    var b = target ? target.parts : [];
    return entry.a.parts.some(function (p) {
      if (p.type !== "rect" || !p.color)
        return false;
      var o = b.find(function (x) {
        return x.type === "rect" && x.name === p.name && x.color;
      });
      return !!o && Math.abs(p.color.r + p.color.g + p.color.b - o.color.r - o.color.g - o.color.b) > 0.6;
    });
  }

  // The part on each side with a given name and type (null where that side has none).
  // A key is "type:name" for a part both sides draw, "A|type:name" or "B|type:name" for one side's.
  function partA(key) {
    return key.indexOf("B|") === 0 ? null : find(entry.a.parts, key.replace(/^A\|/, ""));
  }

  function partB(key) {
    return !target || key.indexOf("A|") === 0 ? null : find(target.parts, key.replace(/^B\|/, ""));
  }

  // Two parts of one name are the same part only where they sit at about the same place in their
  // anchors and are of about one size: a pill's glyph slot holds other marks in other pills.
  function alike(pa, pb) {
    var ra = entry.a.rect, rb = target.rect;
    var cx = (pa.x + pa.w / 2 - ra.x) / Math.max(1, ra.w) - (pb.x + pb.w / 2 - rb.x) / Math.max(1, rb.w);
    var cy = (pa.y + pa.h / 2 - ra.y) / Math.max(1, ra.h) - (pb.y + pb.h / 2 - rb.y) / Math.max(1, rb.h);
    var big = Math.max(pa.w * pa.h, pb.w * pb.h), small = Math.max(1, Math.min(pa.w * pa.h, pb.w * pb.h));
    // A fill that spans its anchor one way stretches to any size (a pill's track and its level into a
    // slider's, however full); a mark of another size is another mark (a battery's fill, a level dot).
    var spans = pa.type === "rect" && (pa.w >= 0.6 * ra.w && pb.w >= 0.6 * rb.w || pa.h >= 0.6 * ra.h && pb.h >= 0.6 * rb.h);
    return Math.hypot(cx, cy) < 0.3 && (spans || big / small < 4);
  }

  function find(list, key) {
    for (var i = 0; i < list.length; i++)
      if (list[i].type + ":" + list[i].name === key)
        return list[i];
    return null;
  }

  // Parts by name: those both anchors draw, then those only the panel before's does, then
  // those only this panel's does, each list in paint order. Only the names: a re-read of this
  // panel that moves or recolours a part rebinds it in place rather than rebuilding it.
  readonly property var keys: {
    var list = [];
    var a = entry.a.parts, b = target ? target.parts : [];
    var seen = {};
    a.forEach(function (pa) {
      var k = pa.type + ":" + pa.name;
      seen[k] = true;
      list.push(k);
    });
    b.forEach(function (pb) {
      var k = pb.type + ":" + pb.name;
      if (!seen[k])
        list.push(k);
    });
    // Same names that are not alike split into one leaving and one arriving.
    var out = [];
    list.forEach(function (k) {
      var pa = find(a, k), pb = find(b, k);
      if (pa && pb && !ghost.alike(pa, pb))
        out.push("A|" + k, "B|" + k);
      else
        out.push(k);
    });
    return out;
  }

  // The model, replaced only when the names change.
  property var model: []

  onKeysChanged: if (keys.join("|") !== model.join("|"))
    model = keys
  Component.onCompleted: model = keys

  // A leaver is cut: on this surface's first frame it is where the surface before left it, on the
  // next it is gone, with no half-faded frame between. Its parts live on the layer's one paint list
  // (MorphLayer.paint), ordered as the two panels painted them, so they take this through `fade`.
  readonly property real fade: entry.out && host && host.clockRunning && host.clock > Theme.morphCut ? 0 : 1

  // A long flight's backing: the card's own ground under the pair, on the paint list just below its
  // parts, so it hides what it crosses rather than print over it. Invisible where it sets off and
  // lands, on that same ground.
  readonly property bool backed: !entry.out && host && Motion.travel(rectA, rectB) >= Theme.morphBackingTravel
  // It covers what the pair draws, not its whole anchor: a slider's bar, not the row it sits in.
  function drawn(parts, fallback) {
    if (parts.length === 0)
      return fallback;
    var x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
    parts.forEach(function (p) {
      x0 = Math.min(x0, p.x);
      y0 = Math.min(y0, p.y);
      x1 = Math.max(x1, p.x + p.w);
      y1 = Math.max(y1, p.y + p.h);
    });
    return {
      x: x0,
      y: y0,
      w: x1 - x0,
      h: y1 - y0
    };
  }
  readonly property var backing: {
    if (!backed)
      return rect;
    var r = Motion.lerpRect(drawn(entry.a.parts, rectA), drawn(target ? target.parts : [], rectB), q);
    r.x += rect.x - free.x;
    r.y += rect.y - free.y;
    return r;
  }
  readonly property real lowestSeq: {
    var low = Infinity;
    var scan = function (parts) {
      for (var i = 0; i < parts.length; i++)
        low = Math.min(low, parts[i].seq);
    };
    scan(entry.a.parts);
    if (target)
      scan(target.parts);
    return low === Infinity ? 0 : low;
  }

  Rectangle {
    parent: ghost.host ? ghost.host.paint : ghost
    // A pair that leads the panel has nothing under it to hide.
    visible: ghost.backed && !ghost.host.leads(ghost.entry)
    z: ghost.lowestSeq - 0.5
    x: ghost.backing.x
    y: ghost.backing.y
    width: ghost.backing.w
    height: ghost.backing.h
    radius: Math.min(height / 2, Theme.controlTileRadius)
    color: Theme.surface
  }

  // Made, not repeated: the parts live on the paint list, not here, so there is nothing to stack them
  // after.
  Instantiator {
    model: ghost.model

    // A part dropped from the model is deleted later; hidden now, so no frame draws it beside its
    // replacement.
    onObjectRemoved: function (index, object) {
      object.visible = false;
    }

    MorphPart {
      required property var modelData

      parent: ghost.host ? ghost.host.paint : ghost
      z: pb ? pb.seq : pa ? pa.seq : 0
      pa: ghost.partA(modelData)
      pb: ghost.partB(modelData)
      owner: ghost
    }
  }
}
