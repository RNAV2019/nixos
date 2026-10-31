import QtQuick
import qs.Commons

// The board's `Island pill`: the contents of a single 42 px island row in one of its eight
// layouts. It lays itself out at its final size, so the surface growing around it uncovers placed
// contents; callers centre it in the TransientSurface. Right-anchored parts follow `width`, the
// waveform stays centred, as does the caption of `glyphLabelAction`, so a card row can be wider
// than a pill.
//
// The glyph is whatever the caller puts inside (a StrokeIcon, a Text, a Spinner), centred in its
// slot; the waveform goes in `waveform`. Everything else is the row's own: the label, detail and
// reading texts, a LevelTrack, the cancel ×, the three dots, and the alert outline.
Item {
  id: root

  // glyphTrackReading, glyphLabelTrackReading, glyphLabelReading, glyphTrackReadingAction,
  // glyphWaveformReadingAction, glyphLabelAction, glyphLabelDetailReading or glyphLabelDetailDots.
  property string layout: "glyphTrackReading"

  // The state is wrong: the pill is outlined in love.
  property bool alert: false

  property string label: ""
  property string detail: ""
  property string reading: ""
  property color labelColor: captioned ? Theme.inkSecondary : Theme.inkPrimary
  property color detailColor: wide ? Theme.accentFill : Theme.inkPrimary
  property color readingColor: wide ? Theme.inkSecondary : Theme.inkPrimary
  property int labelElide: Text.ElideRight

  // Digits of a fixed width, for a reading that counts.
  property bool tabularReading: false

  // The track, as LevelTrack takes them.
  property real value: 0
  property bool indeterminate: false
  property bool showFill: true
  property int fillDuration: Theme.duration(Theme.morphProgress)

  // The track's sweep and the dots only move while the surface is up.
  property bool running: true

  signal cancelled

  default property alias glyph: glyphSlot.data
  property alias waveform: waveformSlot.data

  readonly property bool wide: layout === "glyphLabelDetailReading"
  readonly property bool captioned: layout === "glyphLabelAction" || layout === "glyphLabelDetailDots"
  readonly property bool hasLabel: layout === "glyphLabelTrackReading" || layout === "glyphLabelReading" || captioned || wide
  readonly property bool hasDetail: wide || layout === "glyphLabelDetailDots"
  readonly property bool hasTrack: layout === "glyphTrackReading" || layout === "glyphLabelTrackReading" || layout === "glyphTrackReadingAction"
  readonly property bool hasWaveform: layout === "glyphWaveformReadingAction"
  readonly property bool hasReading: layout !== "glyphLabelAction" && layout !== "glyphLabelDetailDots"
  readonly property bool hasAction: layout === "glyphTrackReadingAction" || hasWaveform || layout === "glyphLabelAction"
  readonly property bool hasDots: layout === "glyphLabelDetailDots"

  // Where each part of this layout sits; what a layout does not use stays 0.
  function placement(name) {
    var base = {
      glyphTop: Theme.islandPillGlyphTop,
      glyphSize: Theme.islandPillGlyphSize,
      labelLeft: Theme.islandPillTextLeft,
      labelWidth: 0,
      labelSize: Theme.nearbyRowNameSize,
      labelWeight: Theme.weightMedium,
      labelAlign: Text.AlignLeft,
      detailLeft: 0,
      detailWidth: 0,
      detailSize: Theme.nearbyRowNameSize,
      detailWeight: Theme.weightSemi,
      trackLeft: 0,
      trackWidth: 0,
      readingInset: Theme.islandPillReadingInset,
      readingTop: Theme.islandPillTextTop,
      readingWidth: Theme.islandPillReadingWidth,
      readingSize: Theme.islandPillReadingSize,
      readingWeight: Theme.weightSemi
    };
    switch (name) {
    case "glyphTrackReading":
      return Object.assign(base, {
        trackLeft: Theme.islandPillTrackLeft,
        trackWidth: Theme.islandPillTrackWidth
      });
    case "glyphLabelTrackReading":
      return Object.assign(base, {
        labelWidth: Theme.islandPillLabelWidthTrack,
        trackLeft: Theme.islandPillTrackLeftLabel,
        trackWidth: Theme.islandPillTrackWidthLabel
      });
    case "glyphLabelReading":
      return Object.assign(base, {
        labelWidth: Theme.islandPillLabelWidthWide
      });
    case "glyphTrackReadingAction":
      return Object.assign(base, {
        trackLeft: Theme.islandPillTrackLeft,
        trackWidth: Theme.islandPillTrackWidthAction,
        readingInset: Theme.islandPillReadingInsetAction
      });
    case "glyphWaveformReadingAction":
      return Object.assign(base, {
        readingInset: Theme.islandPillReadingInsetWaveform
      });
    case "glyphLabelAction":
      return Object.assign(base, {
        labelWidth: Theme.islandPillLabelWidthAction,
        labelSize: Theme.islandPillCaptionSize,
        labelAlign: Text.AlignHCenter
      });
    case "glyphLabelDetailReading":
      return Object.assign(base, {
        glyphTop: Theme.islandPillGlyphTopWide,
        glyphSize: Theme.islandPillGlyphSizeWide,
        labelLeft: Theme.islandPillLabelLeftDetail,
        labelWidth: Theme.islandPillLabelWidthDetail,
        labelWeight: Theme.weightSemi,
        detailLeft: Theme.islandPillDetailLeft,
        detailWidth: Theme.islandPillDetailWidth,
        readingInset: Theme.islandPillNoteInset,
        readingTop: Theme.islandPillNoteTop,
        readingWidth: Theme.islandPillNoteWidth,
        readingSize: Theme.islandPillNoteSize,
        readingWeight: Font.Normal
      });
    case "glyphLabelDetailDots":
      return Object.assign(base, {
        labelWidth: Theme.islandPillLabelWidthDots,
        labelSize: Theme.islandPillCaptionSize,
        detailLeft: Theme.islandPillDotsDetailLeft,
        detailWidth: Theme.islandPillDotsDetailWidth,
        detailSize: Theme.islandPillCaptionSize,
        detailWeight: Theme.weightMedium
      });
    }
    return base;
  }

  readonly property var at: placement(layout)

  implicitWidth: wide ? Theme.islandPillWidthWide : Theme.islandPillWidth
  implicitHeight: Theme.islandPillHeight

  Item {
    id: glyphSlot

    x: Theme.islandPillGlyphLeft
    y: root.at.glyphTop
    width: root.at.glyphSize
    height: width
  }

  Text {
    x: root.layout === "glyphLabelAction" ? Math.round((root.width - width) / 2) : root.at.labelLeft
    y: Theme.islandPillTextTop
    width: root.at.labelWidth
    visible: root.hasLabel
    horizontalAlignment: root.at.labelAlign
    elide: root.labelElide
    text: root.label
    color: root.labelColor
    font.family: Theme.uiFont
    font.pixelSize: root.at.labelSize
    font.weight: root.at.labelWeight
  }

  Text {
    x: root.at.detailLeft
    y: Theme.islandPillTextTop
    width: root.at.detailWidth
    visible: root.hasDetail
    elide: Text.ElideRight
    text: root.detail
    color: root.detailColor
    font.family: Theme.uiFont
    font.pixelSize: root.at.detailSize
    font.weight: root.at.detailWeight
  }

  LevelTrack {
    x: root.at.trackLeft
    y: Theme.islandPillTrackTop
    width: root.at.trackWidth
    visible: root.hasTrack
    value: root.value
    indeterminate: root.indeterminate
    showFill: root.showFill
    fillDuration: root.fillDuration
    running: root.running
  }

  Item {
    id: waveformSlot

    x: Math.round((root.width - width) / 2)
    y: Theme.islandPillWaveformTop
    width: Theme.islandPillWaveformWidth
    height: Theme.islandPillWaveformHeight
    visible: root.hasWaveform
  }

  Text {
    x: root.width - root.at.readingInset - width
    y: root.at.readingTop
    width: root.at.readingWidth
    visible: root.hasReading
    horizontalAlignment: Text.AlignRight
    text: root.reading
    color: root.readingColor
    font.family: Theme.uiFont
    font.pixelSize: root.at.readingSize
    font.weight: root.at.readingWeight
    font.features: root.tabularReading ? {
      "tnum": 1
    } : {}
  }

  StrokeIconButton {
    x: root.width - Theme.islandPillActionInset - width
    y: Theme.islandPillActionTop
    size: Theme.islandPillActionSize
    strokeWidth: 1.6
    visible: root.hasAction
    path: IconPaths.x
    accessibleName: "Cancel"
    baseColor: Theme.inkSecondary
    onClicked: root.cancelled()
  }

  // Three dots passing a beat along, brightest first.
  Row {
    id: dots

    x: root.width - Theme.islandPillDotsInset - width
    y: Theme.islandPillDotsTop
    spacing: Theme.islandPillDotGap
    visible: root.hasDots

    property real beat: 0

    NumberAnimation on beat {
      from: 0
      to: 3
      duration: Theme.sharingPulse
      loops: Animation.Infinite
      running: dots.visible && root.running && !Theme.reduceMotion
    }

    Repeater {
      model: 3

      Rectangle {
        required property int index

        width: Theme.islandPillDotSize
        height: width
        radius: width / 2
        // Distance behind the beat, wrapped: 0 is lit, then 0.55, then 0.25.
        readonly property real lag: ((dots.beat - index) % 3 + 3) % 3
        color: Theme.withAlpha(Theme.accentFill, lag < 1 ? 1 - 0.45 * lag : lag < 2 ? 0.55 - 0.3 * (lag - 1) : 0.25 + 0.75 * (lag - 2))
      }
    }
  }

  // The attention: the row's own outline, in love, as the login pill's refusal is.
  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: "transparent"
    border.width: Theme.islandPillAlertWidth
    border.color: Theme.withAlpha(Theme.love, Theme.lockErrorOutline)
    opacity: root.alert ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
      Morph {
        duration: Theme.duration(Theme.lockStateFade)
      }
    }
  }
}
