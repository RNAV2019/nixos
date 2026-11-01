import QtQuick
import qs.Commons

// The shell's tile, from the design set's Tile: four kinds on ButtonBase's hover, press, keys and
// focus ring. Control is the control centre's pill with a badge, Choice the square one-of-three
// of the power menu, the profiles card and the recorder picker, Carousel a picture with a ring
// (the wallpaper and theme pickers), Device a disc with a progress ring (Nearby). Surfaces step
// highlightMed to the shell's hover alpha; filled grounds lift by `tileLift`. A Control tile in a
// narrow cell is `stacked`: the badge above the label and the line instead of beside them, on
// even padding.
ButtonBase {
  id: root

  enum Kind {
    Control,
    Choice,
    Carousel,
    Device
  }

  property int kind: Tile.Control

  property string label: ""
  property string sublabel: ""
  // A Material Symbols name or stroke path (StrokeIcon): the badge's, the choice's, the disc's.
  property string glyph: ""

  // The filled state: a toggle that is on, the choice that is chosen, the entry that is up.
  property bool active: false
  // Where the keyboard is, which is not the same thing as active.
  property bool current: false

  // Control: the badge toggles while the body opens a view, when there is one.
  property bool opensView: false
  property bool glyphDimmed: false
  // Stacked has no badge target of its own: the whole tile is one.
  property bool stacked: false
  // The grid the badge's glyph is drawn on before it is scaled to the control glyph size: the
  // radios share the Wi-Fi wedge's 24 px grid, so the pair matches.
  property real glyphGrid: Theme.controlTileGlyphSize
  // Choice: love where the machine's whole stance changes, accent where it is one pick of three.
  property color activeColor: kind === Tile.Choice ? Theme.accent : Theme.accentFill
  // An active tile must not wear the ring a current one wears (the armed power tile).
  property bool activeIsCommitting: false

  // Carousel: the picture's URL, what shows under it until it loads, and what the tile is.
  property string image: ""
  property color placeholderColor: Theme.overlay
  property string noun: "tile"
  // Set from the row's `glide`: position and size then spring to each new selection instead of
  // jumping, on the rail's own spring so the two never drift apart.
  property bool glide: false

  // Device: the transfer's state, its progress and the line under the name.
  property bool sending: false
  property bool sent: false
  property bool failed: false
  property bool indeterminate: false
  property real progress: 0
  signal cancelClicked

  signal toggled
  signal opened

  default property alias extras: extrasLayer.data

  readonly property bool isControl: kind === Tile.Control
  readonly property bool isChoice: kind === Tile.Choice
  readonly property bool isCarousel: kind === Tile.Carousel
  readonly property bool isDevice: kind === Tile.Device

  readonly property bool badgeHovered: badgeArea.containsMouse && root.enabled
  readonly property bool pressedAny: root.pressed || badgeArea.pressed
  readonly property bool lit: (root.hovered || root.badgeHovered || root.pressedAny) && root.interactive
  readonly property color ink: active ? Theme.inkOnAccent : Theme.inkPrimary
  // A reading that carries a state (a low battery) tints its own glyph.
  property color glyphColor: {
    var base = active ? Theme.inkOnAccent : Theme.inkSecondary;
    return glyphDimmed ? Theme.withAlpha(base, Theme.controlGlyphDimAlpha) : base;
  }
  // A tile whose line is a reading rather than a hint lifts it from tertiary ink.
  property color sublabelColor: active ? Theme.withAlpha(Theme.inkOnAccent, 0.72) : Theme.inkTertiary
  // A tint for the outline at rest, for a tile that wants to say why it is in trouble (Browse,
  // while the phone refuses it). Transparent leaves the hairline.
  property color outlineTint: "transparent"
  readonly property bool hasSub: sublabel !== ""
  readonly property real cornerRadius: {
    switch (kind) {
    case Tile.Control:
      return stacked ? Theme.controlTileStackedRadius : Theme.controlTileRadius;
    case Tile.Choice:
      return Theme.powerTileRadius;
    case Tile.Carousel:
      // Not scaled with the tile: a radius that grew would read as the corners breathing.
      return Theme.wallpaperTileRadius;
    }
    return 0;
  }

  readonly property color groundColor: {
    if (isControl) {
      if (active)
        return lit ? Qt.lighter(activeColor, Theme.tileLift) : activeColor;
      return Theme.withAlpha(lit ? Theme.highlightMed : Theme.surfaceSubtle, lit ? Theme.groundHoverAlpha : Theme.surfaceRestAlpha);
    }
    if (active)
      return pressedAny ? Qt.darker(activeColor, Theme.tileDim) : activeColor;
    return Theme.withAlpha(lit ? Theme.highlightMed : Theme.highlightLow, lit ? Theme.groundHoverAlpha : Theme.surfaceRestAlpha);
  }

  readonly property color outlineColor: {
    if (isControl)
      return current ? Theme.focusRing : outlineTint.a > 0 ? outlineTint : Theme.withAlpha(Theme.separator, Theme.hairlineAlpha);
    if (isChoice) {
      if (active && activeIsCommitting)
        return activeColor;
      if (current || lit)
        return Theme.accent;
      if (active)
        return activeColor;
      return Theme.withAlpha(Theme.highlightMed, Theme.hairlineAlpha);
    }
    return current ? Theme.accent : active ? Theme.withAlpha(Theme.accent, Theme.wallpaperActiveBorderAlpha) : Theme.withAlpha(Theme.highlightMed, Theme.wallpaperTileBorderAlpha);
  }

  implicitWidth: {
    if (isChoice)
      return Theme.powerTileWidth;
    if (isDevice)
      return Theme.nearbyDeviceSlot;
    return 0;
  }
  implicitHeight: {
    if (isControl)
      return stacked ? Theme.controlTileStackedHeight : Theme.controlTileHeight;
    if (isChoice)
      return Theme.powerTileHeight;
    if (isDevice)
      return Theme.nearbyDeviceSize + Theme.nearbyDeviceNameGap + Theme.nearbyDeviceNameLine + (hasSub ? Theme.nearbyDeviceSubGap + Theme.nearbyDeviceSubHeight : 0);
    return 0;
  }

  ringRadius: cornerRadius
  accessibleRole: isChoice ? Accessible.RadioButton : isControl && !opensView ? Accessible.CheckBox : Accessible.Button
  checkable: accessibleRole !== Accessible.Button
  checked: active
  scale: pressedAny ? Theme.pressScale : 1
  Accessible.name: accessibleName !== "" ? accessibleName : label
  Accessible.focused: isChoice ? current : activeFocus
  Accessible.description: {
    if (isControl)
      return sublabel;
    if (isCarousel)
      return current ? "Selected " + noun : active ? "Current " + noun : noun + " preview";
    return "";
  }
  Accessible.onToggleAction: if (isControl && !opensView)
    root.toggled()

  onClicked: {
    if (!isControl)
      return;
    if (opensView)
      root.opened();
    else
      root.toggled();
  }

  Behavior on x {
    enabled: root.glide

    SurfaceSpring {}
  }

  Behavior on y {
    enabled: root.glide

    SurfaceSpring {}
  }

  Behavior on width {
    enabled: root.glide

    SurfaceSpring {}
  }

  Behavior on height {
    enabled: root.glide

    SurfaceSpring {}
  }

  // ---- Control and Choice: a ground, an outline, the glyph and the words ----

  Rectangle {
    anchors.fill: parent
    visible: root.isControl || root.isChoice
    radius: root.cornerRadius
    color: root.groundColor
    border.width: root.isControl && root.active ? 0 : 1
    border.color: root.outlineColor

    Behavior on color {
      Tint {}
    }

    Behavior on border.color {
      Tint {}
    }
  }

  Rectangle {
    id: badge

    x: root.stacked ? Theme.controlTileStackedPad : Theme.controlTileBadgeLeft
    y: root.stacked ? Theme.controlTileStackedPad : (parent.height - height) / 2
    visible: root.isControl
    width: root.stacked ? Theme.controlTileStackedBadge : Theme.controlTileBadge
    height: width
    radius: height / 2
    color: root.active ? Theme.withAlpha(Theme.inkOnAccent, root.badgeHovered ? 0.28 : root.stacked ? 0.22 : 0.16) : Theme.withAlpha(Theme.inkPrimary, root.badgeHovered ? 0.14 : 0.07)

    Behavior on color {
      Tint {}
    }

    StrokeIcon {
      anchors.centerIn: parent
      visible: root.glyph !== ""
      size: root.glyphGrid
      scale: Theme.controlTileGlyphSize / root.glyphGrid
      strokeWidth: 1.75
      path: root.glyph
      color: root.glyphColor
      inkCentred: root.glyphGrid === Theme.controlTileGlyphSize
    }
  }

  Text {
    id: name

    x: root.stacked ? Theme.controlTileStackedPad : Theme.controlTileTextLeft
    y: root.stacked ? Theme.controlTileStackedLabelTop : 12
    width: Math.max(0, root.width - x - (root.stacked ? Theme.controlTileStackedTextSlack : 10))
    visible: root.isControl
    text: root.label
    color: root.ink
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlTileLabelSize
    font.weight: Theme.weightSemi
    elide: Text.ElideRight
  }

  Text {
    x: name.x
    y: root.stacked ? Theme.controlTileStackedSubTop : 30
    width: name.width
    visible: root.isControl
    text: root.sublabel
    color: root.sublabelColor
    font.family: Theme.uiFont
    font.pixelSize: Theme.controlTileSubSize
    elide: Text.ElideRight
  }

  StrokeIcon {
    anchors.horizontalCenter: parent.horizontalCenter
    y: Theme.powerGlyphTop - Theme.powerTileTop
    visible: root.isChoice
    size: Theme.powerGlyphSize
    fineY: true
    path: root.glyph
    color: root.ink

    Behavior on color {
      Tint {}
    }
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    y: Theme.powerLabelTop - Theme.powerTileTop
    visible: root.isChoice
    text: root.label
    color: root.ink
    font.family: Theme.uiFont
    font.pixelSize: Theme.powerLabelSize
    font.weight: root.active ? Font.Bold : Font.Medium

    Behavior on color {
      Tint {}
    }
  }

  // The badge's target includes its gutter, so the split falls where the text begins.
  MouseArea {
    id: badgeArea

    width: Theme.controlTileTextLeft
    height: parent.height
    enabled: root.isControl && root.interactive && !root.stacked
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onPressed: {
      root.pointerFocused = true;
      root.forceActiveFocus();
    }
    onClicked: root.toggled()
  }

  // ---- Carousel: the picture, its ring and the dot that says it is the one up ----

  RoundedClip {
    anchors.fill: parent
    visible: root.isCarousel
    radius: root.cornerRadius

    Rectangle {
      anchors.fill: parent
      color: root.placeholderColor
    }

    Image {
      anchors.fill: parent
      source: root.isCarousel ? root.image : ""
      fillMode: Image.PreserveAspectCrop
      // Decoded at about twice the tile, so it grows into its selected size unsoftened.
      sourceSize.width: Theme.wallpaperTileWidths[0] * 2
      asynchronous: true
      cache: true
      visible: status === Image.Ready
    }
  }

  // Drawn over the picture rather than around the tile, so the row keeps its pitch. Three
  // weights: full ring (current), accent hairline (up), muted hairline (rest).
  Rectangle {
    anchors.fill: parent
    visible: root.isCarousel
    radius: root.cornerRadius
    color: "transparent"
    border.width: root.current ? Theme.wallpaperSelectedBorder : 1
    border.color: root.outlineColor

    Behavior on border.color {
      Tint {}
    }

    Behavior on border.width {
      enabled: root.glide

      NumberAnimation {
        duration: Theme.duration(Theme.morphState)
        easing.type: Easing.OutQuad
      }
    }
  }

  Item {
    x: parent.width - width - Theme.wallpaperDotInset
    y: Theme.wallpaperDotInset
    width: Theme.wallpaperDotHalo
    height: width
    visible: root.isCarousel && root.active

    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: Theme.withAlpha(Theme.canvas, Theme.wallpaperDotHaloAlpha)
    }

    Rectangle {
      anchors.centerIn: parent
      width: Theme.wallpaperDotSize
      height: width
      radius: width / 2
      color: Theme.accent
    }
  }

  // ---- Device: a disc with the device's glyph, a ring that fills while it sends ----

  Item {
    id: disc

    x: (root.width - Theme.nearbyDeviceSize) / 2
    y: 0
    visible: root.isDevice
    width: Theme.nearbyDeviceSize
    height: Theme.nearbyDeviceSize

    // Sized one notch over the disc so the pair reads as one object.
    Ring {
      anchors.centerIn: parent
      visible: root.sending && !root.sent
      size: Theme.nearbyRingSize
      stroke: Theme.nearbyRingWidth
      trackColor: Theme.withAlpha(Theme.separator, 0.9)
      value: root.progress
      animated: true
      // Events arrive at most every 250 ms, so the arc eases for that long.
      duration: 250
    }

    // The quarter arc that turns where the total is not known, over the ring's own track.
    Spinner {
      anchors.centerIn: parent
      visible: root.indeterminate
      size: Theme.nearbyRingSize
      stroke: Theme.nearbyRingWidth
      track: false
    }

    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: root.sent ? Theme.accentFill : root.sending ? Theme.withAlpha(Theme.accentFill, 0.14) : Theme.withAlpha(root.lit ? Theme.highlightMed : Theme.surfaceSubtle, root.lit ? Theme.groundHoverAlpha : Theme.hairlineGroundAlpha)
      border.width: root.sent ? 0 : 1
      border.color: Theme.withAlpha(Theme.separator, Theme.rowBorderAlpha)

      Behavior on color {
        Tint {}
      }
    }

    // Done: the glyph is replaced by a check that draws in.
    StrokeIcon {
      anchors.centerIn: parent
      visible: root.sent
      size: Theme.nearbyCheckSize
      strokeWidth: 2.2
      path: IconPaths.check
      color: Theme.inkOnAccent
      opacity: root.sent ? 1 : 0
      scale: root.sent ? 1 : 0.6

      Behavior on opacity {
        Morph {
          duration: Theme.morphState
        }
      }

      Behavior on scale {
        Morph {
          duration: Theme.morphState
        }
      }
    }

    StrokeIcon {
      anchors.centerIn: parent
      visible: !root.sent
      size: Theme.nearbyDeviceGlyph
      strokeWidth: 1.75
      path: root.glyph
      color: Theme.accentFill
    }
  }

  Text {
    y: Theme.nearbyDeviceSize + Theme.nearbyDeviceNameGap
    width: root.width
    visible: root.isDevice
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
    text: root.label
    color: Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: Theme.nearbyDeviceNameSize
    font.weight: root.sending || root.sent ? Theme.weightSemi : Theme.weightRegular
  }

  Text {
    y: Theme.nearbyDeviceSize + Theme.nearbyDeviceNameGap + Theme.nearbyDeviceNameLine + Theme.nearbyDeviceSubGap
    width: root.width
    visible: root.isDevice && root.hasSub
    horizontalAlignment: Text.AlignHCenter
    text: root.sublabel
    color: root.failed ? Theme.dangerFill : Theme.accentFill
    font.family: Theme.uiFont
    font.pixelSize: Theme.nearbyDeviceSubSize
    font.weight: Theme.weightMedium

    Behavior on color {
      Tint {}
    }
  }

  // The × badge sits on the disc's top-right corner, punched out by a surface-coloured ring.
  ButtonBase {
    x: disc.x + Theme.nearbyDeviceSize - Theme.nearbyCancelSize + 6
    y: disc.y - 4
    visible: root.isDevice && root.sending
    width: Theme.nearbyCancelSize
    height: Theme.nearbyCancelSize
    hitSlop: 4
    activeFocusOnTab: false
    accessibleName: "Cancel send to " + root.label
    onClicked: root.cancelClicked()

    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: Theme.surfaceRaised
      border.width: Theme.nearbyCancelStroke
      border.color: Theme.surface
    }

    StrokeIcon {
      anchors.centerIn: parent
      size: Theme.nearbyCancelGlyph
      strokeWidth: 2
      path: IconPaths.x
      color: Theme.inkPrimary
    }
  }

  // Whatever a tile type adds (the theme's swatch pill, say) lands above everything here.
  Item {
    id: extrasLayer

    anchors.fill: parent
  }
}
