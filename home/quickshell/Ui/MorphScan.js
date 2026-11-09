.pragma library

// The content morph's two halves that need no QML: reading a panel's contents into plain
// descriptions (scan), and pairing two such readings (match). See Ui/MorphLayer.qml.
//
// An anchor is an item that declares `morphRole` (the primitives do: Tile, ListRow, Button,
// PanelHeader, ...). Its parts are what it draws: text, icons, filled rectangles and images, in
// paint order, in window coordinates. A part is named by its item's objectName, else by its type
// and ordinal inside the anchor, so the same primitive pairs part for part. An anchor inside an
// anchor is an anchor of its own, its role prefixed by its parent's ("header.button"). What lies
// outside every anchor is collected as one more anchor, role "_rest", which never pairs.

function kindOf(item) {
  // A layer's effect (RoundedClip's mask) draws a sibling that is read directly.
  if (item.maskEnabled !== undefined && item.blurEnabled !== undefined)
    return "skip";
  // So does an item layer's own texture: what it shows is the item beside it, read directly.
  if (item.sourceItem !== undefined && item.textureSize !== undefined && item.sourceItem && item.sourceItem.layer && item.sourceItem.layer.enabled)
    return "skip";
  if (item.isGlyph !== undefined && item.strokeWidth !== undefined && item.path !== undefined)
    return "icon";
  if (item.font !== undefined && typeof item.text === "string" && (item.elide !== undefined || item.cursorPosition !== undefined))
    return "text";
  if (item.fillMode !== undefined && item.source !== undefined && item.paintedWidth !== undefined)
    return "image";
  if (item.radius !== undefined && item.border !== undefined && item.color !== undefined)
    return "rect";
  if (item.preferredRendererType !== undefined || item.getContext !== undefined || item.fragmentShader !== undefined || (item.sourceItem !== undefined && item.textureSize !== undefined))
    return "opaque";
  return "item";
}

function rectOf(item) {
  var p = item.mapToItem(null, 0, 0);
  var q = item.mapToItem(null, item.width, item.height);
  return {
    x: Math.min(p.x, q.x),
    y: Math.min(p.y, q.y),
    w: Math.abs(q.x - p.x),
    h: Math.abs(q.y - p.y)
  };
}

function colorOf(c) {
  return {
    r: c.r,
    g: c.g,
    b: c.b,
    a: c.a
  };
}

function intersect(a, b) {
  if (!a)
    return b;
  if (!b)
    return a;
  var x = Math.max(a.x, b.x), y = Math.max(a.y, b.y);
  var r = Math.min(a.x + a.w, b.x + b.w), btm = Math.min(a.y + a.h, b.y + b.h);
  return {
    x: x,
    y: y,
    w: Math.max(0, r - x),
    h: Math.max(0, btm - y)
  };
}

// The width of the border a Rectangle actually draws. One that was never given a border reports the
// defaults, 1 px of opaque black, and draws nothing only because of a flag QML cannot read: copied onto
// a ghost those would become real. So those values read as none (no one here means a black hairline).
function borderWidthOf(item) {
  var c = item.border.color;
  if (c.a <= 0.001)
    return 0;
  if (item.border.width === 1 && c.r === 0 && c.g === 0 && c.b === 0 && c.a === 1)
    return 0;
  return item.border.width;
}

