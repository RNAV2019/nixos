import QtQuick
import qs.Commons
import "MorphScan.js" as MorphScan
import "Motion.js" as Motion

// A content morph: the panel before's contents turning into this one's. Panels are windows of
// their own, so pixels cannot cross; the surface handing over reads its contents into plain
// descriptions (Ui/MorphScan.js) and this layer, in the taker's window, redraws them as ghosts.
//
// Pairs (the same key, else the same role in the same slot) fly from where the panel before had
// them to where this one has them, on the shape's own progress. What the panel before had with no
// partner is cut on the frame after this one's first (`Theme.morphCut`). What this one has with no partner arrives in a cascade, held
// back by the mask (Ui/MorphMask.qml), which also hides this panel's own copy of every pair until
// its ghost has landed. Lives in FrostedSurface.ghostData, in the window's coordinates.
Item {
  id: morph

  // The shape's own progress from the surface before to this one (IslandSurfaceBase.shapeProgress),
  // NaN while the shape does not travel (two panels of one size); a spring of the same pace stands
  // in then. Held at 0 until this surface's first frame.
  property real shapeProgress: NaN
  property string label: "morph"
  // False for a swap inside a surface whose shape stays: its shape progress is stale then.
  property bool useShape: true
  // A swap inside one surface: pairs by role and slot whatever their keys (MorphScan.match).
  property bool inPlace: false
  readonly property real progress: !clockRunning ? 0 : useShape && !isNaN(shapeProgress) ? shapeProgress : fallback.value

  ProgressSpring {
    id: fallback

    label: morph.label + ".p"
    target: 1
  }

  property bool running: false

  // Milliseconds since this surface's first frame; the cut and the cascade are timed on it.
  property real clock: 0
  property bool clockRunning: false

  property var pairs: []
  property var outs: []
  property var ins: []
  property var maskEntries: []
  property var entries: []

  // The ghosts have reached this panel's own contents, which take over in the same frame.
  // Not on the first turn of the clock: the shape re-bases a moment after the first frame, and
  // until it has, its progress still reads the rest it was at.
  // (Not before the words and glyphs that change on the clock have: a swap the same size has no
  // shape to wait on, and would otherwise hand over mid-roll.)
  readonly property bool landed: running && clockRunning && clock > Math.max(Theme.morphPillIn + Theme.morphPillRoll, Theme.morphGlyphTravel) && progress >= 0.999
  property bool ghostsDone: false

  readonly property real cascadeEnd: Theme.morphArriveDelay + Theme.morphArriveStep * Theme.morphArriveSteps + Theme.morphArriveFade

  signal finished

  // When each arriving box was first wholly inside the card (MorphMask), keyed by where it is, so a
  // re-read of the panel does not restart a fade already under way.
  property var since: ({})

  // An arrival that waited for the card to reach it fades in from then, not from its turn.
  // When a rank's turn comes. The first two share a beat: the first is often a header the card has not
  // reached, and the card must not sit empty for it.
  function turn(rank) {
    return Theme.morphArriveDelay + Theme.morphArriveStep * Math.min(Math.max(0, rank - 1), Theme.morphArriveSteps);
  }

  function arrivalFrom(rank, t0) {
    var t = morph.clock - Math.max(t0, turn(rank));
    // What waited for a pair leading the panel comes up over a fade that can be seen, late as it is.
    if (t0 > 0 && lead !== null)
      return Math.max(0, Math.min(1, t / Theme.morphWaitedFade));
    var x = Math.max(0, Math.min(1, t / Theme.morphArriveFade));
    return 1 - Math.pow(1 - x, 2);
  }

  function arrival(rank) {
    var t = morph.clock - turn(rank);
    var x = Math.max(0, Math.min(1, t / Theme.morphArriveFade));
    return 1 - Math.pow(1 - x, 2);
  }

  // What the mask draws: each anchor's box, and each loose part outside every anchor (the calendar's
  // days), with the beat each arrives on. {x, y, w, h, rank, paired}.
  function maskFor(to, pairedB) {
    var list = [];
    // Arrivals come in groups, top to bottom: an anchor and all inside it at one beat; loose parts
    // by the row they sit on.
    var groups = [];
    var groupOf = function (a) {
      var top = a;
      while (top.parent && to.indexOf(top.parent) >= 0)
        top = top.parent;
      for (var i = 0; i < groups.length; i++)
        if (groups[i].key === top)
          return groups[i];
      var g = {
        key: top,
        y: top.box.y,
        x: top.box.x + top.box.w / 2,
        entries: []
      };
      groups.push(g);
      return g;
    };
    var loose = [];
    to.forEach(function (a) {
      if (a.rest) {
        a.parts.forEach(function (p) {
          if (p.bx === undefined)
            return;
          var e = {
            x: p.bx,
            y: p.by,
            w: p.w,
            h: p.h,
            rank: 0,
            paired: false
          };
          list.push(e);
          loose.push({
            e: e,
            cy: p.by + p.h / 2,
            cx: p.bx + p.w / 2
          });
        });
      } else if (a.box) {
        var e = {
          x: a.box.x,
          y: a.box.y,
          w: a.box.w,
          h: a.box.h,
          rank: 0,
          paired: morph.held(a, pairedB)
        };
        list.push(e);
        if (!e.paired)
          groupOf(a).entries.push(e);
      }
    });
    // Loose parts make rows by their centre line, so a disc and the numeral on it are one row.
    loose.sort(function (p, q) {
      return p.cy - q.cy;
    });
    var row = null;
    loose.forEach(function (l) {
      if (!row || l.cy - row.cy > 12) {
        row = {
          key: null,
          cy: l.cy,
          y: l.e.y,
          x: l.cx,
          entries: []
        };
        groups.push(row);
      }
      row.y = Math.min(row.y, l.e.y);
      row.entries.push(l.e);
    });

    // Groups make rows by their top edge; a row arrives on one beat, rows top to bottom.
    groups.sort(function (p, q) {
      return p.y - q.y;
    });
    var beat = -1, rowTop = -Infinity;
    groups.forEach(function (g) {
      if (g.y - rowTop > 16) {
        beat++;
        rowTop = g.y;
      }
      g.entries.forEach(function (e) {
        e.rank = beat;
      });
    });
    // A box inside a bigger one that arrives sooner arrives with it: held back alone, it would punch a
    // hole in what is already showing (a numeral in its disc, a phone's screen in its body).
    var arriving = list.filter(function (e) {
      return !e.paired;
    });
    // Biggest first, so a container's own beat is settled before what it holds takes it.
    arriving.sort(function (p, q) {
      return q.w * q.h - p.w * p.h;
    });
    arriving.forEach(function (e) {
      arriving.forEach(function (c) {
        if (c !== e && c.rank < e.rank && c.w * c.h > e.w * e.h && e.x >= c.x - 2 && e.y >= c.y - 2 && e.x + e.w <= c.x + c.w + 2 && e.y + e.h <= c.y + c.h + 2)
          e.rank = c.rank;
      });
    });
    // A row's extent, so all of it waits for a pair leading the panel down, or none.
    var rows = {};
    arriving.forEach(function (e) {
      var r = rows[e.rank] || (rows[e.rank] = {
          top: e.y,
          bottom: e.y + e.h
        });
      r.top = Math.min(r.top, e.y);
      r.bottom = Math.max(r.bottom, e.y + e.h);
    });
    arriving.forEach(function (e) {
      e.rowTop = rows[e.rank].top;
      e.rowBottom = rows[e.rank].bottom;
    });
    return list;
  }

  // An anchor whose pair is still flying in: this panel's copy waits for it. So does what cannot be
  // redrawn inside one (it would show at its landing place while the ghost is still on its way).
  function held(a, pairedB) {
    return pairedB.indexOf(a) >= 0 || pairedAncestor(a, pairedB) !== null;
  }

  // The window-to-content-box offset, for comparing a ghost (window coordinates) with a mask box.
  property point boxOffset: Qt.point(0, 0)

  // The card, in the window's coordinates (set by the surface).
  property rect cardRect: Qt.rect(0, 0, 0, 0)
  // The card once open: where a flier lands is measured from its edges.
  property rect cardEnd: Qt.rect(0, 0, 0, 0)
  // The card when the clock started: where a flier sets off is measured from its edges.
  property rect cardBegin: Qt.rect(0, 0, 0, 0)

  // A pair going a long way down the panel leads it: what it has to cross arrives once it has passed,
  // rather than be crossed.
  function leads(e) {
    return !e.out && e.a.role !== "carousel" && e.parentIndex < 0 && e.b.rect.y - e.a.rect.y >= Theme.morphBackingTravel;
  }

  // Where the leading pair is, in the content box's coordinates: {top}, what it lands in {landTop} and
  // the span it sweeps {x0, x1}. Null if none leads.
  readonly property var lead: {
    if (!running || ghostsDone || !clockRunning)
      return null;
    var l = null;
    for (var i = 0; i < entries.length; i++) {
      if (!leads(entries[i]))
        continue;
      var g = ghostRepeater.itemAt(i);
      if (!g)
        continue;
      var o = boxOffset;
      if (!l)
        l = {
          top: Infinity,
          landTop: Infinity,
          x0: Infinity,
          x1: -Infinity
        };
      l.top = Math.min(l.top, g.rect.y + o.y);
      l.landTop = Math.min(l.landTop, g.rectB.y + o.y);
      l.x0 = Math.min(l.x0, g.rectA.x + o.x, g.rectB.x + o.x);
      l.x1 = Math.max(l.x1, g.rectA.x + g.rectA.w + o.x, g.rectB.x + g.rectB.w + o.x);
    }
    return l;
  }

  // Whether a box in a row of the content box waits for the leading pair: all of a row it crosses, or
  // none, and nothing out of its way to one side. A row comes once the pair is about past it; what lies
  // below where the pair lands, once it is nearly there.
  function aheadOfLead(x, w, top, bottom) {
    var l = lead;
    if (!l || x + w <= l.x0 || x >= l.x1)
      return false;
    if (top >= l.landTop)
      return l.top < l.landTop - Theme.morphLeadBelow;
    return l.top < l.landTop - 12 && bottom - Math.min(24, 0.15 * (bottom - top)) > l.top;
  }

  // Whether a carousel's tile on its way to its place is over a box: a tile with no partner next to it
  // comes once it has room, rather than be crossed.
  function underCarouselTile(x, y, w, h) {
    for (var i = 0; i < entries.length; i++) {
      var e = entries[i];
      if (e.out || e.a.role !== "carousel")
        continue;
      var g = ghostRepeater.itemAt(i);
      if (!g)
        continue;
      var c = g.rect, room = Theme.morphCarouselRoom;
      if (x + room < c.x + boxOffset.x + c.w && x + w - room > c.x + boxOffset.x && y < c.y + boxOffset.y + c.h && y + h > c.y + boxOffset.y)
        return true;
    }
    return false;
  }

  // The ghost of the pair inside this one (a slider's track in its anchor), or null.
  function innerGhost(index) {
    for (var i = 0; i < entries.length; i++)
      if (entries[i].parentIndex === index)
        return ghostRepeater.itemAt(i);
    return null;
  }

  // How much later than its neighbours above a box below where the leading pair lands comes: they go
  // top to bottom rather than all at once.
  function leadStagger(top) {
    var l = lead;
    return l ? Math.max(0, top - l.landTop) * Theme.morphLeadStagger : 0;
  }

  function ghostAt(i) {
    return ghostRepeater.itemAt(i);
  }

  // The nearest ancestor of `x` in `set`, or null.
  function pairedAncestor(x, set) {
    for (var p = x.parent; p; p = p.parent)
      if (set.indexOf(p) >= 0)
        return p;
    return null;
  }

  // An anchor of a pair with every unpaired anchor inside it folded in, as parts of its own: they
  // ride the pair rather than leaving or arriving on their own beside it (a header's buttons with
  // the header).
  function merged(anchor, list, paired) {
    var extra = [];
    list.forEach(function (x) {
      if (x === anchor || x.rest || paired.indexOf(x) >= 0 || pairedAncestor(x, paired) !== anchor)
        return;
      x.parts.forEach(function (p) {
        var c = Object.assign({}, p);
        c.name = x.role + x.slot + "/" + p.name;
        c.folded = true;
        extra.push(c);
      });
    });
    if (extra.length === 0)
      return anchor;
    var c = Object.assign({}, anchor);
    c.parts = anchor.parts.concat(extra);
    return c;
  }

  // Pairs the panel before (`from`) with this one (`to`) and holds the frame at progress 0.
  function begin(from, to) {
    if (Theme.motionLog) {
      console.info("morph from " + from.map(function (a) {
        return a.role + ":" + a.slot + (a.key ? "#" + a.key : "") + (a.drawable ? "" : "!") + "[" + a.parts.map(function (p) {
          return p.name;
        }).join(",") + "]";
      }).join(" "));
      console.info("morph to " + to.map(function (a) {
        return a.role + ":" + a.slot + (a.key ? "#" + a.key : "") + (a.drawable ? "" : "!") + (a.box ? "@" + Math.round(a.box.x) + "," + Math.round(a.box.y) + "," + Math.round(a.box.w) + "x" + Math.round(a.box.h) : "") + "[" + a.parts.map(function (p) {
          return p.name;
        }).join(",") + "]";
      }).join(" "));
    }
    teardown.stop();
    // First: the mask's boxes built below read the clock, and one a morph before left running would have
    // them all arrived.
    clockAnim.stop();
    clock = 0;
    clockRunning = false;
    clockArmed = false;
    ghostsDone = false;
    var m = MorphScan.match(from, to, {
      inPlace: morph.inPlace
    });
    since = {};
    lastSignature = signature(to);
    stableReads = 0;
    pairs = m.pairs;
    outs = m.outs;
    ins = m.ins;
    var pairedA = m.pairs.map(function (p) {
      return p.a;
    });
    var pairedB = m.pairs.map(function (p) {
      return p.b;
    });
    lastLayout = layoutOf(to);
    for (var bi = 0; bi < to.length; bi++)
      if (to[bi].box && to[bi].rect && !to[bi].rest) {
        boxOffset = Qt.point(to[bi].box.x - to[bi].rect.x, to[bi].box.y - to[bi].rect.y);
        break;
      }
    maskEntries = morph.maskFor(to, pairedB);
    var list = m.pairs.map(function (p) {
      var mb = morph.merged(p.b, to, pairedB);
      return {
        a: morph.merged(p.a, from, pairedA),
        b: mb,
        sigB: morph.signature([mb]),
        rawB: p.b,
        tier: p.tier,
        // The pair this one sits inside, if any: it stays in step with where the card keeps that.
        parentIndex: m.pairs.findIndex(function (o) {
          return o.a === p.a.parent;
        }),
        out: false
      };
    });
    // A leaver inside a pair rides it (folded into the pair above); the rest are cut where they are.
    m.outs.filter(function (a) {
      return !morph.pairedAncestor(a, pairedA);
    }).forEach(function (a) {
      list.push({
        a: a,
        b: null,
        tier: "out",
        out: true
      });
    });
    // The ghosts this replaces are deleted later, not now: hidden here, so no frame shows both.
    for (var k = 0; k < paintList.children.length; k++)
      paintList.children[k].visible = false;
    entries = list;
    running = true;
    if (Theme.motionLog)
      console.info("morph pairs " + m.pairs.map(function (p) {
        return p.tier + ":" + (p.a.key || p.a.role + p.a.slot) + ">" + (p.b.key || p.b.role + p.b.slot);
      }).join(" ") + " | outs " + m.outs.length + " ins " + m.ins.length);
  }

  // The first frame is reported once the compositor has shown it. A report that comes late must not
  // leave the surface before standing in ghosts: armed, the clock starts on the second frame this
  // window swaps after begin(), whatever the report says.
  property bool clockArmed: false
  property int armedSwaps: 0

  function armClock() {
    clockArmed = true;
    armedSwaps = 0;
  }

  Connections {
    target: morph.Window.window
    ignoreUnknownSignals: true

    function onFrameSwapped() {
      if (!morph.clockArmed || !morph.running || morph.clockRunning)
        return;
      morph.armedSwaps++;
      if (morph.armedSwaps >= 2)
        morph.startClock();
    }
  }

  // The first frame is on screen: the cut and the cascade start.
  function startClock() {
    if (!running || clockRunning)
      return;
    clockArmed = false;
    clockRunning = true;
    cardBegin = cardRect;
    fallback.value = 0;
    fallback.kick(0);
    clockAnim.restart();
  }

  // Reads this panel again (set by the surface): its layout can settle after the first read (a
  // list that loads, a carousel that centres on the chosen entry).
  property var rescan: null

  // The anchor of `to` that is `a` again: by key where it has one, else by role and slot.
  function find(to, a) {
    for (var i = 0; i < to.length; i++) {
      var b = to[i];
      if (b.rest)
        continue;
      if (a.key ? b.key === a.key : !b.key && b.role === a.role && b.slot === a.slot)
        return b;
    }
    return null;
  }

  // Lands every pair, and the cascade, where this panel now has them.
  // A reading reduced to what the ghosts and the mask use, to tell a layout that moved from one that
  // did not (the usual case, which then costs nothing but the read).
  function signature(to) {
    var r = Math.round;
    return to.map(function (a) {
      var g = a.rect ? r(a.rect.x) + "," + r(a.rect.y) + "," + r(a.rect.w) + "," + r(a.rect.h) : "";
      return a.role + ":" + a.slot + ":" + a.key + "@" + g + "[" + a.parts.map(function (p) {
        var c = p.color ? r(p.color.r * 20) + "." + r(p.color.g * 20) + "." + r(p.color.b * 20) + "." + r(p.color.a * 20) : "";
        return p.name + r(p.x) + "," + r(p.y) + "," + r(p.w) + (p.text !== undefined ? p.text : "") + "~" + r(p.opacity * 20) + c + (p.path || "") + (p.source || "");
      }).join(";") + "]";
    }).join("|");
  }

  property string lastSignature: ""

  function refresh(to) {
    if (!running || ghostsDone)
      return;
    var sig = signature(to);
    if (sig === lastSignature) {
      stableReads++;
      return;
    }
    stableReads = 0;
    lastSignature = sig;
    var i;
    for (i = 0; i < entries.length; i++) {
      var e = entries[i];
      if (e.out)
        continue;
      var nb = find(to, e.rawB);
      if (nb)
        e.rawB = nb;
    }
    var pairedB = entries.filter(function (e) {
      return !e.out;
    }).map(function (e) {
      return e.rawB;
    });
    // The ghosts take the new reading in place (MorphGhost rebinds its parts).
    for (i = 0; i < entries.length; i++) {
      if (entries[i].out)
        continue;
      // Only what changed: a ghost given a new reading re-sets every part it draws.
      var nm = merged(entries[i].rawB, to, pairedB);
      var ns = signature([nm]);
      if (ns === entries[i].sigB)
        continue;
      entries[i].sigB = ns;
      entries[i].b = nm;
      var g = ghostRepeater.itemAt(i);
      if (g)
        g.target = nm;
    }
    // The mask is many items: rebuilt only when the boxes moved, not when what is in them changed.
    var layout = layoutOf(to);
    if (layout !== lastLayout) {
      lastLayout = layout;
      maskEntries = morph.maskFor(to, pairedB);
    }
  }

  property string lastLayout: ""
  // Reads in a row that found nothing moved: three, and the panel has settled (the rescan stops).
  property int stableReads: 0

  function layoutOf(to) {
    var r = Math.round;
    return to.map(function (a) {
      var b = a.box ? r(a.box.x) + "," + r(a.box.y) + "," + r(a.box.w) + "," + r(a.box.h) : "";
      return a.role + a.slot + a.key + "@" + b + "#" + (a.rest ? a.parts.map(function (p) {
          return r(p.bx) + "," + r(p.by) + "," + r(p.w);
        }).join(";") : "");
    }).join("|");
  }

  Timer {
    interval: 24
    repeat: true
    // A panel that lays out late does so in its first frames; one that has held still for three reads,
    // or is most of the way in, is not read again.
    running: morph.running && morph.clockRunning && !morph.ghostsDone && morph.rescan !== null && morph.stableReads < 3 && morph.clock < Theme.morphRescanFor
    onTriggered: {
      var t0 = Date.now();
      morph.refresh(morph.rescan());
      if (Theme.motionLog)
        console.info("morph refresh took " + (Date.now() - t0) + " ms at clock " + Math.round(morph.clock));
    }
  }

  function stop() {
    clockAnim.stop();
    clockArmed = false;
    running = false;
    clockRunning = false;
    ghostsDone = true;
    pairs = [];
    outs = [];
    ins = [];
    teardown.restart();
  }

  // The ghosts and the mask's boxes are many items; destroyed in the frame a morph lands, they cost
  // that frame. Hidden then, they go once everything has come to rest.
  Timer {
    id: teardown

    interval: 500
    onTriggered: if (!morph.running) {
      morph.entries = [];
      morph.maskEntries = [];
    }
  }

  onLandedChanged: if (landed)
    ghostsDone = true

  // With QS_MOTION_LOG=1: the morph's progress and clock, once a frame while it runs.
  FrameAnimation {
    running: Theme.motionLog && morph.running && morph.clockRunning
    onTriggered: console.info("motion " + morph.label + ".q " + Date.now() + " " + morph.progress.toFixed(4) + " " + morph.clock.toFixed(1) + " " + (isNaN(morph.shapeProgress) ? "nan" : morph.shapeProgress.toFixed(4)))
  }

  // Wall time, read once a frame: a frame that comes late (the first ones after a window maps can)
  // finds the cut and the cascade as far on as the shape's springs, which also step by real time.
  property real clockStart: 0

  FrameAnimation {
    id: clockAnim

    function restart() {
      morph.clockStart = 0;
      morph.clock = 0;
      start();
    }

    // From the first frame after it starts, a frame in: making the ghosts can take a frame or two, and
    // the roll and the cascade must not have run by the time the first of them is seen.
    onTriggered: {
      var now = Date.now();
      if (morph.clockStart === 0)
        morph.clockStart = now - 8;
      morph.clock = Math.min(2000, now - morph.clockStart);
    }
  }

  onClockChanged: if (running && ghostsDone && clock >= cascadeEnd) {
    stop();
    finished();
  }

  // What is on screen just now, read as a scan, for a panel taking over in the middle of this one's
  // morph: each pair where its ghost is, faded leavers, and this panel's own anchors as far as the
  // cascade has let them in. `own` is a fresh scan of this panel.
  function snapshot(own) {
    var q = Math.max(0, Math.min(1, progress));
    var result = [];
    if (!ghostsDone) {
      pairs.forEach(function (p) {
        result.push(lerpAnchor(p.a, p.b, q));
      });
      var cut = clockRunning && clock > Theme.morphCut ? 0 : 1;
      if (cut > 0.05)
        outs.forEach(function (a) {
          result.push(faded(a, cut));
        });
    }
    own.forEach(function (a) {
      var isPair = false;
      for (var i = 0; i < pairs.length; i++)
        if (sameAnchor(pairs[i].b, a))
          isPair = true;
      if (isPair && !ghostsDone)
        return;
      var shown = a.rest ? morph.arrival(0) : rankOf(a) >= 0 ? morph.arrival(rankOf(a)) : 1;
      if (shown > 0.05)
        result.push(faded(a, shown));
    });
    return result;
  }

  function rankOf(a) {
    for (var i = 0; i < ins.length; i++)
      if (sameAnchor(ins[i], a))
        return ins[i].rank;
    return -1;
  }

  function sameAnchor(x, y) {
    return x.role === y.role && x.slot === y.slot && x.key === y.key;
  }

  function faded(a, k) {
    var c = Object.assign({}, a);
    c.parent = null;
    c.depth = 0;
    c.parts = a.parts.map(function (p) {
      var d = Object.assign({}, p);
      d.opacity = p.opacity * k;
      return d;
    });
    return c;
  }

  function lerpAnchor(a, b, q) {
    var c = Object.assign({}, b);
    c.parent = null;
    c.depth = 0;
    c.rect = Motion.lerpRect(a.rect, b.rect, q);
    var parts = [];
    b.parts.forEach(function (pb) {
      var pa = null;
      for (var i = 0; i < a.parts.length; i++)
        if (a.parts[i].name === pb.name)
          pa = a.parts[i];
      var d = Object.assign({}, q < 0.5 && pa ? pa : pb);
      if (pa) {
        var r = Motion.lerpRect(pa, pb, q);
        d.x = r.x;
        d.y = r.y;
        d.w = r.w;
        d.h = r.h;
      }
      parts.push(d);
    });
    c.parts = parts;
    return c;
  }

  // Every ghost's parts, in paint order (MorphGhost reparents them here).
  readonly property Item paint: paintList

  Item {
    id: paintList

    visible: !morph.ghostsDone
  }

  Repeater {
    id: ghostRepeater

    model: morph.entries

    MorphGhost {
      required property var modelData
      required property int index

      entry: modelData
      entryIndex: index
      host: morph
    }
  }
}
