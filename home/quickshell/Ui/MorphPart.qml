import QtQuick
import qs.Commons
import "Motion.js" as Motion

// One part of a content-morph ghost (Ui/MorphGhost.qml): text, an icon, a filled rectangle or an
// image, read off the panel before (`pa`), this panel (`pb`) or both. Both drawing the same thing,
// it travels and blends (place, size, colour, corner). Both drawing something different, the old
// one leaves and the new one arrives in the same moving place: text rolls (out upwards, in from
// below), an icon dips and swaps, an image dissolves. Drawn by one side only, it rides its anchor
// and fades: the panel before's early, this one's late. In the window's coordinates.
Item {
  id: part

  property var pa: null
  property var pb: null
  property var owner

  readonly property real q: owner ? owner.q : 0
  readonly property bool both: pa !== null && pb !== null
  readonly property var d0: pa !== null ? pa : pb
  // What each slot draws, apart from where and how strongly: bound to the two parts, not to `solved`,
  // which is new every frame, so a slot's text, font, path and fill are not re-set every frame. Never
  // switched halfway: every part of a panel at once is a frame's worth of relayout.
  readonly property var dOne: both ? (resized ? pb : pa) : d0
  readonly property var dTwo: both && !same && !resized ? pb : null
  // How far along its pair is when the words moving across it have passed this part (MorphGhost).
  readonly property real clearAt: !owner || pa !== null || pb === null || !pb.folded ? 0 : owner.wordsClear(pb)

  // The same words in the same face at another size (a toast's line in the control centre's list):
  // one text, scaled from the one size to the other, never two sizes drawn over each other.
  readonly property bool resized: both && !same && type === "text" && pa.text === pb.text && pa.font.family === pb.font.family && pa.font.weight === pb.font.weight && pa.font.italic === pb.font.italic

  function textSize(p) {
    var f = p.font || {};
    var s = f.pixelSize > 0 ? f.pixelSize : (f.pointSize > 0 ? f.pointSize * 4 / 3 : 14);
    return s * (p.scale > 0 ? p.scale : 1);
  }
  readonly property string type: d0 ? d0.type : ""

  readonly property bool same: {
    if (!both)
      return false;
    if (type === "text")
      return pa.text === pb.text && pa.font.pixelSize === pb.font.pixelSize && pa.font.weight === pb.font.weight && pa.font.family === pb.font.family;
    if (type === "icon")
      return pa.path === pb.path;
    if (type === "image")
      return pa.source === pb.source;
    return true;
  }

  // Where a part drawn by one side only sits while its anchor travels: carried with the anchor,
  // stretched with it if it is a fill.
  function follow(p, from, to) {
    var sx = from.w > 0 ? to.w / from.w : 1;
    var sy = from.h > 0 ? to.h / from.h : 1;
    // What was folded in from an anchor inside keeps its own size: only the anchor's own fills stretch.
    var stretch = !p.folded && (p.type === "rect" || p.type === "image");
    var w = stretch ? p.w * sx : p.w;
    var h = stretch ? p.h * sy : p.h;
    // Text and icons keep their size and their offset from the anchor's nearer edge, scaled.
    return {
      x: to.x + (p.x - from.x) * sx + (stretch ? 0 : (p.w * sx - w) / 2),
      y: to.y + (p.y - from.y) * sy + (stretch ? 0 : (p.h * sy - h) / 2),
      w: w,
      h: h
    };
  }

  // A rectangle's four corners, the shared radius where one was not set on its own.
  function corners(p) {
    var r = p.radius || 0;
    return {
      tl: p.tl >= 0 ? p.tl : r,
      tr: p.tr >= 0 ? p.tr : r,
      bl: p.bl >= 0 ? p.bl : r,
      br: p.br >= 0 ? p.br : r
    };
  }

  function lerpCorners(a, b, t) {
    return {
      tl: Motion.lerp(a.tl, b.tl, t),
      tr: Motion.lerp(a.tr, b.tr, t),
      bl: Motion.lerp(a.bl, b.bl, t),
      br: Motion.lerp(a.br, b.br, t)
    };
  }

  function rgba(c) {
    return Qt.rgba(c.r, c.g, c.b, c.a);
  }

  // What each of the two slots draws this frame: {d, g: rect, op, scale, dy, color, size, radius,
  // border}; `two` is null unless the two sides differ.
  readonly property var solved: {
    var q = part.q;
    // Words, glyphs and colours change on the clock, not the shape: a long flight would otherwise
    // leave the slot empty between the old word and the new one.
    // A leaver reads no clock: it is cut whole (MorphGhost.fade), and a panel has many of them.
    var t = owner && owner.host && !owner.entry.out ? owner.host.clock : 0;
    var tint = Motion.ramp(t, 0, 30);
    if (!owner || !owner.rectA || !d0)
      return {
        one: {
          d: d0 || ({}),
          g: {
            x: 0,
            y: 0,
            w: 0,
            h: 0
          },
          op: 0,
          scale: 1,
          dy: 0,
          color: "transparent",
          size: 0,
          radius: 0,
          borderColor: "transparent"
        },
        two: null
      };
    if (!both) {
      var p = pa !== null ? pa : pb;
      var from = pa !== null ? owner.rectA : owner.rectB;
      // Carried with a pair that travels; where its own side has it in one that stays put.
      // What arrives inside a pair is at its own place too, not flying; unless the pair's words have to
      // cross that place (a title on its way past its back button), when it rides along beside them.
      var crosses = pa === null && p.folded && owner.crossedBy(p);
      var g = crosses ? {
        x: p.x + owner.rect.x - owner.rectB.x,
        y: p.y + owner.rect.y - owner.rectB.y,
        w: p.w,
        h: p.h
      } : owner.inPlace || p.folded && pa === null ? {
        x: p.x,
        y: p.y,
        w: p.w,
        h: p.h
      } : follow(p, from, owner.rect);
      // The panel before's is cut with the rest of what it had no partner for. This panel's arrives
      // on the cascade's first beat; on an anchor that travels, once it is most of the way, so it is
      // not seen apart from it.
      var op;
      if (pa !== null) {
        // A fill or a picture that is the anchor's own plate (a row's card) fades with the move
        // rather than blink out under it.
        var cut = owner.host && owner.host.clockRunning && t > Theme.morphCut;
        // (Not a glyph's own body, in an anchor no bigger than it.)
        var plate = !p.folded && from.w >= 60 && (p.type === "rect" || p.type === "image") && p.w >= 0.6 * from.w && p.h >= 0.5 * from.h;
        // (Eased out, and no faster than its flight, so its last faint tone goes as it lands, not in one
        // frame half way.)
        op = plate ? Math.max(Math.pow(1 - Motion.ramp(t, 0, Theme.morphPlateFade), 2), Math.pow(1 - q, 2)) : cut ? 0 : 1;
      } else {
        // Its own plate (a row's card) comes up as it nears its place: on the way the card is too narrow
        // for it, and it would read as the card changing tone.
        var fx = Motion.ramp(t, 0, Theme.morphArriveFade);
        var ownPlate = !p.folded && from.w >= 60 && (p.type === "rect" || p.type === "image") && p.w >= 0.6 * from.w && p.h >= 0.5 * from.h;
        // In a pill, on the curve the words rolling beside it come on (MorphPart's roll below), so a line
        // of two runs comes up as one; a pill handed on starts as the old is cut, so it is not seen empty.
        if (owner.inPlace && owner.entry.a.role === "pill") {
          var pillFrom = owner.host && owner.host.inPlace ? Theme.morphPillIn : 0;
          op = 1 - Math.pow(1 - Motion.ramp(t, pillFrom, pillFrom + Theme.morphPillRoll), 2);
        } else if (owner.inPlace) {
          // In a pair that stays put, with the words and glyphs changing beside it. (What comes with a
          // header leads the rows under it.)
          var inFrom = owner.entry.a.role === "header" ? 8 : 16;
          op = 1 - Math.pow(1 - Motion.ramp(t, inFrom, inFrom + Theme.morphRollIn), 2);
        } else if (p.folded && owner.platedA)
          // Inside a row the panel before drew on a plate: once that plate has gone, so it never sits
          // on the plate's edge.
          op = Motion.ramp(t, Theme.morphPlateFade, Theme.morphPlateFade + Theme.morphArriveFade);
        else
          op = ownPlate ? Motion.ramp(q, 0.5, 0.9) : (1 - Math.pow(1 - fx, 2)) * (p.folded ? 1 : Motion.ramp(q, 0.4, 0.8));
        // A word of the pair on its way across this part: not until it has cleared it.
        if (clearAt > 0)
          op *= Motion.ramp(q, clearAt - 0.2, clearAt + 0.15);
      }
      return {
        one: {
          d: p,
          g: g,
          op: p.opacity * op,
          scale: 1,
          // In a pill, a word comes up with the words rolling beside it.
          dy: owner.inPlace && owner.entry.a.role === "pill" && pa === null && p.type === "text" ? Theme.morphRoll * (1 - op) : 0,
          color: p.color ? rgba(p.color) : "transparent",
          size: p.size || 0,
          radius: p.type === "image" ? (p.clipRadius || 0) : (p.radius || 0),
          corners: p.type === "rect" ? corners(p) : null,
          borderColor: p.borderColor ? rgba(p.borderColor) : "transparent"
        },
        two: null
      };
    }
    // How far the card pushed the anchor in (MorphGhost.rect): every part rides that too.
    var sx = owner.rect.x - owner.free.x, sy = owner.rect.y - owner.free.y;
    if (same) {
      // A plate changing colour goes over more than a moment, not in the frame the morph first shows.
      if (type === "rect" && pa.color && pb.color && Math.abs(pa.color.r + pa.color.g + pa.color.b - pb.color.r - pb.color.g - pb.color.b) > 0.6)
        tint = Motion.ramp(t, 0, Theme.morphPlateTint);
      var gs = Motion.lerpRect(pa, pb, q);
      gs.x += sx;
      gs.y += sy;
      // A plate that comes or goes with its colour (a chosen tile's fill) does so over that same time,
      // whichever way it is going, not with the shape.
      var plateOp = type === "rect" && Math.abs(pa.opacity - pb.opacity) > 0.3 ? Motion.ramp(t, 0, Theme.morphPlateTint) : q;
      // A glyph turning the colour of the plate it lands on (a pill's speaker, into a slider's fill) dips
      // where it was and comes up where it will sit on that plate, riding it from there, not crossing it.
      var turnOp = 1;
      if (type === "icon" && pa.color && pb.color && Math.abs(pa.color.r + pa.color.g + pa.color.b - pb.color.r - pb.color.g - pb.color.b) > 0.6) {
        var turned = t >= Theme.morphRollOut;
        var track = owner.host ? owner.host.innerGhost(owner.entryIndex) : null;
        var home = turned ? pb : pa;
        var base = track ? track.rect : owner.rect;
        var from = track ? (turned ? track.rectB : track.rectA) : (turned ? owner.rectB : owner.rectA);
        // Level with the plate however thick it is just now.
        gs = {
          x: base.x + home.x - from.x,
          y: base.y + (base.h - home.h) / 2,
          w: home.w,
          h: home.h
        };
        tint = turned ? 1 : 0;
        turnOp = turned ? Motion.ramp(t, Theme.morphRollOut, Theme.morphRollOut + Theme.morphRollIn) : 1 - Motion.ramp(t, 0, Theme.morphRollOut);
      }
      return {
        one: {
          d: pa,
          g: gs,
          borderWidth: Motion.lerp(pa.borderWidth || 0, pb.borderWidth || 0, q),
          op: Motion.lerp(pa.opacity, pb.opacity, plateOp) * turnOp,
          scale: 1,
          dy: 0,
          color: pa.color ? rgba(Motion.lerpColor(pa.color, pb.color, tint)) : "transparent",
          size: Motion.lerp(pa.size || 0, pb.size || 0, q),
          radius: type === "image" ? Motion.lerp(pa.clipRadius || 0, pb.clipRadius || 0, q) : Motion.lerp(pa.radius || 0, pb.radius || 0, q),
          corners: type === "rect" ? lerpCorners(corners(pa), corners(pb), q) : null,
          borderColor: pa.borderColor ? rgba(Motion.lerpColor(pa.borderColor, pb.borderColor, tint)) : "transparent"
        },
        two: null
      };
    }
    // A roll: the old word is mostly gone when the new one starts up from below, so two words are never
    // both legible on top of each other, and a tile is never seen with neither.
    var recolour = owner.plateTurns && pa.color && pb.color && Math.abs(pa.color.r + pa.color.g + pa.color.b - pb.color.r - pb.color.g - pb.color.b) > 0.6;
    // The first frame that shows any of it comes a frame or two into the clock: the old one is still
    // there to be seen leaving.
    var titled = owner.entry.a.role === "header" && pa.name === "title";
    // The new one on the same curve as what arrives around it, so it does not come up after its row.
    var handedPill = owner.entry.a.role === "pill" && !(owner.host && owner.host.inPlace);
    // (A pill cuts its old word at once: the new one comes as it goes, never with it legible, and the
    // pill is never seen empty.)
    var pill = owner.entry.a.role === "pill";
    var inStart = handedPill ? 0 : pill ? Theme.morphPillIn : titled ? 16 : 14;
    var out = handedPill ? Motion.ramp(t, 0, Theme.morphCut + 2) : pill ? Motion.ramp(t, 0, Theme.morphPillOut) : Motion.ramp(t, 4, titled ? 4 + Theme.morphRollOut : 22), inn = 1 - Math.pow(1 - Motion.ramp(t, inStart, inStart + (pill ? Theme.morphPillRoll : Theme.morphRollIn)), 2);
    // Glyphs keep their own place in their anchor and ride it. (In a pair that stays put, each where
    // its own side has it.)
    var ride = !owner.inPlace;
    var ox = ride ? owner.rect.x - owner.rectA.x : 0, oy = ride ? owner.rect.y - owner.rectA.y : 0;
    var nx = ride ? owner.rect.x - owner.rectB.x : 0, ny = ride ? owner.rect.y - owner.rectB.y : 0;
    var ga, gb;
    // Each word keeps its own colour: a blend of the two on a plate that is changing colour too reads
    // as a disabled grey.
    var colA = pa.color ? rgba(pa.color) : "transparent";
    // (Over a plate changing colour under it, the new one has the old ink until the plate is half way
    // and the new from there, whichever reads better: never a grey of the two on the plate's mid tone.)
    var colB = !pb.color ? "transparent" : recolour && t < 0.5 * Theme.morphPlateTint ? rgba(pa.color) : rgba(pb.color);
    if (type === "text") {
      // A panel's title travels from where the old one was to where the new one lands, ahead of its
      // anchor, so it is not seen to hop and has moved over before its back button comes. Every other
      // word keeps its own place and rides: it sits beside a glyph or the rest of its line.
      var slides = owner.entry.a.role === "header" && pa.name === "title";
      if (slides) {
        var base = ride ? owner.rect : owner.free;
        var wq = 1 - Math.pow(1 - q, 5);
        var wx = base.x + Motion.lerp(pa.x - owner.rectA.x, pb.x - owner.rectB.x, wq);
        var wy = base.y + Motion.lerp(pa.y - owner.rectA.y, pb.y - owner.rectB.y, wq);
        ga = {
          x: wx,
          y: wy,
          w: pa.w,
          h: pa.h
        };
        gb = {
          x: wx,
          y: wy,
          w: pb.w,
          h: pb.h
        };
      } else {
        ga = {
          x: pa.x + ox,
          y: pa.y + oy,
          w: pa.w,
          h: pa.h
        };
        gb = {
          x: pb.x + nx,
          y: pb.y + ny,
          w: pb.w,
          h: pb.h
        };
      }
      // The same words in another face (a toast's line in the control centre's list) travel as one and
      // cross over where they are, the new face up before the old is down, so the line never dims.
      if (resized) {
        var k = Motion.lerp(textSize(pa) / textSize(pb), 1, q);
        return {
          one: {
            d: pb,
            g: {
              x: Motion.lerp(ga.x, gb.x, q),
              y: Motion.lerp(ga.y, gb.y, q),
              w: gb.w,
              h: gb.h
            },
            op: Motion.lerp(pa.opacity, pb.opacity, q),
            scale: k,
            dy: 0,
            color: rgba(Motion.lerpColor(pa.color, pb.color, tint)),
            size: 0,
            radius: 0,
            borderColor: "transparent"
          },
          two: null
        };
      }
      if (pa.text === pb.text) {
        var gt = Motion.lerpRect(ga, gb, q);
        return {
          one: {
            d: pa,
            g: gt,
            op: pa.opacity * (1 - Motion.ramp(t, 8, 30)),
            scale: 1,
            dy: 0,
            color: colA,
            size: 0,
            radius: 0,
            borderColor: "transparent"
          },
          two: {
            d: pb,
            g: gt,
            op: pb.opacity * Motion.ramp(t, 0, 16),
            scale: 1,
            dy: 0,
            color: colB,
            size: 0,
            radius: 0,
            borderColor: "transparent"
          }
        };
      }
      // Other words roll.
      // (A title is big: it needs the room to clear the old one.)
      var roll = titled ? Theme.morphTitleRoll : Theme.morphRoll;
      return {
        one: {
          d: pa,
          g: ga,
          op: pa.opacity * (1 - out),
          scale: 1,
          dy: -roll * out,
          color: colA,
          size: 0,
          radius: 0,
          borderColor: "transparent"
        },
        two: {
          d: pb,
          g: gb,
          op: pb.opacity * inn,
          scale: 1,
          dy: roll * (1 - inn),
          color: colB,
          size: 0,
          radius: 0,
          borderColor: "transparent"
        }
      };
    }
    if (type === "icon") {
      // A pill's glyph changes in one place on its way to where the new one sits, not in two.
      if (owner.entry.a.role === "pill" && !(owner.host && owner.host.inPlace)) {
        // From where the old one sat to where the new one sits beside the words that are already there,
        // on the clock, not pinned to the card's edge as that moves.
        var gq = 1 - Math.pow(1 - Motion.ramp(t, 0, Theme.morphGlyphTravel), 3);
        var igx = Motion.lerp(pa.x + ox, pb.x + nx, gq);
        var igy = Motion.lerp(pa.y + oy, pb.y + ny, gq);
        ox = igx - pa.x;
        oy = igy - pa.y;
        // It goes with what is cut around it (a battery's fill), not after it.
        out = Motion.ramp(t, 0, Theme.morphCut);
        nx = igx - pb.x;
        ny = igy - pb.y;
      }
      return {
        one: {
          d: pa,
          g: {
            x: pa.x + ox,
            y: pa.y + oy,
            w: pa.w,
            h: pa.h
          },
          op: pa.opacity * (1 - out),
          scale: 1 - 0.45 * out,
          dy: 0,
          color: colA,
          size: pa.size,
          radius: 0,
          borderColor: "transparent"
        },
        two: {
          d: pb,
          g: {
            x: pb.x + nx,
            y: pb.y + ny,
            w: pb.w,
            h: pb.h
          },
          op: pb.opacity * inn,
          scale: 0.55 + 0.45 * inn,
          dy: 0,
          color: colB,
          size: pb.size,
          radius: 0,
          borderColor: "transparent"
        }
      };
    }
    // An image dissolves in a place that travels.
    var gi = Motion.lerpRect(pa, pb, q);
    gi.x += sx;
    gi.y += sy;
    var dis = Motion.ramp(t, 10, 80);
    return {
      one: {
        d: pa,
        g: gi,
        op: Motion.lerp(pa.opacity, pb.opacity, q),
        scale: 1,
        dy: 0,
        color: "transparent",
        size: 0,
        radius: Motion.lerp(pa.clipRadius || 0, pb.clipRadius || 0, q),
        borderColor: "transparent"
      },
      two: {
        d: pb,
        g: gi,
        op: pb.opacity * dis,
        scale: 1,
        dy: 0,
        color: "transparent",
        size: 0,
        radius: Motion.lerp(pa.clipRadius || 0, pb.clipRadius || 0, q),
        borderColor: "transparent"
      }
    };
  }

  // A part inside a clipping ancestor (a scrolled list) stays inside it; a pair's clip travels.
  readonly property var clipRect: {
    if (!owner || !owner.rectA || !d0)
      return null;
    if (both)
      return pa.clip && pb.clip ? Motion.lerpRect(pa.clip, pb.clip, q) : null;
    var p = pa !== null ? pa : pb;
    if (!p.clip)
      return null;
    if (owner.inPlace)
      return p.clip;
    return follow({
      type: "rect",
      x: p.clip.x,
      y: p.clip.y,
      w: p.clip.w,
      h: p.clip.h
    }, pa !== null ? owner.rectA : owner.rectB, owner.rect);
  }

  opacity: owner ? owner.fade : 0
  visible: opacity > 0
  x: clipRect ? clipRect.x : 0
  y: clipRect ? clipRect.y : 0
  width: clipRect ? clipRect.w : 0
  height: clipRect ? clipRect.h : 0
  clip: clipRect !== null

  Loader {
    id: slotOne

    readonly property var s: part.solved.one
    readonly property var d: part.dOne
    // A text scales from its top-left corner, where it is laid out; a glyph dips about its middle.
    transformOrigin: part.type === "text" ? Item.TopLeft : Item.Center

    x: s.g.x - part.x
    y: s.g.y - part.y
    width: s.g.w
    height: s.g.h
    opacity: s.op
    visible: s.op > 0.002
    scale: s.scale
    sourceComponent: part.type === "text" ? textPart : part.type === "icon" ? iconPart : part.type === "rect" ? rectPart : imagePart

    transform: Translate {
      y: slotOne.s.dy
    }
  }

  Loader {
    id: slotTwo

    readonly property var s: part.solved.two
    readonly property var d: part.dTwo
    transformOrigin: part.type === "text" ? Item.TopLeft : Item.Center

    active: s !== null
    x: s ? s.g.x - part.x : 0
    y: s ? s.g.y - part.y : 0
    width: s ? s.g.w : 0
    height: s ? s.g.h : 0
    opacity: s ? s.op : 0
    visible: s !== null && s.op > 0.002
    scale: s ? s.scale : 1
    sourceComponent: part.type === "text" ? textPart : part.type === "icon" ? iconPart : part.type === "rect" ? rectPart : imagePart

    transform: Translate {
      y: slotTwo.s ? slotTwo.s.dy : 0
    }
  }

  // Each slot's item reads its slot (the Loader, its parent) through `s`; a slot being torn down
  // has none, so every binding falls back.
  Component {
    id: textPart

    Text {
      readonly property var s: parent && parent.s ? parent.s : null
      readonly property var d: parent && parent.d ? parent.d : ({})

      // Drawn at its own size and scaled as the original was, so it wraps and elides the same.
      readonly property real sc: d.scale > 0 ? d.scale : 1

      width: parent ? parent.width / sc : 0
      height: parent ? parent.height / sc : 0
      scale: sc
      transformOrigin: Item.TopLeft
      text: d.text || ""
      color: s ? s.color : "transparent"
      font: Qt.font(d.font ? d.font : {
        family: Theme.uiFont
      })
      elide: d.elide || Text.ElideNone
      horizontalAlignment: d.hAlign || Text.AlignLeft
      verticalAlignment: d.vAlign || Text.AlignTop
      wrapMode: d.wrapMode || Text.NoWrap
      maximumLineCount: d.maximumLineCount > 0 ? d.maximumLineCount : 2147483647
      lineHeight: d.lineHeight || 1
      lineHeightMode: d.lineHeightMode || Text.ProportionalHeight
      textFormat: d.textFormat || Text.PlainText
      renderType: d.renderType !== undefined ? d.renderType : Text.QtRendering
      fontSizeMode: d.fontSizeMode || Text.FixedSize
    }
  }

  Component {
    id: iconPart

    StrokeIcon {
      readonly property var s: parent && parent.s ? parent.s : null
      readonly property var d: parent && parent.d ? parent.d : ({})

      width: parent ? parent.width : 0
      height: parent ? parent.height : 0
      path: d.path || ""
      size: s ? s.size : 0
      color: s ? s.color : "transparent"
      filled: d.filled === true
      strokeWidth: d.strokeWidth || 2
      curve: d.curve !== false
      fineY: d.fineY === true
      inkCentred: d.inkCentred === true
    }
  }

  Component {
    id: rectPart

    Rectangle {
      id: plate

      readonly property var s: parent && parent.s ? parent.s : null
      readonly property var d: parent && parent.d ? parent.d : ({})

      width: parent ? parent.width : 0
      height: parent ? parent.height : 0
      color: s ? s.color : "transparent"
      radius: s ? s.radius : 0
      topLeftRadius: s && s.corners ? s.corners.tl : radius
      topRightRadius: s && s.corners ? s.corners.tr : radius
      bottomLeftRadius: s && s.corners ? s.corners.bl : radius
      bottomRightRadius: s && s.corners ? s.corners.br : radius
      border.width: s && s.borderWidth !== undefined ? s.borderWidth : (d.borderWidth || 0)
      border.color: s ? s.borderColor : "transparent"
      gradient: d.gradient ? grad : null

      function stop(i) {
        var list = d.gradient ? d.gradient.stops : [];
        var st = list[Math.min(i, list.length - 1)];
        return st ? st : {
          p: 0,
          c: {
            r: 0,
            g: 0,
            b: 0,
            a: 0
          }
        };
      }

      // Up to three stops, the last repeated where there are fewer.
      Gradient {
        id: grad

        orientation: plate.d.gradient && !plate.d.gradient.vertical ? Gradient.Horizontal : Gradient.Vertical

        GradientStop {
          position: plate.stop(0).p
          color: Qt.rgba(plate.stop(0).c.r, plate.stop(0).c.g, plate.stop(0).c.b, plate.stop(0).c.a)
        }

        GradientStop {
          position: plate.stop(1).p
          color: Qt.rgba(plate.stop(1).c.r, plate.stop(1).c.g, plate.stop(1).c.b, plate.stop(1).c.a)
        }

        GradientStop {
          position: plate.stop(2).p
          color: Qt.rgba(plate.stop(2).c.r, plate.stop(2).c.g, plate.stop(2).c.b, plate.stop(2).c.a)
        }
      }
    }
  }

  Component {
    id: imagePart

    RoundedClip {
      id: picture

      readonly property var s: parent && parent.s ? parent.s : null
      readonly property var d: parent && parent.d ? parent.d : ({})

      width: parent ? parent.width : 0
      height: parent ? parent.height : 0
      radius: s ? s.radius : 0

      Image {
        readonly property var d: picture.d

        anchors.fill: parent
        source: d.source || ""
        fillMode: d.fillMode !== undefined ? d.fillMode : Image.Stretch
        smooth: d.smooth !== false
        mipmap: d.mipmap === true
        sourceSize: d.sourceSize ? Qt.size(d.sourceSize.width, d.sourceSize.height) : Qt.size(0, 0)
        asynchronous: false
        cache: true
      }
    }
  }
}