function describe(item, kind, rect, opacity, clipRect) {
  var d = {
    type: kind,
    x: rect.x,
    y: rect.y,
    w: rect.w,
    h: rect.h,
    opacity: opacity,
    clip: clipRect
  };
  // Any scale on the way (a glyph drawn on a 24 grid and scaled to its slot): what the item is
  // drawn at times this is what lands on screen.
  d.scale = item.width > 0 ? rect.w / item.width : 1;
  if (kind === "text") {
    d.text = item.displayText !== undefined ? item.displayText : item.text;
    d.color = colorOf(item.color);
    // Copied out: a value read off an item is a live reference to it in Qt 6, and the item may have
    // changed (or gone) by the time the ghost is drawn.
    var f = item.font;
    d.font = {
      family: f.family,
      pixelSize: f.pixelSize > 0 ? f.pixelSize : undefined,
      pointSize: f.pixelSize > 0 ? undefined : f.pointSize,
      weight: f.weight,
      italic: f.italic,
      letterSpacing: f.letterSpacing,
      wordSpacing: f.wordSpacing,
      capitalization: f.capitalization,
      kerning: f.kerning,
      hintingPreference: f.hintingPreference,
      features: f.features ? JSON.parse(JSON.stringify(f.features)) : undefined
    };
    Object.keys(d.font).forEach(function (k) {
      if (d.font[k] === undefined)
        delete d.font[k];
    });
    d.elide = item.elide !== undefined ? item.elide : 0;
    d.hAlign = item.horizontalAlignment;
    d.vAlign = item.verticalAlignment;
    d.wrapMode = item.wrapMode;
    d.maximumLineCount = item.maximumLineCount !== undefined ? item.maximumLineCount : 0;
    d.lineHeight = item.lineHeight !== undefined ? item.lineHeight : 1;
    d.lineHeightMode = item.lineHeightMode !== undefined ? item.lineHeightMode : 0;
    d.textFormat = item.textFormat !== undefined ? item.textFormat : 0;
    d.renderType = item.renderType;
    d.fontSizeMode = item.fontSizeMode !== undefined ? item.fontSizeMode : 0;
  } else if (kind === "icon") {
    d.path = item.path;
    d.size = item.size * d.scale;
    d.color = colorOf(item.color);
    d.filled = item.filled;
    d.strokeWidth = item.strokeWidth * d.scale;
    d.curve = item.curve;
    d.fineY = item.fineY;
    d.inkCentred = item.inkCentred;
  } else if (kind === "rect") {
    d.color = colorOf(item.color);
    d.radius = item.radius;
    d.borderWidth = borderWidthOf(item);
    d.borderColor = colorOf(item.border.color);
    // Per-corner radii (a grouped row rounds only its stack's outer corners); NaN when unset.
    d.tl = item.topLeftRadius !== undefined ? item.topLeftRadius : -1;
    d.tr = item.topRightRadius !== undefined ? item.topRightRadius : -1;
    d.bl = item.bottomLeftRadius !== undefined ? item.bottomLeftRadius : -1;
    d.br = item.bottomRightRadius !== undefined ? item.bottomRightRadius : -1;
    // A gradient fill: its direction and stops.
    var g = item.gradient;
    if (g && g.stops && g.stops.length > 0) {
      d.gradient = {
        vertical: g.orientation !== 1, // Gradient.Horizontal
        stops: Array.prototype.map.call(g.stops, function (s) {
          return {
            p: s.position,
            c: colorOf(s.color)
          };
        })
      };
    }
  } else if (kind === "image") {
    d.source = String(item.source);
    d.fillMode = item.fillMode;
    d.smooth = item.smooth;
    d.mipmap = item.mipmap;
    d.sourceSize = {
      width: item.sourceSize.width,
      height: item.sourceSize.height
    };
    d.clipRadius = 0;
  }
  return d;
}

