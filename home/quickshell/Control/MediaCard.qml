import QtQuick
import QtQuick.Effects
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Services
import qs.Ui

Item {
  id: root

  readonly property var sink: Pipewire.defaultAudioSink

  readonly property string output: {
    if (!sink)
      return "No output";
    return sink.nickname || sink.description || sink.name;
  }

  readonly property bool hasArt: Media.artUrl !== "" && art.status === Image.Ready

  implicitHeight: Theme.controlMediaHeight

  PwObjectTracker {
    objects: root.sink ? [root.sink] : []
  }

  // Masked together so the blur cannot bleed past the card's corners.
  Item {
    id: ground

    anchors.fill: parent
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: mask
    }

    Rectangle {
      anchors.fill: parent
      color: Theme.surfaceRaised
    }

    // Overscanned: a blur sampling the card's own edge fades it out.
    Item {
      id: crop

      x: -40
      y: -40
      width: parent.width + 80
      height: parent.height + 80
      visible: false
      layer.enabled: true

      Image {
        id: art

        anchors.fill: parent
        source: Media.artUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
      }
    }

    MultiEffect {
      x: crop.x
      y: crop.y
      width: crop.width
      height: crop.height
      source: crop
      visible: root.hasArt
      blurEnabled: true
      blur: 0.6
      blurMax: 48
      blurMultiplier: 1
    }

    Rectangle {
      anchors.fill: parent
      color: Theme.withAlpha(Theme.canvas, root.hasArt ? 0.58 : 0.2)
    }
  }

  Item {
    id: mask

    anchors.fill: parent
    visible: false
    layer.enabled: true

    Rectangle {
      anchors.fill: parent
      radius: Theme.controlMediaRadius
      color: "black"
    }
  }

  Text {
    id: outputGlyph

    x: 16
    y: 13
    text: Volume.glyph(root.sink)
    color: Theme.inkSecondary
    font.family: Theme.iconFont
    font.pixelSize: Theme.controlMediaCaptionSize
  }

  Text {
    x: 36
    y: 13
    width: Math.max(0, root.width - x - 16)
    text: root.output
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlMediaCaptionSize
    elide: Text.ElideRight
  }

  Text {
    id: title

    x: 16
    y: 36
    width: Math.max(0, transport.x - x - 12)
    text: Media.active ? Media.title : "Nothing playing"
    color: Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlMediaTitleSize
    font.weight: Theme.weightSemi
    elide: Text.ElideRight
  }

  Text {
    x: title.x
    y: 61
    width: title.width
    visible: Media.artist !== ""
    text: Media.artist
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlMediaArtistSize
    elide: Text.ElideRight
  }

  // Previous, play/pause and next as three equal discs, centred on the title block.
  Row {
    id: transport

    x: root.width - width - 16
    y: 56 - height / 2
    spacing: Theme.controlMediaButtonGap

    Repeater {
      model: [
        {
          kind: "previous",
          name: "Previous track"
        },
        {
          kind: "toggle",
          name: "Play or pause"
        },
        {
          kind: "next",
          name: "Next track"
        }
      ]

      Rectangle {
        id: button

        required property var modelData

        readonly property bool hovered: buttonArea.containsMouse

        width: Theme.controlMediaButtonSize
        height: width
        radius: width / 2
        color: Theme.withAlpha(Theme.text, hovered && enabled ? Theme.controlMediaButtonHoverAlpha : Theme.controlMediaButtonAlpha)
        scale: buttonArea.pressed ? Theme.pressScale : 1
        enabled: Media.active
        // Dimmed with a layer, not bare opacity: the glyphs are filled and stroked in one
        // colour, and at half opacity that overlap composites twice into a bright ring
        // around each glyph. Rasterising first makes the dim even.
        opacity: enabled ? 1 : 0.5
        layer.enabled: opacity < 1

        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: modelData.kind === "toggle" ? (Media.playing ? "Pause" : "Play") : modelData.name
        Accessible.focusable: true
        Accessible.onPressAction: button.activate()

        function activate() {
          if (modelData.kind === "previous")
            Media.previous();
          else if (modelData.kind === "next")
            Media.next();
          else
            Media.toggle();
        }

        Behavior on color {
          Tint {}
        }

        Behavior on scale {
          Morph {
            duration: Theme.morphState
          }
        }

        TransportGlyph {
          anchors.centerIn: parent
          width: implicitWidth
          height: implicitHeight
          kind: button.modelData.kind === "toggle" ? (Media.playing ? "pause" : "play") : button.modelData.kind
          color: button.activeFocus ? Theme.focusRing : Theme.text
        }

        MouseArea {
          id: buttonArea

          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: button.activate()
        }

        Keys.onPressed: function (event) {
          if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            button.activate();
            event.accepted = true;
          }
        }
      }
    }
  }

  // The scrub bar. MPRIS reports position about once a second, so the thumb runs on its own
  // clock between reports and is pulled back only when a report disagrees; a drag previews
  // the time and seeks once, on release.
  Item {
    id: scrub

    readonly property real trackX: 16
    readonly property real trackW: root.width - 32
    readonly property real thumbR: Theme.controlMediaThumbSize / 2
    readonly property real trackCentre: Theme.controlMediaTrackY

    property real shown: 0
    property bool dragging: false
    property real dragFraction: 0

    readonly property real fraction: {
      if (dragging)
        return dragFraction;
      return Media.length > 0 ? Math.max(0, Math.min(1, shown / Media.length)) : 0;
    }

    readonly property real thumbX: trackX + thumbR + fraction * (trackW - thumbR * 2)

    // The hills rise when music plays and settle flat when it stops.
    property real swell: Media.playing && !Theme.reduceMotion ? 1 : 0
    property real phase: 0

    Behavior on swell {
      Morph {
        duration: Theme.duration(Theme.morphAmbient)
      }
    }

    anchors.fill: parent

    Connections {
      target: Media

      function onPositionChanged() {
        if (!scrub.dragging && (Math.abs(Media.position - scrub.shown) > 0.75 || !Media.playing))
          scrub.shown = Media.position;
      }

      function onPlayerChanged() {
        scrub.shown = Media.position;
      }
    }

    Component.onCompleted: shown = Media.position

    FrameAnimation {
      // Media.trackPosition is held true only while the control centre is showing.
      running: Media.trackPosition && (Media.playing || scrub.swell > 0.001)
      onTriggered: {
        if (Media.playing && Media.length > 0)
          scrub.shown = Math.min(Media.length, scrub.shown + frameTime);
        if (!Theme.reduceMotion)
          scrub.phase += frameTime;
        hills.requestPaint();
      }
    }

    // Three layers in darker shades of the accent, each two slow sine waves under an envelope
    // that rises from the start of the track and eases off into the thumb. Positions are taken
    // against the whole track, so the waves stay put as the played part grows, not stretching.
    Canvas {
      id: hills

      x: scrub.trackX
      y: scrub.trackCentre - Theme.controlMediaHillHeight
      width: scrub.trackW
      height: Theme.controlMediaHillHeight
      visible: scrub.swell > 0.001

      readonly property var layers: [
        {
          ink: Qt.darker(Theme.accent, 1.5),
          alpha: 0.85,
          f1: 0.045,
          f2: 0.11,
          s1: 0.9,
          s2: -1.3,
          k: 1
        },
        {
          ink: Qt.darker(Theme.accent, 2),
          alpha: 0.8,
          f1: 0.07,
          f2: 0.031,
          s1: -0.7,
          s2: 1.1,
          k: 0.8
        },
        {
          ink: Qt.darker(Theme.accent, 2.6),
          alpha: 0.75,
          f1: 0.028,
          f2: 0.083,
          s1: 1.4,
          s2: 0.6,
          k: 0.62
        }
      ]

      function ease(edge0, edge1, x) {
        var t = Math.max(0, Math.min(1, (x - edge0) / Math.max(1, edge1 - edge0)));
        return t * t * (3 - 2 * t);
      }

      onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        var w = scrub.thumbX - scrub.trackX;
        if (w < 4 || scrub.swell <= 0.001)
          return;
        for (var i = 0; i < layers.length; i++) {
          var l = layers[i];
          ctx.fillStyle = "rgba(" + Math.round(l.ink.r * 255) + "," + Math.round(l.ink.g * 255) + "," + Math.round(l.ink.b * 255) + "," + l.alpha + ")";
          ctx.beginPath();
          ctx.moveTo(0, height);
          for (var x = 0; x <= w; x += 2) {
            var envelope = ease(0, w * 0.3, x) * (1 - 0.6 * ease(w - 36, w, x));
            var wave = (Math.sin(x * l.f1 + scrub.phase * l.s1) + Math.sin(x * l.f2 + scrub.phase * l.s2)) / 2;
            var h = height * l.k * scrub.swell * envelope * (0.55 + 0.45 * wave);
            ctx.lineTo(x, height - h);
          }
          ctx.lineTo(w, height);
          ctx.closePath();
          ctx.fill();
        }
      }
    }

    Rectangle {
      x: scrub.trackX
      y: scrub.trackCentre - height / 2
      width: scrub.trackW
      height: Theme.controlMediaTrackHeight
      radius: height / 2
      color: Theme.withAlpha(Theme.text, Theme.controlMediaTrackAlpha)

      Rectangle {
        width: scrub.thumbX - scrub.trackX
        height: parent.height
        radius: height / 2
        color: Theme.accent
      }
    }

    Rectangle {
      x: scrub.thumbX - width / 2
      y: scrub.trackCentre - height / 2
      width: Theme.controlMediaThumbSize
      height: width
      radius: width / 2
      visible: Media.length > 0
      // A shade under the played track, so the thumb still reads against it without a ring.
      color: Qt.darker(Theme.accent, Theme.controlMediaThumbShade)
      border.width: scrubArea.activeFocus ? Theme.controlMediaThumbRing : 0
      border.color: Theme.focusRing
      scale: scrub.dragging ? Theme.controlMediaThumbPressScale : 1

      Behavior on scale {
        enabled: !Theme.reduceMotion

        MicroSpring {}
      }
    }

    Text {
      x: scrub.trackX
      y: Theme.controlMediaTimeY
      text: root.clock(scrub.fraction * Media.length)
      color: Theme.inkSecondary
      font.family: Theme.uiFont
      font.pixelSize: Theme.controlMediaCaptionSize
      font.features: {
        "tnum": 1
      }
    }

    Text {
      x: scrub.trackX + scrub.trackW - width
      y: Theme.controlMediaTimeY
      text: root.clock(Media.length)
      color: Theme.inkSecondary
      font.family: Theme.uiFont
      font.pixelSize: Theme.controlMediaCaptionSize
      font.features: {
        "tnum": 1
      }
    }

    // Taller than the drawn track, so the thumb is easy to catch.
    MouseArea {
      id: scrubArea

      x: scrub.trackX - scrub.thumbR
      y: scrub.trackCentre - 14
      width: scrub.trackW + scrub.thumbR * 2
      height: 28
      enabled: Media.seekable
      cursorShape: Qt.PointingHandCursor
      preventStealing: true

      activeFocusOnTab: Media.seekable
      Accessible.role: Accessible.Slider
      Accessible.name: "Seek"
      Accessible.description: root.clock(scrub.fraction * Media.length) + " of " + root.clock(Media.length)

      function fractionAt(px) {
        var local = px + x - scrub.trackX - scrub.thumbR;
        return Math.max(0, Math.min(1, local / Math.max(1, scrub.trackW - scrub.thumbR * 2)));
      }

      onPressed: function (mouse) {
        forceActiveFocus();
        scrub.dragFraction = fractionAt(mouse.x);
        scrub.dragging = true;
      }

      onPositionChanged: function (mouse) {
        if (pressed)
          scrub.dragFraction = fractionAt(mouse.x);
      }

      onReleased: {
        Media.seek(scrub.dragFraction);
        scrub.shown = scrub.dragFraction * Media.length;
        scrub.dragging = false;
      }

      onCanceled: scrub.dragging = false

      // Five seconds a press, like a player's own arrow keys.
      Keys.onPressed: function (event) {
        if (Media.length <= 0 || (event.key !== Qt.Key_Left && event.key !== Qt.Key_Right))
          return;
        var to = Math.max(0, Math.min(Media.length, scrub.shown + (event.key === Qt.Key_Right ? 5 : -5)));
        Media.seek(to / Media.length);
        scrub.shown = to;
        event.accepted = true;
      }
    }
  }

  // "02:05", as One UI writes it; an hour or more gains its own field.
  function clock(seconds) {
    if (!(seconds > 0))
      return "00:00";
    var s = Math.floor(seconds % 60), m = Math.floor(seconds / 60) % 60, h = Math.floor(seconds / 3600);
    var two = function (n) {
      return n < 10 ? "0" + n : "" + n;
    };
    return (h > 0 ? h + ":" : "") + two(m) + ":" + two(s);
  }
}
