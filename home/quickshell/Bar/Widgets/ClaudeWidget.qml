import QtQuick
import qs.Commons
import qs.Services

IconWidget {
  id: root

  // The 5h window is the one that actually bites, so it carries the label.
  readonly property int percent: Math.round(ClaudeUsage.fiveHour)

  glyph: Icons.claude
  label: ClaudeUsage.available ? percent + "%" : "—"
  gap: Theme.spacingSm

  glyphColor: ClaudeUsage.available ? ClaudeUsage.severity(percent) : Theme.muted

  onActivated: ClaudeUsage.refresh()

  readonly property string tooltip: {
    if (!ClaudeUsage.available)
      return "Claude usage unavailable";
    return "5h " + percent + "% · resets " + Qt.formatDateTime(ClaudeUsage.fiveHourResets, "HH:mm") + "   7d " + Math.round(ClaudeUsage.sevenDay) + "% · resets " + Qt.formatDateTime(ClaudeUsage.sevenDayResets, "ddd HH:mm");
  }
}