// Reads `root`'s visible contents. `box` is the item anchors' `box` rects are measured in (the
// surface's content box, which the mask is drawn over); `fade` scales every opacity.
function scan(root, box, fade) {
  var anchors = [];
  var seq = 0;
  var rest = newAnchor(null, "_rest", "", undefined, null);
  rest.rest = true;

  function newAnchor(item, role, key, slot, parent) {
    return {
      role: role,
      key: key,
      slot: slot,
      parent: parent,
      rect: item ? rectOf(item) : null,
      box: null,
      parts: [],
      counts: {},
      drawable: true,
      depth: parent ? parent.depth + 1 : 0
    };
  }

  function addPart(anchor, item, kind, opacity, clipRect, round) {
    var r = rectOf(item);
    if (r.w <= 0 && r.h <= 0)
      return;
    if (clipRect && (r.x >= clipRect.x + clipRect.w || r.y >= clipRect.y + clipRect.h || r.x + r.w <= clipRect.x || r.y + r.h <= clipRect.y))
      return;
    var n = anchor.counts[kind] || 0;
    anchor.counts[kind] = n + 1;
    var d = describe(item, kind, r, opacity * fade, clipRect);
    d.name = item.objectName && item.objectName !== "" ? item.objectName : kind + n;
    // Paint order across the whole reading: ghosts are drawn in it, whatever anchor holds them.
    d.seq = seq++;
    // Where it sits in the content box, for the mask.
    if (box) {
      var pb = item.mapToItem(box, 0, 0);
      d.bx = pb.x;
      d.by = pb.y;
    }
    // A fill or a picture that fills a RoundedClip takes its corners.
    if (round && (kind === "image" || kind === "rect") && Math.abs(r.x - round.rect.x) < 1.5 && Math.abs(r.y - round.rect.y) < 1.5 && Math.abs(r.w - round.rect.w) < 1.5 && Math.abs(r.h - round.rect.h) < 1.5) {
      d.clipRadius = round.r;
      if (kind === "rect" && d.radius < round.r) {
        d.radius = round.r;
        d.tl = d.tr = d.bl = d.br = -1;
      }
    }
    anchor.parts.push(d);
  }

  function walk(item, anchor, opacity, clipRect, round) {
    var kids = item.children.slice ? item.children.slice() : Array.prototype.slice.call(item.children);
    kids = kids.map(function (k, i) {
      return {
        k: k,
        i: i
      };
    });
    kids.sort(function (a, b) {
      return a.k.z - b.k.z || a.i - b.i;
    });
    for (var j = 0; j < kids.length; j++) {
      var child = kids[j].k;
      if (!child.visible || child.opacity <= 0.002 || child.morphIgnore === true)
        continue;
      var op = opacity * child.opacity;
      var clip = clipRect;
      var target = anchor;
      // An anchor wholly outside what clips it (a carousel tile scrolled past the panel) is not there.
      if (child.morphRole !== undefined && child.morphRole !== "" && clipRect) {
        var cr = rectOf(child);
        if (cr.x >= clipRect.x + clipRect.w || cr.y >= clipRect.y + clipRect.h || cr.x + cr.w <= clipRect.x || cr.y + cr.h <= clipRect.y)
          continue;
      }
      if (child.morphRole !== undefined && child.morphRole !== "") {
        var parentReal = anchor.rest ? null : anchor;
        var role = parentReal ? parentReal.role + "." + child.morphRole : child.morphRole;
        target = newAnchor(child, role, child.morphKey || "", child.morphSlot, parentReal);
        target.opacity = op;
        if (box) {
          var p = child.mapToItem(box, 0, 0);
          target.box = {
            x: p.x,
            y: p.y,
            w: child.width,
            h: child.height
          };
        }
        anchors.push(target);
      }
      var kind = kindOf(child);
      if (kind === "skip")
        continue;
      // What cannot be redrawn (a Shape, a Canvas, a shader) is an anchor of its own that never
      // pairs: the panel before's is cut at once, this panel's arrives on the cascade.
      if (kind === "opaque") {
        if (target === anchor) {
          var host = anchor.rest ? null : anchor;
          target = newAnchor(child, host ? host.role + ".opaque" : "opaque", "", undefined, host);
          target.opacity = op;
          if (box) {
            var po = child.mapToItem(box, 0, 0);
            target.box = {
              x: po.x,
              y: po.y,
              w: child.width,
              h: child.height
            };
          }
          anchors.push(target);
        }
        target.drawable = false;
        continue;
      }
      // A text input draws its placeholder and caret as children of its own.
      var editable = kind === "text" && child.cursorPosition !== undefined;
      var empty = kind === "text" && (child.displayText !== undefined ? child.displayText : child.text) === "";
      if (kind === "icon" || kind === "text" || kind === "image") {
        if (!empty)
          addPart(target, child, kind, op, clip, round);
        if (editable)
          walk(child, target, op, clip, round);
        continue;
      }
      if (kind === "rect" && (child.color.a > 0.001 || borderWidthOf(child) > 0))
        addPart(target, child, "rect", op, clip, round);
      if (child.clip)
        clip = intersect(clip, rectOf(child));
      var inner = child.morphRounds === true ? {
        r: child.radius,
        rect: rectOf(child)
      } : round;
      walk(child, target, op, clip, inner);
    }
  }

  rest.rect = rectOf(root);
  walk(root, rest, 1, null, null);
  assignSlots(anchors);
  var out = anchors.filter(function (a) {
    return a.parts.length > 0 || a.box;
  });
  if (rest.parts.length > 0)
    out.push(rest);
  out.forEach(function (a) {
    delete a.counts;
  });
  return out;
}

