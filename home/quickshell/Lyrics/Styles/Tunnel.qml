import QtQuick
import qs.Commons
import qs.Lyrics
import "../Kinetic.js" as Kinetic

// Flying down a tunnel of words. Each word comes out of the depth as a speck near the middle,
// rushes up and brakes to full size just as it is sung, creeps a little nearer while it is held,
// and when the next arrives it goes on past the camera, swelling off the frame as it fades. Two
// or three words are in the air at once at different depths. A sparse field of streaks pours
// out of the vanishing point, faster with every word that lands.
LyricStyle {
  id: sty

  bloom: 0.6
  bloomKick: 0.45
  aberration: 0.0018
  aberrationKick: 0.006
  punchKick: 0.3
  shakeKick: 0.15
  warp: 0.04
  grain: 0.06
  vignette: 0.6
  ground: 0.7

  // How long a word is in the air before it is sung, and how long it takes to pass the camera.
  readonly property real approach: 0.8
  readonly property real pass: 0.22
  // How far off a word starts: its size there is 1 / far of its size when sung.
  readonly property real far: 28

  // The segment's words in order, so a pool can take them in turn.
  readonly property var words: {
    var out = [];
    if (first < 0)
      return out;
    for (var i = first; i <= last; i++)
      for (var j = 0; j < lines[i].words.length; j++)
        out.push({
          li: i,
          j: j
        });
    return out;
  }
  readonly property int at: {
    var c = -1;
    for (var n = 0; n < words.length; n++)
      if (lines[words[n].li].words[words[n].j].t <= now)
        c = n;
    return c;
  }

  // The vanishing point: the middle, wandering a little on the wall's clock.
  readonly property real vx: width / 2 + Math.sin(stage.wall * 0.37) * 2.5 * u
  readonly property real vy: height * 0.48 + Math.cos(stage.wall * 0.29) * 1.8 * u

  // The streaks, behind the words. Each runs out along its own ray from the vanishing point;
  // where it is along it is a pure function of the wall's clock and of `stir` (the kicks so
  // far, summed), so every word that lands throws the whole field forward.
  Repeater {
    model: sty.cur >= 0 ? 36 : 0

    Rectangle {
      required property int index

      readonly property real angle: Kinetic.hash(sty.seed, index, 1) * Math.PI * 2
      readonly property real pace: 0.55 + 0.7 * Kinetic.hash(sty.seed, index, 2)
      readonly property real p: {
        var x = Kinetic.hash(sty.seed, index, 3) + (sty.stage.wall * 0.3 + (sty.stage.stir || 0) * 1.6) * pace;
        return x - Math.floor(x);
      }
      // Out along the ray as a square, so it gathers speed like something passed.
      readonly property real r: (4 + p * p * 120) * sty.u

      x: sty.vx + Math.cos(angle) * r
      y: sty.vy + Math.sin(angle) * r - height / 2
      width: (0.6 + 14 * p * p) * sty.u * (1 + 1.5 * sty.stage.kick)
      height: Math.max(1, 0.18 * sty.u * (0.6 + p))
      transformOrigin: Item.Left
      rotation: angle * 180 / Math.PI
      antialiasing: true
      color: index % 3 === 0 ? sty.accent2 : sty.ink
      opacity: Kinetic.span(0, 0.15, p) * (0.3 + 0.5 * p)
    }
  }

  // Five words in the air at most: the one passing, the one in hand and those still coming.
  Repeater {
    model: 5

    LyricText {
      id: word

      required property int index

      readonly property int n: {
        for (var m = sty.at - 1; m <= sty.at + 3; m++)
          if (m >= 0 && m < sty.words.length && ((m % 5) + 5) % 5 === index)
            return m;
        return -1;
      }
      readonly property var line: n >= 0 ? sty.lines[sty.words[n].li] : null
      readonly property int j: n >= 0 ? sty.words[n].j : 0
      readonly property var w: line && j < line.words.length ? line.words[j] : null
      readonly property real age: w ? sty.now - w.t : -10
      readonly property real until: line ? sty.until(line, j) : 0
      // It sets off a moment before the next word arrives, to clear the way for it.
      readonly property real gone: w ? sty.now - Math.max(w.t + 0.15, until - 0.16) : -1
      // How far off it is, 1 when it is sung: a soft brake on the way in, a creep while held,
      // and a rush past once let go.
      readonly property real depth: {
        if (age < 0)
          return 1 + (sty.far - 1) * Math.pow(Kinetic.clamp01(-age / sty.approach), 2.2);
        var held = 1 - 0.14 * Kinetic.outCubic(Kinetic.span(0, Math.max(0.4, until - w.t), age));
        return gone <= 0 ? held : held * Math.exp(-gone * 11);
      }
      // Where it sits when sung, off the middle a little; the further it comes past that, the
      // further out it swings, as a thing passing the camera does.
      readonly property real heading: Kinetic.hash(sty.seed, n, 11) * Math.PI * 2
      readonly property real reach: (4 + 5 * Kinetic.hash(sty.seed, n, 12)) * sty.u
      readonly property real ox: Math.cos(heading) * reach * 1.6
      readonly property real oy: Math.sin(heading) * reach
      // Fitted once, to the stage's width and to a height, at its sung distance.
      readonly property real fit: Math.min(sty.width * 0.72 / Math.max(1, implicitWidth), 38 * sty.u / Math.max(1, implicitHeight))

      x: sty.vx + ox / depth - width / 2
      y: sty.vy + oy / depth - height / 2
      z: -depth
      text: w ? Kinetic.bare(w.text) : ""
      face: line ? sty.face(sty.words[n].li, j) : null
      size: 20 * sty.u
      scale: fit / depth
      rotation: Kinetic.jitter(sty.seed, n, 13) * 7 * Math.log(depth)
      // Far off it is the second colour and faint; it lands in the accent and settles to ink.
      color: age < 0 ? sty.mix(sty.accent2, sty.ink, Kinetic.span(4, 1.2, depth)) : gone > 0 ? sty.mix(sty.ink, sty.accent, gone / sty.pass * 2) : sty.mix(sty.accent, sty.ink, age / 0.3)
      opacity: Kinetic.span(sty.far, sty.far * 0.45, depth) * (age < 0 ? 0.2 + 0.8 * Kinetic.span(1.7, 1, depth) : 1) * Math.pow(1 - Kinetic.span(0, sty.pass, gone), 3)
      visible: w !== null && age > -sty.approach && gone < sty.pass
    }
  }
}
