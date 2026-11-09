import QtQuick
import QtQuick.Effects
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Services
import qs.Ui

Item {
  id: root

  // A content-morph anchor (Ui/MorphScan.js): what it is, and what pairs it across panels.
  property string morphRole: "media"
  property string morphKey: "media"
  property var morphSlot: undefined

  readonly property var sink: Pipewire.defaultAudioSink

  readonly property string output: {
    if (!sink)
      return "No output";
    return sink.nickname || sink.description || sink.name;
  }

  readonly property bool hasArt: art.hasArt

  implicitHeight: Theme.controlMediaHeight

  PwObjectTracker {
    objects: root.sink ? [root.sink] : []
  }

  // Masked together so the blur cannot bleed past the card's corners.
  RoundedClip {
    id: ground

    anchors.fill: parent
    radius: Theme.controlMediaRadius

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

      // A new cover fades in over the last one here, under the blur.
      ArtFade {
        id: art

        anchors.fill: parent
        source: Media.artUrl
      }
    }

    MultiEffect {
      x: crop.x
      y: crop.y
      width: crop.width
      height: crop.height
      source: crop
      // The blurred cover arrives and leaves on a fade, with the scrim below following it.
      opacity: art.presence
      visible: opacity > 0
      blurEnabled: true
      blur: 0.6
      blurMax: 48
      blurMultiplier: 1
    }

    Rectangle {
      anchors.fill: parent
      color: Theme.withAlpha(Theme.canvas, 0.2 + 0.38 * art.presence)
    }
  }

  Text {
    id: outputGlyph

    x: 16
    y: 13
    text: Volume.glyphFor(root.sink)
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

      Button {
        id: button

        required property var modelData

        kind: Button.Disc
        size: Button.Large
        // Large enough that play's triangle keeps the ink the hand-drawn one had (about 13 x 15).
        iconSize: 30
        icon: Icons.transportGlyph(button.modelData.kind === "toggle" ? (Media.playing ? "pause" : "play") : button.modelData.kind)
        enabled: Media.active
        accessibleName: modelData.kind === "toggle" ? (Media.playing ? "Pause" : "Play") : modelData.name
        onClicked: {
          if (modelData.kind === "previous")
            Media.previous();
          else if (modelData.kind === "next")
            Media.next();
          else
            Media.toggle();
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
      }
    }

    // Three layers in darker shades of the accent, each two slow sine waves under an envelope
    // that rises from the start of the track and eases off into the thumb. Positions are taken
    // against the whole track, so the waves stay put as the played part grows, not stretching.
    // Drawn on the GPU (Shaders/hills.frag); the waves' frequencies and speeds live there.
    ShaderEffect {
      id: hills

      x: scrub.trackX
      y: scrub.trackCentre - Theme.controlMediaHillHeight
      width: scrub.trackW
      height: Theme.controlMediaHillHeight
      visible: scrub.swell > 0.001 && scrub.thumbX - scrub.trackX >= 4

      property real phase: scrub.phase
      property size itemSize: Qt.size(width, height)
      property real amplitude: scrub.swell
      property real progress: (scrub.thumbX - scrub.trackX) / Math.max(1, scrub.trackW)
      property color ink0: shade(1.5, 0.85)
      property color ink1: shade(2, 0.8)
      property color ink2: shade(2.6, 0.75)

      // The accent darkened, with the layer's own opacity (Qt premultiplies it on the way to the shader).
      function shade(by, alpha) {
        var c = Qt.darker(Theme.accent, by);
        return Qt.rgba(c.r, c.g, c.b, alpha);
      }

      fragmentShader: Qt.resolvedUrl("../Shaders/hills.frag.qsb")
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
      scale: thumbScale.value

      MorphSpring {
        id: thumbScale

        target: scrub.dragging ? Theme.controlMediaThumbPressScale : 1
        omega: Theme.microOmega
        epsilon: 0.001
        label: "media.thumb"
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
