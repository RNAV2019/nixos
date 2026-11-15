import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Services
import "Director.js" as Director
import "Kinetic.js" as Kinetic
import "Palette.js" as Palette
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
  // stretches with at least two words that have a picture, and `look: "film"` marks the
  // black-and-white ones, which the plan casts in runs so a song is not for ever changing stock. With motion reduced only the
  // `gentle` ones are cast, and nothing kicks.
  readonly property var catalogue: [
    {
      name: "Stack",
      tiers: ["calm", "mid"],
      weight: 1.3,
      gentle: true
    },
    {
      name: "Whisper",
      tiers: ["calm"],
      weight: 1,
      gentle: true
    },
    {
      name: "Reel",
      tiers: ["calm", "mid"],
      weight: 1,
      look: "film",
      gentle: true
    },
    {
      name: "Cascade",
      tiers: ["mid"],
      weight: 0.8
    },
    {
      name: "Pictogram",
      tiers: ["mid", "high"],
      weight: 1.2,
      wants: "emoji"
    },
    {
      name: "Ring",
      tiers: ["mid", "high"],
      weight: 1,
      look: "film"
    },
    {
      name: "Titlecard",
      tiers: ["mid", "high"],
      weight: 0.9,
      look: "film"
    },
    {
      name: "Punch",
      tiers: ["high"],
      weight: 1
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
  // The lens as it is set now. A style says what it wants (LyricStyle's `bloom`, `grain`...)
  // and the lens follows over a moment. The old print is not a style's to ask for at its first
  // frame, though: how far the picture is one (`stock`, and `marks` for its dust and flicker)
  // is read off the plan and the song's time, so it comes up across the change and is never
  // cut to, and the lens is set between what the last plain style wanted (`_plain`) and the
  // print (Theme's `lyricFilm...`) by that much.
  property real lensBloom: 0.45
  property real lensGrain: 0.05
  property real lensVignette: 0.4
  property real lensMono: 0
  property real lensDust: 0
  property real lensFlicker: 0
  property real lensDepth: 0
  property real lensGround: 1
  property real lensVeil: 0
  property real lensSoftness: 0
  property bool _lensSet: false
  property real stock: 0
  property real marks: 0
  property var _plain: ({
      bloom: 0.45,
      grain: 0.05,
      vignette: 0.4,
      ground: 1
    })
  property real level: 0
  // How far out of focus the whole picture is: 0 but round a change of style, where the lens
  // goes soft on the style leaving and comes sharp on the one arriving.
  property real refocus: 0
  // The kicks so far, summed: the ground's field is pushed along by it.
  property real stir: 0

  property real _estimate: 0

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
  // Which of the plan's stretches are an old print.
  readonly property var films: Director.looks(plan, catalogue, "film")
  readonly property int segIndex: Director.segmentAt(plan, now)
  readonly property var seg: plan[Math.min(segIndex, plan.length - 1)]
  readonly property real tierGain: seg.tier === "high" ? 1.15 : seg.tier === "calm" ? 0.6 : 0.85

  // ---- colour: every colour on the stage is the cover's ----

  // The cover as a file the quantiser can read. A player that names one on the web (a
  // streaming client does) has it fetched once to the cache; with no cover the theme stands in.
  readonly property string artUrl: scene.live ? Media.artUrl : ""
  readonly property bool artRemote: artUrl.indexOf("http://") === 0 || artUrl.indexOf("https://") === 0
  readonly property string artCopy: Paths.lyricsDir + "/cover"
  // The web cover the copy on disk is of, and the one that could not be had.
  property string _fetched: ""
  property string _failed: ""
  // A web cover is on its way: the last song's colours stand until it lands.
  readonly property bool artWaiting: artRemote && _fetched !== artUrl && _failed !== artUrl
  readonly property string artFile: {
    if (scene.artRemote)
      return scene._fetched === scene.artUrl ? "file://" + scene.artCopy : "";
    return scene.artUrl.indexOf("file://") === 0 || scene.artUrl.indexOf("/") === 0 ? scene.artUrl : "";
  }

  // Asked for a moment after the cover changes: inside the change itself the bindings that
  // hang off it (the command among them) have not all followed.
  onArtUrlChanged: Qt.callLater(scene.fetchArt)
  onArtFileChanged: Qt.callLater(scene.readArt)
  onArtWaitingChanged: Qt.callLater(scene.readArt)

  function fetchArt() {
    if (scene.artWaiting)
      artFetch.run();
  }

  QueuedProcess {
    id: artFetch

    stamp: scene.artUrl
    command: ["curl", "--silent", "--fail", "--location", "--max-time", "10", "--output", scene.artCopy, scene.artUrl]

    onExited: function (code) {
      if (artFetch.stale)
        return;
      // A fetch that failed may have left half a file: the copy is then no cover's.
      scene._fetched = code === 0 ? scene.artUrl : "";
      scene._failed = code === 0 ? "" : scene.artUrl;
    }
  }

  ColorQuantizer {
    id: swatch

    source: scene.artFile
    depth: 3
    rescaleSize: 64
    onColorsChanged: {
      scene._readKey = scene.artKey;
      scene.readArt();
    }
  }

  // The parts the cover's colours play (Palette.js), or null with no cover to read. Kept by
  // hand, not bound: the quantiser goes on holding the last cover's colours when it is given
  // none or a new one, and they must not be taken for this song's. `_readKey` is the cover
  // its colours are of (a web cover by its address too, since every one is copied to one file).
  property var roles: null
  readonly property string artKey: artFile === "" ? "" : artFile + " " + (artRemote ? artUrl : "")
  property string _readKey: ""

  function readArt() {
    if (scene.artFile === "") {
      if (!scene.artWaiting)
        scene.roles = null;
      return;
    }
    if (scene._readKey !== scene.artKey)
      return;
    var list = [];
    for (var i = 0; i < swatch.colors.length; i++) {
      var c = swatch.colors[i];
      list.push({
        h: Math.max(0, c.hslHue),
        s: c.hslSaturation,
        l: c.hslLightness
      });
    }
    if (list.length > 0)
      scene.roles = Palette.roles(list);
  }

  function paint(part, fallback) {
    return scene.roles ? Qt.hsla(scene.roles[part].h, scene.roles[part].s, scene.roles[part].l, 1) : fallback;
  }

  // What the styles are handed. They follow the cover over the best part of a second, so a
  // new song's colours come up and are not switched to.
  property color ink: paint("ink", Theme.lyricInk)
  property color accent: paint("accent", Theme.accent)
  property color accent2: paint("second", Qt.color(Theme.palette.gold))
  property color accent3: paint("third", Qt.tint(Theme.accent, Theme.withAlpha(Qt.color(Theme.palette.gold), 0.5)))
  property color dim: paint("dim", Qt.hsla(0, 0, 0.55, 1))
  // What a black-and-white style is toned with: grey, leaning the cover's way.
  property color tone: paint("tone", Qt.hsla(0, 0, 0.5, 1))

  Behavior on ink {
    ColorAnimation {
      duration: Theme.lyricColourFade
    }
  }
  Behavior on accent {
    ColorAnimation {
      duration: Theme.lyricColourFade
    }
  }
  Behavior on accent2 {
    ColorAnimation {
      duration: Theme.lyricColourFade
    }
  }
  Behavior on accent3 {
    ColorAnimation {
      duration: Theme.lyricColourFade
    }
  }
  Behavior on dim {
    ColorAnimation {
      duration: Theme.lyricColourFade
    }
  }
  Behavior on tone {
    ColorAnimation {
      duration: Theme.lyricColourFade
    }
  }

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

    var at = Math.min(scene.segIndex, scene.plan.length - 1);
    var ease = scene._lensSet ? Math.min(1, dt * Theme.lyricLookRate) : 1;
    scene._lensSet = scene.frontItem !== null;
    scene.lensDepth += (scene.look("depth", 0) - scene.lensDepth) * ease;
    // A print in front says nothing of what a plain style wants: the last one's stands.
    var plain = scene._plain;
    if (scene.films[at] !== true) {
      plain.bloom += (scene.look("bloom", 0.45) - plain.bloom) * ease;
      plain.grain += (scene.look("grain", 0.05) - plain.grain) * ease;
      plain.vignette += (scene.look("vignette", 0.4) - plain.vignette) * ease;
      plain.ground += (scene.look("ground", 1) - plain.ground) * ease;
    }
    var stock = Director.lookAt(scene.plan, scene.films, scene.now, Theme.lyricFilmLead, Theme.lyricFilmTail);
    scene.stock = stock;
    scene.marks = Director.lookAt(scene.plan, scene.films, scene.now, 0, Theme.lyricFilmMarks);
    scene.lensBloom = Kinetic.lerp(plain.bloom, Theme.lyricFilmBloom, stock);
    scene.lensGrain = Kinetic.lerp(plain.grain, Theme.lyricFilmGrain, stock);
    scene.lensVignette = Kinetic.lerp(plain.vignette, Theme.lyricFilmVignette, stock);
    scene.lensGround = Kinetic.lerp(plain.ground, Theme.lyricFilmGround, stock);
    scene.lensVeil = Theme.lyricFilmVeil * stock;
    scene.lensSoftness = Theme.lyricFilmSoftness * stock;
    scene.lensMono = stock;
    scene.lensDust = scene.marks;
    scene.lensFlicker = scene.marks;
    // The song's own time says where the changes fall, so the lens is already going soft as
    // one comes. A stretch that carries on in the same style has no change to mark.
    var before = at > 0 && scene.plan[at - 1].style !== scene.seg.style;
    var after = at + 1 < scene.plan.length && scene.plan[at + 1].style !== scene.seg.style;
    var coming = after ? 1 - Kinetic.smooth(0, Theme.lyricRefocusIn, scene.seg.t1 - scene.now) : 0;
    var going = before ? 1 - Kinetic.smooth(0, Theme.lyricRefocusOut, scene.now - scene.seg.t0) : 0;
    scene.refocus = Theme.reduceMotion ? 0 : Math.max(coming, going);

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
    // Read off the model the plan was made from, not a binding that may not have followed yet.
    var lines = scene.model ? scene.model.lines : [];
    // The same style again, on the same song: it carries on with the new stretch, uncut.
    var playing = scene.frontItem;
    if (scene._shown !== null && playing && scene._shown.style === scene.seg.style && playing.lines === lines) {
      playing.seg = scene.seg;
      scene._shown = scene.seg;
      return;
    }
    var incoming = scene.front === 0 ? hostB : hostA;
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
      property real glow: (Theme.lyricGlow + Theme.lyricGlowKick * scene.kick + Theme.lyricGlowLevel * scene.level) * scene.lensGround
      property real stir: scene.stir
      property color tintA: scene.accent
      property color tintB: scene.accent2
      property color tintC: scene.accent3

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

  // ---- the soft plate: what a style wants out of focus ----

  // A style parents items here (`stage.softPlate`) and they are drawn small, blurred across and
  // down by the style's `softRadius`, and added to the picture by the lens. The plate and its
  // textures are the stage's own and last as long as it does: a blur made per line, with the
  // line, is where the one crash this stage has had came from.
  readonly property Item softPlate: plate
  readonly property bool softens: scene.look("softens", false) === true
  // One tap's stride on the plate's texture: the blur's own spread is three taps.
  readonly property real softStride: Math.max(0.02, scene.look("softRadius", 0) * scene.height / 100 / Theme.lyricSoftShrink / 3)

  Item {
    id: plate

    anchors.fill: parent
  }

  ShaderEffectSource {
    id: plateTexture

    sourceItem: plate
    hideSource: true
    live: scene.live && scene.softens
    textureSize: Qt.size(softAcross.width, softAcross.height)
    visible: false
  }

  // The two passes are kept visible and hidden by the textures that read them (`hideSource`):
  // an item that is not visible is never brought up to date, so a stride that changes, as this
  // one does with every focus pull, would stay what it was when the stage came up.
  ShaderEffect {
    id: softAcross

    width: Math.ceil(scene.width / Theme.lyricSoftShrink)
    height: Math.ceil(scene.height / Theme.lyricSoftShrink)

    property var source: plateTexture
    property point stride: Qt.point(scene.softStride / Math.max(1, width), 0)
    property real floorLuma: 0

    fragmentShader: Qt.resolvedUrl("../Shaders/lyricblur.frag.qsb")
  }

  ShaderEffectSource {
    id: softAcrossTexture

    sourceItem: softAcross
    hideSource: true
    live: scene.live && scene.softens
    textureSize: Qt.size(softAcross.width, softAcross.height)
    visible: false
  }

  ShaderEffect {
    id: softDown

    width: softAcross.width
    height: softAcross.height

    property var source: softAcrossTexture
    property point stride: Qt.point(0, scene.softStride / Math.max(1, height))
    property real floorLuma: 0

    fragmentShader: Qt.resolvedUrl("../Shaders/lyricblur.frag.qsb")
  }

  ShaderEffectSource {
    id: softTexture

    sourceItem: softDown
    hideSource: true
    live: scene.live && scene.softens
    textureSize: Qt.size(softAcross.width, softAcross.height)
    visible: false
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
    property point stride: Qt.point(Theme.lyricBloomSpread / Math.max(1, width), 0)
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
    property point stride: Qt.point(0, Theme.lyricBloomSpread / Math.max(1, height))
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
    property var softSource: softTexture
    property real softOn: scene.softens ? 1 : 0
    property real veil: scene.lensVeil
    // Pixels of softness as the copy of the picture that is that much smaller.
    property real softness: scene.lensSoftness * scene.pixelRatio > 1 ? Math.log2(scene.lensSoftness * scene.pixelRatio) : 0
    property size pixels: Qt.size(width * scene.pixelRatio, height * scene.pixelRatio)
    property real time: scene.wall
    property real bloom: scene.lensBloom + scene.look("bloomKick", 0.2) * scene.kick
    property real punch: scene.look("punchKick", 0) * scene.kick
    // The pull of focus at a change of style: a blur over everything (in device pixels), the
    // picture a little larger and a little darker while it lasts.
    property real haze: scene.refocus * Theme.lyricRefocusBlur * scene.height / 100 * scene.pixelRatio
    property real swell: scene.refocus * Theme.lyricRefocusSwell
    property real dip: scene.refocus * Theme.lyricRefocusDip
    property color tone: scene.tone
    property real depth: scene.lensDepth
    property real depthAt: scene.look("depthAt", 0.5)
    property real depthBand: scene.look("depthBand", 0.08)
    property real grain: scene.lensGrain
    property real vignette: scene.lensVignette
    property real mono: scene.lensMono
    property real dust: scene.lensDust
    property real flicker: scene.lensFlicker
    property real spot: scene.look("spot", 0)
    property real spotSize: scene.look("spotSize", 0.32)
    property point spotAt: scene.look("spotAt", Qt.point(0.5, 0.5))

    fragmentShader: Qt.resolvedUrl("../Shaders/lyricpost.frag.qsb")
  }
}
