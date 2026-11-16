import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Services
import qs.Ui
import "Kinetic.js" as Kinetic
import "Palette.js" as Palette
import "Parse.js" as Parse

// The lyric stage's picture on one screen: the ground, the style the words are drawn in (and
// the one it was changed from, for the length of the change), the lens they are seen through,
// and over that the song's name in a corner.
//
// One clock runs it. `now` is the player's position in the song, read every frame, and the
// style draws from `now` alone. `kick` jumps as each word lands and dies away, and with the
// player's loudness (`level`) it is what the ground's light moves to.
Item {
  id: scene

  // The window is mapped. Nothing here runs or holds a texture otherwise.
  property bool live: false
  // For tests and the curious: a time to hold the song at (seconds; -1 follows the player).
  property real pinned: -1
  // The style the words are drawn in: a file in Styles/.
  property string styleName: Theme.lyricStyles[0]
  // Seconds the words run ahead of the player's own clock.
  property real offset: 0
  // Device pixels per item pixel.
  property real pixelRatio: 1

  // The song's time and the wall's, both in seconds; the second never stops or jumps.
  property real now: 0
  property real wall: 0
  property real kick: 0
  property real level: 0
  // The kicks so far, summed: the ground's field is pushed along by it.
  property real stir: 0

  property real _estimate: 0

  readonly property var model: Lyrics.state === "ready" ? Lyrics.model : null
  readonly property var lines: model ? model.lines : []

  // What is said in the middle of the stage while there are no words to show.
  readonly property string status: {
    if (!Media.active)
      return "Nothing is playing";
    if (Lyrics.state === "loading")
      return "Finding the words";
    if (Lyrics.state === "none")
      return "No timed lyrics for this one";
    return "";
  }

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
  property color dim: paint("dim", Qt.hsla(0, 0, 0.55, 1))

  // What the ground is lit with: the cover's own colours as they are on the sleeve, the one it
  // has most of first, not lifted to read as type the way the ink and the accent are.
  function lit(i, fallback) {
    if (!scene.roles)
      return fallback;
    var c = scene.roles.wash[i];
    return Qt.hsla(c.h, c.s, c.l, 1);
  }

  property color washA: lit(0, Theme.accent)
  property color washB: lit(1, Qt.color(Theme.palette.gold))
  property color washC: lit(2, Qt.tint(Theme.accent, Theme.withAlpha(Qt.color(Theme.palette.gold), 0.5)))
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
  Behavior on washA {
    ColorAnimation {
      duration: Theme.lyricColourFade
    }
  }
  Behavior on washB {
    ColorAnimation {
      duration: Theme.lyricColourFade
    }
  }
  Behavior on washC {
    ColorAnimation {
      duration: Theme.lyricColourFade
    }
  }
  Behavior on dim {
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
    scene.kick = Theme.reduceMotion ? 0 : k;
    scene.stir += scene.kick * dt;

    var heard = meter.enabled ? meter.peak : 0;
    scene.level += (heard - scene.level) * Math.min(1, dt * (heard > scene.level ? 30 : 4));
  }

  // ---- the style: two hosts, the one in front drawing the song ----

  property int front: 0
  readonly property var frontItem: front === 0 ? hostA.item : hostB.item
  // What the host in front was put up with.
  property string _style: ""
  property var _lines: null

  // Puts the style up, or changes it: a change of style (N and P) and a change of song both
  // bring the new one up in the other host and fade the two across.
  function change() {
    if (!scene.live) {
      scene._style = "";
      scene._lines = null;
      hostA.source = "";
      hostB.source = "";
      return;
    }
    // Read off the model, not a binding that may not have followed yet.
    var lines = scene.model ? scene.model.lines : [];
    if (scene._style === scene.styleName && scene._lines === lines)
      return;
    var incoming = scene.front === 0 ? hostB : hostA;
    incoming.setSource(Qt.resolvedUrl("Styles/" + scene.styleName + ".qml"), {
      stage: scene,
      lines: lines
    });
    if (incoming.status === Loader.Error)
      console.warn("Lyrics: no style " + scene.styleName);
    scene._style = scene.styleName;
    scene._lines = lines;
    scene.front = 1 - scene.front;
  }

  onStyleNameChanged: change()
  onModelChanged: change()
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
      property color tintA: scene.washA
      property color tintB: scene.washB
      property color tintC: scene.washC

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

  // Mipmapped, because what is out of focus is read from its smaller copies.
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
    anchors.fill: parent

    property var source: picture
    property size pixels: Qt.size(width * scene.pixelRatio, height * scene.pixelRatio)
    property real time: scene.wall
    property real depth: scene.look("depth", 0)
    property real depthAt: scene.look("depthAt", 0.5)
    property real depthBand: scene.look("depthBand", 0.08)

    fragmentShader: Qt.resolvedUrl("../Shaders/lyricpost.frag.qsb")
  }

  // ---- over the lens: what is said with no words to show, and the song's name ----

  Text {
    anchors.centerIn: parent
    visible: scene.model === null && text !== ""
    text: scene.status
    color: scene.dim
    font.family: Theme.uiFont
    font.pixelSize: Math.max(1, Math.round(2.4 * scene.height / 100))
    font.weight: Theme.weightMedium
  }

  // The cover and the song's name, small in a corner. It creeps round a slow loop, since it is
  // the one thing on the stage that would otherwise sit still for a whole song on an OLED panel.
  Row {
    readonly property real u: scene.height / 100

    x: 0.034 * scene.width + 1.2 * u * Math.sin(scene.wall * 0.021)
    y: 0.895 * scene.height + 0.8 * u * Math.cos(scene.wall * 0.017)
    spacing: 1.75 * u
    opacity: 0.62
    visible: Media.active && Lyrics.track.title !== ""

    RoundedClip {
      width: 5.5 * parent.u
      height: width
      radius: 1.1 * parent.u
      visible: scene.artFile !== ""

      Image {
        anchors.fill: parent
        source: scene.artFile
        sourceSize: Qt.size(128, 128)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
      }
    }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 0.3 * parent.u

      Text {
        text: Lyrics.track.title
        color: scene.ink
        font.family: Theme.lyricFont
        font.pixelSize: Math.max(1, Math.round(2.25 * scene.height / 100))
        font.weight: Font.Bold
      }

      Text {
        text: Lyrics.track.artist
        visible: text !== ""
        color: scene.ink
        opacity: 0.6
        font.family: Theme.lyricFont
        font.pixelSize: Math.max(1, Math.round(1.9 * scene.height / 100))
        font.weight: Font.Medium
      }
    }
  }
}