// An anchor's slot is what it declared, else its ordinal among the anchors of its role under the
// same parent, in reading order.
function assignSlots(anchors) {
  var groups = {};
  anchors.forEach(function (a) {
    if (a.slot !== undefined && a.slot !== null && a.slot !== -9999)
      return;
    var g = a.role + "|" + (a.parent ? anchors.indexOf(a.parent) : -1);
    (groups[g] = groups[g] || []).push(a);
  });
  Object.keys(groups).forEach(function (g) {
    // Reading order by rows: two whose middles share a line are one row, however their heights differ
    // (a carousel's chosen tile stands taller than the rest).
    groups[g].sort(function (a, b) {
      var dy = (a.rect.y + a.rect.h / 2) - (b.rect.y + b.rect.h / 2);
      if (Math.abs(dy) < Math.min(a.rect.h, b.rect.h) / 2)
        return a.rect.x - b.rect.x;
      return dy;
    }).forEach(function (a, i) {
      a.slot = i;
    });
  });
}

function centre(r) {
  return {
    x: r.x + r.w / 2,
    y: r.y + r.h / 2
  };
}

// An anchor's keys: one, or several most particular first, split on "|".
function keysOf(a) {
  return a.key ? a.key.split("|") : [];
}

function shareKey(a, b) {
  var kb = keysOf(b);
  return keysOf(a).some(function (k) {
    return kb.indexOf(k) >= 0;
  });
}

