import QtQuick

// A column of rows kept scrolled so the current one stays in view; it takes its row pitch from
// `spacing`, and only becomes a flickable once its rows overflow it.
ListView {
  clip: true
  boundsBehavior: Flickable.StopAtBounds
  highlightFollowsCurrentItem: false
  interactive: contentHeight > height
}
