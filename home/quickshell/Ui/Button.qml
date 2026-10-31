import QtQuick
import qs.Commons

// The shell's button, from the design set's Button: a bare icon, a disc, or a pill, in the
// three sizes. Kind decides the ground and the ink, Size the measurements. Grounded neutral
// kinds step highlightMed from a rest alpha to a hover one; filled pills lift their fill by
// 6%; the ungrounded ones wash. Pressed adds the shell's press scale.
ButtonBase {
  id: root

  enum Kind {
    // A bare glyph that steps from subtle to text, with an invisible margin around it.
    Icon,
    Disc,
    DiscDanger,
    Neutral,
    Primary,
    Danger,
    Ghost,
    // The accent word on a wash: Connect, Pair, Join, Cancel.
    Plain,
    // For rows that are themselves accent-filled.
    OnAccent,
    Tonal,
    // For cards that are themselves accent-filled.
    Inverse
  }

  enum Size {
    Compact,
    Regular,
    Large
  }

  property int kind: Button.Neutral
  property int size: Button.Regular

  // A pill's label.
  property string text: ""
  // A Material Symbols name or stroke path (StrokeIcon), drawn before a pill's label or alone
  // in a disc or Icon.
  property string icon: ""
  property real iconSize: defaultIconSize
  property real iconStroke: 1.75
  property bool iconFilled: false
  // The label's and the icon's ink, when the kind's own is not the one wanted (a muted ghost).
  property color ink: kindInk
  // Replaces the icon's ink alone, for a glyph that shows a state of its own.
  property color iconColor: ink

  // The Icon kind's ink.
  property color baseColor: Theme.subtle
  property color hoverColor: Theme.text
  // Plain's danger tone: love ink and wash.
  property bool destructive: false
  // Fixed-width digits, for a label that counts.
  property bool tabular: false

  // A glyph of the caller's own (a drawn transport mark), centred in a disc or Icon. Take its
  // colour from `ink`.
  default property alias content: slot.data

  readonly property bool isIcon: kind === Button.Icon
  readonly property bool isDisc: kind === Button.Disc || kind === Button.DiscDanger
  readonly property bool isPill: !isIcon && !isDisc
  readonly property bool lit: root.hovered || root.pressed

  readonly property real defaultIconSize: {
    if (isIcon)
      return Theme.headerIconSize;
    if (isDisc)
      return size === Button.Large ? Theme.discGlyphLarge : Theme.discGlyph;
    return size === Button.Large ? Theme.pillIconLarge : Theme.pillIconSize;
  }
  readonly property real pad: [Theme.pillPadCompact, Theme.pillPadRegular, Theme.pillPadLarge][size]
  readonly property real gap: size === Button.Large ? Theme.pillIconGapLarge : Theme.pillIconGap
  readonly property real labelSize: [Theme.pillLabelCompact, Theme.pillLabelRegular, Theme.pillLabelLarge][size]
  readonly property bool medium: kind === Button.Neutral || kind === Button.Plain || kind === Button.OnAccent

  readonly property color fill: {
    switch (kind) {
    case Button.Disc:
    case Button.Neutral:
      return Theme.withAlpha(Theme.highlightMed, lit ? Theme.groundHoverAlpha : Theme.groundRestAlpha);
    case Button.DiscDanger:
      return Theme.withAlpha(Theme.urgent, lit ? Theme.groundHoverAlpha : Theme.dangerRestAlpha);
    case Button.Primary:
      return Qt.lighter(Theme.accentFill, lit ? Theme.fillLift : 1);
    case Button.Danger:
      return Qt.lighter(Theme.dangerFill, lit ? Theme.fillLift : 1);
    case Button.Inverse:
      return Qt.lighter(Theme.inkOnAccent, lit ? Theme.fillLift : 1);
    case Button.Ghost:
      return Theme.withAlpha(Theme.inkPrimary, lit ? Theme.washAlpha : 0);
    case Button.Plain:
      return Theme.withAlpha(destructive ? Theme.dangerFill : Theme.accentFill, lit ? Theme.plainHoverAlpha : 0);
    case Button.OnAccent:
      return Theme.withAlpha(Theme.inkOnAccent, lit ? Theme.onAccentHoverAlpha : Theme.onAccentRestAlpha);
    case Button.Tonal:
      return Theme.withAlpha(Theme.accentFill, lit ? Theme.tonalHoverAlpha : Theme.tonalRestAlpha);
    }
    return "transparent";
  }

  readonly property color kindInk: {
    switch (kind) {
    case Button.Icon:
      return lit ? hoverColor : baseColor;
    case Button.Primary:
      return Theme.inkOnAccent;
    case Button.DiscDanger:
    case Button.Danger:
      return Theme.inkOnDanger;
    case Button.Disc:
    case Button.Neutral:
    case Button.Ghost:
      return Theme.inkPrimary;
    case Button.Plain:
      return destructive ? Theme.dangerFill : Theme.accentFill;
    case Button.OnAccent:
      return Theme.inkOnAccent;
    case Button.Tonal:
    case Button.Inverse:
      return Theme.accentFill;
    }
    return Theme.inkPrimary;
  }

  implicitWidth: {
    if (isIcon)
      return iconSize;
    if (isDisc)
      return implicitHeight;
    return pillRow.implicitWidth + pad * 2;
  }
  implicitHeight: {
    if (isIcon)
      return iconSize;
    if (isDisc)
      return [Theme.discCompact, Theme.discRegular, Theme.discLarge][size];
    return [Theme.pillHeightCompact, Theme.pillHeightRegular, Theme.pillHeightLarge][size];
  }
  width: implicitWidth
  height: implicitHeight

  hitSlop: isIcon ? 8 : 0
  activeFocusOnTab: !isIcon
  ringRadius: isIcon ? 4 : height / 2
  ringInset: isIcon ? -2 : 0
  Accessible.name: root.accessibleName !== "" ? root.accessibleName : root.text

  Rectangle {
    anchors.fill: parent
    visible: !root.isIcon
    radius: height / 2
    color: root.fill
    border.width: root.kind === Button.Ghost ? 1 : 0
    border.color: Theme.withAlpha(Theme.highlightMed, Theme.hairlineAlpha)

    Behavior on color {
      Tint {}
    }
  }

  // A disc's or Icon's glyph, or the caller's own mark.
  Item {
    id: slot

    anchors.centerIn: parent
    visible: !root.isPill
    width: root.iconSize
    height: root.iconSize

    StrokeIcon {
      anchors.centerIn: parent
      visible: root.icon !== "" && !root.isPill
      size: root.iconSize
      strokeWidth: root.iconStroke
      path: root.icon
      filled: root.iconFilled
      color: root.iconColor

      Behavior on color {
        Tint {}
      }
    }
  }

  Row {
    id: pillRow

    anchors.centerIn: parent
    visible: root.isPill
    spacing: root.gap

    StrokeIcon {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.icon !== "" && root.isPill
      size: root.iconSize
      strokeWidth: root.iconStroke
      path: root.icon
      filled: root.iconFilled
      color: root.iconColor
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.text !== ""
      text: root.text
      color: root.ink
      font.family: Theme.uiFont
      font.pixelSize: root.labelSize
      font.weight: root.medium ? Theme.weightMedium : Theme.weightSemi
      font.features: root.tabular ? {
        "tnum": 1
      } : {}

      Behavior on color {
        Tint {}
      }
    }
  }
}