// Pairs two readings. Same key first, then same role and slot when the two are alike in size
// (under `ratio` on each axis) and close (centres under `reach` px apart). Returns the pairs,
// the anchors of `from` with no partner (outs) and those of `to` (ins), each `in` ranked for the
// arrival cascade in reading order from the top.
function match(from, to, opts) {
  opts = opts || {};
  var ratio = opts.ratio || 1.6;
  var reach = opts.reach || 48;
  // Inside one surface (a moment for a moment, the OSD from volume to brightness) the same role in
  // the same slot is the same place whatever its key says.
  var inPlace = !!opts.inPlace;
  var usedA = [], usedB = [];
  var pairs = [];

  function take(a, b, tier) {
    pairs.push({
      a: a,
      b: b,
      tier: tier
    });
    usedA.push(a);
    usedB.push(b);
  }

  function free(list, used, x) {
    return list.indexOf(x) >= 0 && used.indexOf(x) < 0;
  }

  function pairable(a) {
    return !a.rest && a.drawable;
  }

  // A child pairs only where its parent did, or where neither has one.
  function parentsAgree(a, b) {
    if (!a.parent && !b.parent)
      return true;
    if (!a.parent || !b.parent)
      return false;
    for (var i = 0; i < pairs.length; i++)
      if (pairs[i].a === a.parent)
        return pairs[i].b === b.parent;
    return false;
  }

  // The same role; inside two parents that paired, the same last part of it (a pill's track and a
  // slider's track: "pill.track", "slider.track").
  function sameRole(a, b) {
    if (a.role === b.role)
      return true;
    if (!a.parent || !b.parent)
      return false;
    var base = function (r) {
      return r.substring(r.lastIndexOf(".") + 1);
    };
    return base(a.role) === base(b.role);
  }

  var byDepth = function (x, y) {
    return x.depth - y.depth;
  };
  var fromSorted = from.slice().sort(byDepth);

  // A key may list several, most particular first ("device.Pixel|header"): of all the pairs that share
  // one, those that share their first keys go first, then by depth and reading order.
  var candidates = [];
  fromSorted.forEach(function (a, ia) {
    if (!pairable(a) || !a.key)
      return;
    var ka = keysOf(a);
    to.forEach(function (b, ib) {
      if (!pairable(b) || !b.key)
        return;
      var kb = keysOf(b);
      for (var i = 0; i < ka.length; i++) {
        var j = kb.indexOf(ka[i]);
        if (j >= 0) {
          candidates.push({
            a: a,
            b: b,
            cost: i + j,
            order: ia * 100000 + ib
          });
          return;
        }
      }
    });
  });
  // (Of rows that say the same, the top ones, whichever way the pair is going.)
  candidates.sort(function (x, y) {
    return x.cost - y.cost || x.a.depth - y.a.depth || x.a.rect.y - y.a.rect.y || x.b.rect.y - y.b.rect.y || x.order - y.order;
  });
  candidates.forEach(function (c) {
    if (free(from, usedA, c.a) && free(to, usedB, c.b))
      take(c.a, c.b, "same");
  });

  // A ghost the surface before was still fading out (MorphLayer.snapshot) that this surface has in
  // the very same place is this surface's own, taken back before it had gone: it stays, and comes
  // back up where it stands.
  fromSorted.forEach(function (a) {
    if (!a.ghost || !pairable(a) || !free(from, usedA, a))
      return;
    for (var i = 0; i < to.length; i++) {
      var b = to[i];
      if (!pairable(b) || !free(to, usedB, b) || b.role !== a.role || b.slot !== a.slot || (b.key || "") !== (a.key || ""))
        continue;
      if (Math.abs(a.rect.x - b.rect.x) > 1.5 || Math.abs(a.rect.y - b.rect.y) > 1.5 || Math.abs(a.rect.w - b.rect.w) > 1.5 || Math.abs(a.rect.h - b.rect.h) > 1.5)
        continue;
      take(a, b, "back");
      return;
    }
  });

  fromSorted.forEach(function (a) {
    if (!pairable(a) || !free(from, usedA, a))
      return;
    // Between two surfaces only what is named the same thing flies (and what sits inside it); a tile
    // that merely holds the same place in another panel dissolves with the rest.
    if (!inPlace && !(a.parent && usedA.indexOf(a.parent) >= 0))
      return;
    for (var i = 0; i < to.length; i++) {
      var b = to[i];
      if (!pairable(b) || !free(to, usedB, b) || !inPlace && b.key && a.key && !shareKey(a, b))
        continue;
      if (!sameRole(a, b) || b.slot !== a.slot || !parentsAgree(a, b))
        continue;
      var rw = Math.max(a.rect.w / Math.max(1, b.rect.w), b.rect.w / Math.max(1, a.rect.w));
      var rh = Math.max(a.rect.h / Math.max(1, b.rect.h), b.rect.h / Math.max(1, a.rect.h));
      var ca = centre(a.rect), cb = centre(b.rect);
      if (a.parent) {
        // Inside parents that paired, a child goes wherever its parent goes, if it sits at about the
        // same place in it (a pill's track and a slider's, not a back button and a far-end action).
        var ra = a.parent.rect, rb = b.parent.rect;
        var dx = (ca.x - ra.x) / Math.max(1, ra.w) - (cb.x - rb.x) / Math.max(1, rb.w);
        var dy = (ca.y - ra.y) / Math.max(1, ra.h) - (cb.y - rb.y) / Math.max(1, rb.h);
        if (Math.hypot(dx, dy) > 0.25)
          continue;
      } else if (rw >= ratio || rh >= ratio || a.role !== "carousel" && Math.hypot(ca.x - cb.x, ca.y - cb.y) > reach) {
        // (A carousel row is one strip wherever it is scrolled to: its tiles pair in order however
        // far the two rows sit apart, and the strip slides across as one.)
        continue;
      }
      take(a, b, "slot");
      return;
    }
  });

  var outs = from.filter(function (a) {
    return usedA.indexOf(a) < 0;
  });
  var ins = to.filter(function (b) {
    return usedB.indexOf(b) < 0 && !b.rest;
  });
  var top = Infinity, mid = 0, n = 0;
  to.forEach(function (b) {
    if (b.rect) {
      top = Math.min(top, b.rect.y);
      mid += b.rect.x + b.rect.w / 2;
      n++;
    }
  });
  mid = n ? mid / n : 0;
  // An anchor inside an arriving one arrives with it.
  function arrivingParent(b) {
    for (var p = b.parent; p; p = p.parent)
      if (ins.indexOf(p) >= 0)
        return p;
    return null;
  }
  ins.filter(function (b) {
    return !arrivingParent(b);
  }).sort(function (p, q) {
    return order(p) - order(q);
  }).forEach(function (b, i) {
    b.rank = i;
  });
  ins.forEach(function (b) {
    var p = arrivingParent(b);
    if (p)
      b.rank = p.rank;
  });

  function order(b) {
    var c = centre(b.rect);
    return (b.rect.y - top) + Math.abs(c.x - mid) * 0.2;
  }

  return {
    pairs: pairs,
    outs: outs,
    ins: ins
  };
}

