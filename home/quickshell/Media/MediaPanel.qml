import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Bar.Widgets
import qs.Commons
import qs.Services
import qs.Ui

// Now playing: the track's cover bled in from the left, and beside it where the sound goes, the
// title and artist, the scrub bar and the transport. Opened from the keyboard or by a click on
// the hover card's cover, title and artist, which it carries on: out of the open card those three
// grow into this panel's own (`takesCard`, Ui/IslandOrigin.qml). It is only there while
// something plays.
Variants {
  id: root

  model: Quickshell.screens

  IslandSurface {
    id: win

    key: "media"
    openWidth: Theme.mediaWidth
    openHeight: Theme.mediaHeight
    openRadius: Theme.mediaRadius
    openable: Media.active

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property string output: {
      if (!sink)
        return "No output";
      return sink.nickname || sink.description || sink.name;
    }
    readonly property real columnMid: (Theme.mediaColumnLeft + Theme.mediaColumnRight) / 2
    readonly property color quietInk: Theme.withAlpha(Theme.text, Theme.mediaSecondaryAlpha)

    PwObjectTracker {
      objects: win.sink ? [win.sink] : []
    }

    // The player gone, so is the panel; one that only passes through "stopped" on its way to the
    // next track is given a moment.
    Timer {
      interval: Theme.mediaGoneGrace
      running: win.open && !Media.active
      onTriggered: win.hide()
    }

    // The scrub bar needs MPRIS polled, for as long as it is on screen.
    onShowingChanged: Media.holdPosition(win.key + "@" + win.screenName, win.showing)
    Component.onDestruction: Media.holdPosition(win.key + "@" + win.screenName, false)

    Panel {
      surface: win
      takesActivate: true
      takesMove: true

      onActivated: Media.toggle()

      // Along the track by a player's own five seconds; up and down are the tracks either side.
      onMoved: function (dx, dy) {
        if (dx !== 0)
          scrub.nudge(5 * dx);
        else if (dy > 0)
          Media.next();
        else
          Media.previous();
      }

      onKeyPressed: function (event) {
        if (event.key === Qt.Key_N)
          Media.next();
        else if (event.key === Qt.Key_P)
          Media.previous();
        else
          return;
        event.accepted = true;
      }

      CoverBleed {
        width: Theme.mediaBleedWidth
        height: Theme.mediaHeight
      }

      Text {
        id: outputGlyph

        objectName: "outputGlyph"
        x: Theme.mediaColumnLeft
        y: Theme.mediaOutputMid - height / 2
        text: Volume.glyphFor(win.sink)
        color: win.quietInk
        font.family: Theme.iconFont
        font.pixelSize: Theme.mediaOutputGlyph
      }

      Text {
        objectName: "output"
        x: outputGlyph.x + Theme.mediaOutputGlyph + Theme.mediaOutputGap
        y: Theme.mediaOutputMid - height / 2
        width: Math.max(0, equaliser.x - 12 - x)
        text: win.output
        color: win.quietInk
        font.family: Theme.uiFont
        font.pixelSize: Theme.mediaCaptionSize
        elide: Text.ElideRight
      }

      Equaliser {
        id: equaliser

        x: Theme.mediaColumnRight - width
        y: Theme.mediaOutputMid - height / 2
        playing: Media.playing
        restsFlat: true
      }

      Text {
        // A content-morph anchor (Ui/MorphScan.js): the hover card's title, and the media card's.
        property string morphRole: "title"
        property string morphKey: "media.title"

        x: Theme.mediaColumnLeft
        y: Theme.mediaTitleMid - height / 2
        width: Theme.mediaColumnRight - x
        text: Media.title
        color: Theme.text
        font.family: Theme.uiFont
        font.pixelSize: Theme.mediaTitleSize
        font.weight: Theme.weightSemi
        elide: Text.ElideRight
      }

      Text {
        property string morphRole: "artist"
        property string morphKey: "media.artist"

        x: Theme.mediaColumnLeft
        y: Theme.mediaArtistMid - height / 2
        width: Theme.mediaColumnRight - x
        text: Media.artist
        color: win.quietInk
        font.family: Theme.uiFont
        font.pixelSize: Theme.mediaArtistSize
        elide: Text.ElideRight
      }

      // The control centre's scrub bar, hills and all, with what is left counted down.
      MediaScrub {
        id: scrub

        x: Theme.mediaColumnLeft
        width: Theme.mediaColumnRight - x
        height: parent.height
        trackY: Theme.mediaTrackY
        timeY: Theme.mediaTimeMid - timeHeight / 2
        countsDown: true
        padded: false
      }

      // Shuffle and repeat at the column's ends, each only where the player has it: quiet until on.
      Button {
        x: Theme.mediaColumnLeft
        y: Theme.mediaTransportMid - height / 2
        visible: Media.shuffleSupported
        kind: Button.Icon
        icon: Icons.shuffle
        iconSize: Theme.mediaModeGlyph
        baseColor: Media.shuffle ? Theme.accent : Theme.subtle
        hoverColor: Media.shuffle ? Theme.accent : Theme.text
        morphKey: "media.shuffle"
        checkable: true
        checked: Media.shuffle
        accessibleName: "Shuffle"
        onClicked: Media.toggleShuffle()
      }

      Button {
        x: Theme.mediaColumnRight - width
        y: Theme.mediaTransportMid - height / 2
        visible: Media.loopSupported
        kind: Button.Icon
        icon: Media.loop === "track" ? Icons.repeatOne : Icons.repeat
        iconSize: Theme.mediaModeGlyph
        baseColor: Media.loop !== "none" ? Theme.accent : Theme.subtle
        hoverColor: Media.loop !== "none" ? Theme.accent : Theme.text
        morphKey: "media.repeat"
        checkable: true
        checked: Media.loop !== "none"
        accessibleName: Media.loop === "track" ? "Repeat this track" : Media.loop === "playlist" ? "Repeat all" : "Repeat"
        onClicked: Media.cycleLoop()
      }

      Button {
        x: win.columnMid - Theme.mediaSkipOffset - width / 2
        y: Theme.mediaTransportMid - height / 2
        kind: Button.Disc
        icon: Icons.previous
        iconSize: Theme.mediaSkipGlyph
        morphKey: "media.previous"
        accessibleName: "Previous track"
        onClicked: Media.previous()
      }

      // The one accent in the panel: a filled pill made a disc.
      Button {
        x: win.columnMid - width / 2
        y: Theme.mediaTransportMid - height / 2
        width: Theme.mediaPlaySize
        height: Theme.mediaPlaySize
        kind: Button.Primary
        icon: Media.playing ? Icons.pause : Icons.play
        iconSize: Theme.mediaPlayGlyph
        morphKey: "media.toggle"
        accessibleName: Media.playing ? "Pause" : "Play"
        onClicked: Media.toggle()
      }

      Button {
        x: win.columnMid + Theme.mediaSkipOffset - width / 2
        y: Theme.mediaTransportMid - height / 2
        kind: Button.Disc
        icon: Icons.next
        iconSize: Theme.mediaSkipGlyph
        morphKey: "media.next"
        accessibleName: "Next track"
        onClicked: Media.next()
      }
    }
  }
}
