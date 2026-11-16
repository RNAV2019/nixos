import QtQuick
import Quickshell.Services.Pipewire
import qs.Bar.Widgets
import qs.Commons
import qs.Services
import qs.Ui

// What is playing, in the control centre: the track's cover bled in from the card's left at its
// full height, and beside it a column of where the sound goes, the title and artist, the scrub
// bar and the transport. With no cover the column takes the whole card; with nothing playing it
// says so, and the transport waits.
Item {
  id: root

  // A content-morph anchor (Ui/MorphScan.js): what it is, and what pairs it across panels.
  property string morphRole: "media"
  property string morphKey: "media"

  readonly property var sink: Pipewire.defaultAudioSink

  readonly property string output: {
    if (!sink)
      return "No output";
    return sink.nickname || sink.description || sink.name;
  }

  // The column starts past the cover's far end, on clean ground, and at the card's own inset
  // where there is no cover; it moves over as a cover comes or goes.
  readonly property real columnLeft: Theme.controlMediaInset + (Theme.controlMediaColumnLeft - Theme.controlMediaInset) * bleed.presence
  readonly property real columnRight: width - Theme.controlMediaInset
  readonly property real columnMid: (columnLeft + columnRight) / 2
  readonly property color quietInk: Theme.withAlpha(Theme.text, Theme.mediaSecondaryAlpha)

  implicitHeight: Theme.controlMediaHeight

  PwObjectTracker {
    objects: root.sink ? [root.sink] : []
  }

  // The card's ground and the cover on it, cropped together to the card's corners.
  RoundedClip {
    anchors.fill: parent
    radius: Theme.controlMediaRadius

    Rectangle {
      anchors.fill: parent
      color: Theme.surfaceRaised
    }

    CoverBleed {
      id: bleed

      width: Theme.controlMediaBleedWidth
      height: parent.height
      ground: Theme.surfaceRaised
    }
  }

  Text {
    id: outputGlyph

    objectName: "outputGlyph"
    x: root.columnLeft
    y: Theme.controlMediaOutputMid - height / 2
    text: Volume.glyphFor(root.sink)
    color: root.quietInk
    font.family: Theme.iconFont
    font.pixelSize: Theme.controlMediaOutputGlyph
  }

  Text {
    objectName: "output"
    x: outputGlyph.x + Theme.controlMediaOutputGlyph + Theme.controlMediaOutputGap
    y: Theme.controlMediaOutputMid - height / 2
    width: Math.max(0, equaliser.x - 12 - x)
    text: root.output
    color: root.quietInk
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlMediaCaptionSize
    elide: Text.ElideRight
  }

  Equaliser {
    id: equaliser

    x: root.columnRight - width
    y: Theme.controlMediaOutputMid - height / 2
    playing: Media.playing
    restsFlat: true
  }

  Text {
    // An anchor of its own inside the card's: the hover card's title is this one.
    property string morphRole: "title"
    property string morphKey: "media.title"

    x: root.columnLeft
    y: Theme.controlMediaTitleMid - height / 2
    width: Math.max(0, root.columnRight - x)
    text: Media.active ? Media.title : "Nothing playing"
    color: Theme.text
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlMediaTitleSize
    font.weight: Theme.weightSemi
    elide: Text.ElideRight
  }

  Text {
    property string morphRole: "artist"
    property string morphKey: "media.artist"

    x: root.columnLeft
    y: Theme.controlMediaArtistMid - height / 2
    width: Math.max(0, root.columnRight - x)
    visible: Media.artist !== ""
    text: Media.artist
    color: root.quietInk
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlMediaArtistSize
    elide: Text.ElideRight
  }

  // The scrub bar, hills and all, with what is left counted down.
  MediaScrub {
    x: root.columnLeft
    width: Math.max(0, root.columnRight - x)
    height: parent.height
    trackY: Theme.controlMediaTrackY
    timeY: Theme.controlMediaTimeMid - timeHeight / 2
    countsDown: true
    padded: false
  }

  // Shuffle and repeat at the column's ends, each only where the player has it: quiet until on.
  Button {
    x: root.columnLeft
    y: Theme.controlMediaTransportMid - height / 2
    visible: Media.shuffleSupported
    kind: Button.Icon
    icon: Icons.shuffle
    iconSize: Theme.controlMediaModeGlyph
    baseColor: Media.shuffle ? Theme.accent : Theme.subtle
    hoverColor: Media.shuffle ? Theme.accent : Theme.text
    morphKey: "media.shuffle"
    checkable: true
    checked: Media.shuffle
    accessibleName: "Shuffle"
    onClicked: Media.toggleShuffle()
  }

  Button {
    x: root.columnRight - width
    y: Theme.controlMediaTransportMid - height / 2
    visible: Media.loopSupported
    kind: Button.Icon
    icon: Media.loop === "track" ? Icons.repeatOne : Icons.repeat
    iconSize: Theme.controlMediaModeGlyph
    baseColor: Media.loop !== "none" ? Theme.accent : Theme.subtle
    hoverColor: Media.loop !== "none" ? Theme.accent : Theme.text
    morphKey: "media.repeat"
    checkable: true
    checked: Media.loop !== "none"
    accessibleName: Media.loop === "track" ? "Repeat this track" : Media.loop === "playlist" ? "Repeat all" : "Repeat"
    onClicked: Media.cycleLoop()
  }

  Button {
    x: root.columnMid - Theme.controlMediaSkipOffset - width / 2
    y: Theme.controlMediaTransportMid - height / 2
    kind: Button.Disc
    icon: Icons.previous
    iconSize: Theme.controlMediaSkipGlyph
    morphKey: "media.previous"
    enabled: Media.active
    accessibleName: "Previous track"
    onClicked: Media.previous()
  }

  // The one accent in the card: a filled pill made a disc.
  Button {
    x: root.columnMid - width / 2
    y: Theme.controlMediaTransportMid - height / 2
    width: Theme.controlMediaPlaySize
    height: Theme.controlMediaPlaySize
    kind: Button.Primary
    icon: Media.playing ? Icons.pause : Icons.play
    iconSize: Theme.controlMediaPlayGlyph
    morphKey: "media.toggle"
    enabled: Media.active
    accessibleName: Media.playing ? "Pause" : "Play"
    onClicked: Media.toggle()
  }

  Button {
    x: root.columnMid + Theme.controlMediaSkipOffset - width / 2
    y: Theme.controlMediaTransportMid - height / 2
    kind: Button.Disc
    icon: Icons.next
    iconSize: Theme.controlMediaSkipGlyph
    morphKey: "media.next"
    enabled: Media.active
    accessibleName: "Next track"
    onClicked: Media.next()
  }
}
