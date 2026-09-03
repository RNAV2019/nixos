import QtQuick
import qs.Commons
import qs.Services

IconWidget {
  id: root

  // The 5h window is the one that actually bites, so it carries the label.
  readonly property int percent: Math.round(ClaudeUsage.fiveHour)

  // An expired token has no number worth trusting; anything else keeps the
  // last reading on the bar, dimmed to subtle once it stops being current.
  readonly property bool blank: ClaudeUsage.expired || !ClaudeUsage.available

  glyph: Icons.claude
  label: blank ? "—" : percent + "%"
  gap: Theme.spacingSm

  glyphColor: {
    if (root.blank)
      return Theme.muted;
    if (ClaudeUsage.stale)
      return Theme.subtle;
    return ClaudeUsage.severity(percent);
  }

  onActivated: ClaudeUsage.refresh()

  // The icon already says this is Claude, so the window names carry the line:
  // "5h 6% → 01:00" is the window, its usage, and when it resets.
  readonly property string tooltip: {
    if (ClaudeUsage.expired)
      return "Token expired — start Claude Code";
    if (!ClaudeUsage.available)
      return "Usage unavailable";
    var t = "5h " + percent + "% → " + Qt.formatDateTime(ClaudeUsage.fiveHourResets, "HH:mm") + "   7d " + Math.round(ClaudeUsage.sevenDay) + "% → " + Qt.formatDateTime(ClaudeUsage.sevenDayResets, "ddd HH:mm");
    if (ClaudeUsage.stale)
      t += "   stale " + Qt.formatDateTime(ClaudeUsage.updated, "HH:mm");
    return t;
  }
}
