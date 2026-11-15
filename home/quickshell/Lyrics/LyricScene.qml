import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Services
import "Director.js" as Director
import "Kinetic.js" as Kinetic
import "Parse.js" as Parse

// The lyric stage's picture on one screen: the ground, the style playing now (and the one it
// cut from, for the length of the cut), and the lens they are seen through.
//
// One clock runs it. `now` is the player's position in the song, read every frame; the plan
// (Director.js) says which style has which stretch of the song; the style in hand draws from
// `now` alone. `kick` jumps as each word lands and dies away, and with the player's loudness
// (`level`) it is what the ground and the lens move to.
Item {
  id: scene

  // The window is mapped. Nothing here runs or holds a texture otherwise.
  property bool live: false
  // For tests and the curious: a time to hold the song at (seconds; -1 follows the player), and
  // one style to play the whole song in ("" casts by section).
  property real pinned: -1
  property string forcedStyle: ""
  // Seconds the words run ahead of the player's own clock.
  property real offset: 0
  // Device pixels per item pixel.
  property real pixelRatio: 1

  // The styles there are, and what kind of stretch each is cast for: "calm" (intros, bridges,
  // the quiet), "mid" (verses) and "high" (choruses). `wants: "emoji"` keeps a style for
  // stretches with at least two words that have a picture. With motion reduced only the
  // `gentle` ones are cast, and nothing kicks.
  readonly property var catalogue: [
    {
      name: "Whisper",
      tiers: ["calm"],
      weight: 1,
      gentle: true
    },
    {
      name: "Typewriter",
      tiers: ["calm", "mid"],
      weight: 0.7,
      gentle: true
    },
    {
      name: "Drift",
      tiers: ["calm", "mid"],
      weight: 0.7,
      gentle: true
    },
    {
      name: "Neon",
      tiers: ["calm", "mid"],
      weight: 0.7,
      gentle: true
    },
    {
      name: "Reel",
      tiers: ["calm", "mid"],
      weight: 0.9,
      gentle: true
    },
    {
      name: "Poster",
      tiers: ["mid"],
      weight: 1
    },
    {
      name: "Ransom",
      tiers: ["mid"],
      weight: 1
    },
    {
      name: "Cascade",
      tiers: ["mid"],
      weight: 1
    },
    {
      name: "Orbit",
      tiers: ["mid"],
      weight: 1
    },
    {
      name: "Pictogram",
      tiers: ["mid", "high"],
      weight: 1.3,
      wants: "emoji"
    },
    {
      name: "Echo",
      tiers: ["mid", "high"],
      weight: 0.8
    },
    {
      name: "Ring",
      tiers: ["mid", "high"],
      weight: 1
    },
    {
      name: "Titlecard",
      tiers: ["mid", "high"],
      weight: 0.8
    },
    {
      name: "Punch",
      tiers: ["high"],
      weight: 1
    },
    {
      name: "Marquee",
      tiers: ["high"],
      weight: 1
    },
    {
      name: "Tunnel",
      tiers: ["high"],
      weight: 1
    },
    {
      name: "Glitch",
      tiers: ["high"],
      weight: 0.8
    }
  ].filter(function (s) {
    return !Theme.reduceMotion || s.gentle === true;
  })
  readonly property var styleNames: catalogue.map(function (c) {
    return c.name;
  })

  // The song's time and the wall's, both in seconds; the second never stops or jumps.
  property real now: 0
  property real wall: 0
  property real kick: 0
  property real level: 0
  // 1 at a change of style, dying away.
  property real cut: 0
  // The kicks so far, summed: the ground's field is pushed along by it.
  property real stir: 0

  property real _estimate: 0
  property real _cutAt: -100

  readonly property var model: Lyrics.state === "ready" ? Lyrics.model : null
  readonly property var lines: model ? model.lines : []
  readonly property int seed: Director.hashText(Lyrics.key)

  // What the interlude says under the song's name while there are no words to show.
  readonly property string status: {
    if (!Media.active)
      return "Nothing is playing";
    if (Lyrics.state === "loading")
      return "Finding the words";
    if (Lyrics.state === "none")
      return "No timed lyrics for this one";
    return "";
  }

  readonly property var plan: {
    if (scene.model === null)
      return Director.plan({
        lines: [],
        parts: []
      }, scene.catalogue, scene.seed);
    var segments = Director.plan(scene.model, scene.catalogue, scene.seed);
    if (scene.forcedStyle !== "")
      segments.forEach(function (s) {
        if (s.firstLine >= 0)
          s.style = scene.forcedStyle;
      });
    return segments;
  }
  readonly property int segIndex: Director.segmentAt(plan, now)
  readonly property var seg: plan[Math.min(segIndex, plan.length - 1)]
  readonly property real tierGain: seg.tier === "high" ? 1.15 : seg.tier === "calm" ? 0.6 : 0.85

  // ---- colour: the cover's, where the cover is a file; the theme's otherwise ----

  readonly property string artFile: {
    var url = Media.artUrl;
    return url.indexOf("file://") === 0 || url.indexOf("/") === 0 ? url : "";
  }

  ColorQuantizer {
    id: swatch

    source: scene.live && scene.artFile !== "" ? scene.artFile : ""
    depth: 3
    rescaleSize: 64
  }

  // The cover's liveliest colour and the one furthest from it round the wheel, both lifted
  // until they read on black.
  readonly property var tones: {
    var best = null, bestScore = 0;
    var colors = swatch.colors;
    for (var i = 0; i < colors.length; i++) {
      var c = colors[i];
      var score = c.hsvSaturation * (0.35 + c.hsvValue);
      if (c.hsvSaturation > 0.22 && c.hsvValue > 0.2 && score > bestScore) {
        best = c;
        bestScore = score;
      }
    }
    if (best === null)
      return {
        accent: Theme.accent,
        second: Qt.color(Theme.palette.gold)
      };
    var other = null, otherScore = 0;
    for (var j = 0; j < colors.length; j++) {
      var d = Math.abs(colors[j].hslHue - best.hslHue);
      var turn = Math.min(d, 1 - d) * (0.3 + colors[j].hsvSaturation);
      if (colors[j].hsvSaturation > 0.15 && turn > otherScore) {
        other = colors[j];
        otherScore = turn;
      }
    }
    var lift = function (c, turned) {
      var h = (c.hslHue + turned + 1) % 1;
      return Qt.hsla(h, Math.max(0.6, Math.min(0.95, c.hslSaturation)), Math.max(0.64, Math.min(0.76, c.hslLightness)), 1);
    };
    return {
      accent: lift(best, 0),
      second: other !== null && otherScore > 0.06 ? lift(other, 0) : lift(best, 0.11)
    };
  }
  readonly property color ink: Theme.lyricInk
  readonly property color accent: tones.accent
  readonly property color accent2: tones.second

  // ---- the clock ----

  // The player's loudness, where PipeWire will say. Silent in the harness, and then the words
  // alone drive the picture.
  PwNodePeakMonitor {
    id: meter

    node: Pipewire.defaultAudioSink
    enabled: scene.live && Media.playing
  }

  FrameAnimation {
    running: scene.live
    onTriggered: scene.tick(Math.min(0.1, frameTime))
  }

  // One per frame drawn, for whoever is counting them (tools/qs-verify/lyrics.sh probe).
  signal ticked

  function tick(dt) {
    scene.wall += dt;
    scene.ticked();

    // The player extrapolates its own position between reports; this glides after it rather
    // than copying it, so a report that lands a few milliseconds off does not jerk the words.
    var raw = Media.positionKnown && Media.player ? Media.player.position : 0;
    if (scene.pinned >= 0)
      scene._estimate = scene.pinned;
    else if (!Media.playing || Math.abs(raw - scene._estimate) > 0.5)
      scene._estimate = raw;
    else
      scene._estimate += dt + (raw - scene._estimate) * Math.min(1, dt * 4);
    scene.now = scene._estimate + (scene.pinned >= 0 ? 0 : scene.offset);

    var k = 0;
    var i = Parse.lineAt(scene.lines, scene.now, 0);
    for (var j = Math.max(0, i - 1); j <= i; j++) {
      var words = scene.lines[j].words;
      for (var w = 0; w < words.length; w++) {
        var age = scene.now - words[w].t;
        if (age >= 0 && age < 1.5)
          k = Math.max(k, Kinetic.weight(words[w], w === words.length - 1) * Math.exp(-age * Theme.lyricKickDecay));
      }
    }
    scene.kick = Theme.reduceMotion ? 0 : k * scene.tierGain;
    scene.stir += scene.kick * dt;
    scene.cut = Kinetic.pulse(scene.wall - scene._cutAt, Theme.lyricCutDecay);

    var heard = meter.enabled ? meter.peak : 0;
    scene.level += (heard - scene.level) * Math.min(1, dt * (heard > scene.level ? 30 : 4));
  }

  // ---- the styles: two hosts, the one in front playing the segment in hand ----

  property int front: 0
  readonly property var frontItem: front === 0 ? hostA.item : hostB.item
  property var _shown: null

  function change() {
    if (!scene.live) {
      scene._shown = null;
      hostA.source = "";
      hostB.source = "";
      return;
    }
    if (scene._shown === scene.seg)
      return;
    var incoming = scene.front === 0 ? hostB : hostA;
    // Read off the model the plan was made from, not a binding that may not have followed yet.
    var lines = scene.model ? scene.model.lines : [];
    incoming.setSource(Qt.resolvedUrl("Styles/" + scene.seg.style + ".qml"), {
      stage: scene,
      seg: scene.seg,
      lines: lines
    });
    if (incoming.status === Loader.Error) {
      console.warn("Lyrics: no style " + scene.seg.style);
      incoming.setSource(Qt.resolvedUrl("Styles/Interlude.qml"), {
        stage: scene,
        seg: scene.seg,
        lines: lines
      });
    }
    // The first style comes up with the stage, not on a cut.
    if (scene._shown !== null)
      scene._cutAt = scene.wall;
    scene._shown = scene.seg;
    scene.front = 1 - scene.front;
  }

  onSegChanged: change()
  onLiveChanged: change()

  function look(name, fallback) {
    var item = scene.frontItem;
    return item && item[name] !== undefined ? item[name] : fallback;
  }

  Item {
    id: canvas

    anchors.fill: parent

    Rectangle {
      anchors.fill: parent
      color: Theme.lyricGround
    }

    // Drawn small and stretched: it is all slow gradients.
    ShaderEffect {
      width: Math.ceil(scene.width / Theme.lyricGroundShrink)
      height: Math.ceil(scene.height / Theme.lyricGroundShrink)
      scale: Theme.lyricGroundShrink
      transformOrigin: Item.TopLeft
      layer.enabled: true
      layer.smooth: true
      // Half floats: at this size eight bits a channel would stretch into visible bands.
      layer.format: ShaderEffectSource.RGBA16F

      property real time: scene.wall
      property real aspect: scene.width / Math.max(1, scene.height)
      property real glow: (Theme.lyricGlow + Theme.lyricGlowKick * scene.kick + Theme.lyricGlowLevel * scene.level) * scene.look("ground", 1)
      property real stir: scene.stir
      property color tintA: scene.accent
      property color tintB: scene.accent2
      property color tintC: Qt.tint(scene.accent, Theme.withAlpha(scene.accent2, 0.5))

      fragmentShader: Qt.resolvedUrl("../Shaders/lyricground.frag.qsb")
    }

    Loader {
      id: hostA

      anchors.fill: parent
      opacity: scene.front === 0 ? 1 : 0
      onOpacityChanged: if (opacity === 0 && scene.front !== 0)
        source = ""

      Behavior on opacity {
        NumberAnimation {
          duration: Theme.lyricCut
        }
      }
    }

    Loader {
      id: hostB

      anchors.fill: parent
      opacity: scene.front === 1 ? 1 : 0
      onOpacityChanged: if (opacity === 0 && scene.front !== 1)
        source = ""

      Behavior on opacity {
        NumberAnimation {
          duration: Theme.lyricCut
        }
      }
    }
  }

  // ---- the lens ----

  // Mipmapped, because the bloom reads it at a sixth of its size.
  ShaderEffectSource {
    id: picture

    sourceItem: canvas
    hideSource: true
    live: scene.live
    mipmap: true
    // Half floats, so the dark end of the ground reaches the lens unbanded and is dithered there.
    format: ShaderEffectSource.RGBA16F
    visible: false
  }

  ShaderEffect {
    id: glowAcross

    width: Math.ceil(scene.width / Theme.lyricBloomShrink)
    height: Math.ceil(scene.height / Theme.lyricBloomShrink)
    visible: false

    property var source: picture
    property point step: Qt.point(Theme.lyricBloomSpread / Math.max(1, width), 0)
    property real floorLuma: Theme.lyricBloomFloor

    fragmentShader: Qt.resolvedUrl("../Shaders/lyricblur.frag.qsb")
  }

  ShaderEffectSource {
    id: glowAcrossTexture

    sourceItem: glowAcross
    live: scene.live
    textureSize: Qt.size(glowAcross.width, glowAcross.height)
    visible: false
  }

  ShaderEffect {
    id: glowDown

    width: glowAcross.width
    height: glowAcross.height
    visible: false

    property var source: glowAcrossTexture
    property point step: Qt.point(0, Theme.lyricBloomSpread / Math.max(1, height))
    property real floorLuma: 0

    fragmentShader: Qt.resolvedUrl("../Shaders/lyricblur.frag.qsb")
  }

  ShaderEffectSource {
    id: glowTexture

    sourceItem: glowDown
    live: scene.live
    textureSize: Qt.size(glowAcross.width, glowAcross.height)
    visible: false
  }

  ShaderEffect {
    anchors.fill: parent

    property var source: picture
    property var glowSource: glowTexture
    property size pixels: Qt.size(width * scene.pixelRatio, height * scene.pixelRatio)
    property point shake: {
      var reach = scene.look("shakeKick", 0) * scene.kick / 100;
      return Qt.point(reach * Math.sin(scene.wall * 91) * scene.height / Math.max(1, scene.width), reach * Math.cos(scene.wall * 73));
    }
    property real time: scene.wall
    property real bloom: scene.look("bloom", 0.45) + scene.look("bloomKick", 0.3) * scene.kick + 0.35 * scene.cut
    property real aberration: scene.look("aberration", 0.0012) + scene.look("aberrationKick", 0.003) * scene.kick + Theme.lyricCutFringe * scene.cut
    property real punch: scene.look("punchKick", 0) * scene.kick + Theme.lyricCutPunch * scene.cut
    property real glitch: scene.look("glitchKick", 0) * scene.kick
    property real warp: scene.look("warp", 0)
    property real scan: scene.look("scan", 0)
    property real grain: scene.look("grain", 0.05)
    property real vignette: scene.look("vignette", 0.4)
    property real flash: scene.look("flashKick", 0) * scene.kick + Theme.lyricCutFlash * scene.look("cutFlash", 1) * scene.cut
    property real mono: scene.look("mono", 0)
    property real dust: scene.look("dust", 0)
    property real flicker: scene.look("flicker", 0)
    property real spot: scene.look("spot", 0)
    property real spotSize: scene.look("spotSize", 0.32)
    property point spotAt: scene.look("spotAt", Qt.point(0.5, 0.5))

    fragmentShader: Qt.resolvedUrl("../Shaders/lyricpost.frag.qsb")
  }
}
