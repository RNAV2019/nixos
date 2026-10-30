import QtQuick
import qs.Commons
import qs.Services
import qs.Ui

// The hover card of the Claude satellite (Penpot "Ariadne / Activity card / Claude"): the one
// session that waits, as a permission to answer or a turn that finished, or a row for each
// when several do. Open raises that session's terminal; Dismiss forgets it until it asks again.
Item {
  id: root

  readonly property var sessions: ClaudeSessions.list
  readonly property bool several: sessions.length > 1
  readonly property var one: sessions.length > 0 ? sessions[0] : null
  readonly property bool finished: one !== null && one.state === "finished"
  readonly property int shownRows: Math.min(sessions.length, 3)

  // Kept as the card last had it, so the close animation does not collapse to nothing.
  property real settled: 190
  readonly property real wanted: several ? 64 + shownRows * 52 - 4 + Theme.activityCardPad + (sessions.length > 3 ? 24 : 0) : finished ? 176 : 190
  onWantedChanged: if (sessions.length > 0)
    settled = wanted

  implicitWidth: Theme.activityCardWidth
  implicitHeight: settled

  // Re-read once a minute so "2 min ago" moves.
  property real now: Date.now()

  Timer {
    interval: 15000
    repeat: true
    running: true
    onTriggered: root.now = Date.now()
  }

  function age(since) {
    var minutes = Math.floor((root.now - since) / 60000);
    if (minutes < 1)
      return "just now";
    if (minutes < 60)
      return minutes + " min ago";
    return Math.floor(minutes / 60) + " h ago";
  }

  function act(session, run) {
    run(session.id);
    Activities.closeCard();
  }

  CardHeader {
    icon: IconPaths.claude
    tint: Theme.accent
    title: root.several ? root.sessions.length + " sessions waiting" : root.one ? root.one.project : ""
    caption: root.several ? "Claude Code" : root.one ? "Claude Code · " + root.age(root.one.since) : ""
  }

  // ---- one session ----

  Text {
    visible: !root.several && root.one !== null && !root.finished
    x: Theme.activityCardPad
    y: 74 - height / 2
    text: root.one && root.one.state === "question" ? "Question" : "Permission requested"
    color: Theme.inkTertiary
    font.family: Theme.uiFont
    font.pixelSize: Theme.sectionSize
    font.weight: Theme.weightMedium
  }

  Rectangle {
    visible: !root.several && root.one !== null && !root.finished
    x: Theme.activityCardPad
    y: 88
    width: root.width - 2 * Theme.activityCardPad
    height: 44
    radius: Theme.activityWellRadius
    color: Theme.surfaceSubtle

    Text {
      x: 12
      y: (parent.height - height) / 2
      width: parent.width - 24
      elide: Text.ElideRight
      text: root.one ? root.one.detail : ""
      color: Theme.inkPrimary
      font.family: root.one && root.one.state === "permission" ? Theme.monoFont : Theme.uiFont
      font.pixelSize: Theme.activityDetailSize
    }
  }

  Text {
    visible: !root.several && root.finished
    x: Theme.activityCardPad
    y: 76 - height / 2
    text: "Finished — waiting for input"
    color: Theme.inkPrimary
    font.family: Theme.uiFont
    font.pixelSize: Theme.activityRowTitleSize
    font.weight: Theme.weightSemi
  }

  Text {
    visible: !root.several && root.finished
    x: Theme.activityCardPad
    y: 90
    width: root.width - 2 * Theme.activityCardPad
    height: 36
    wrapMode: Text.Wrap
    maximumLineCount: 2
    lineHeight: 18
    lineHeightMode: Text.FixedHeight
    elide: Text.ElideRight
    text: root.one ? root.one.detail : ""
    color: Theme.inkSecondary
    font.family: Theme.uiFont
    font.pixelSize: Theme.activityRowTitleSize
  }

  Row {
    visible: !root.several && root.one !== null
    x: root.width - Theme.activityCardPad - width
    y: root.finished ? 130 : 144
    spacing: Theme.activityButtonGap

    ActivityButton {
      kind: "secondary"
      width: 86
      text: "Dismiss"
      onClicked: root.act(root.one, ClaudeSessions.dismiss)
    }

    ActivityButton {
      kind: "primary"
      width: 84
      icon: IconPaths.terminal
      text: "Open"
      onClicked: root.act(root.one, ClaudeSessions.open)
    }
  }

  // ---- several ----

  Repeater {
    model: root.several ? root.shownRows : 0

    Rectangle {
      id: row

      required property int index
      readonly property var session: root.sessions[index] !== undefined ? root.sessions[index] : null

      x: 8
      y: 64 + index * 52
      width: root.width - 16
      height: 48
      radius: Theme.activityWellRadius
      color: area.containsMouse ? Theme.surfaceRaised : Theme.surfaceSubtle

      Rectangle {
        x: 20
        y: 16 - height / 2
        width: Theme.activityDotSize
        height: width
        radius: width / 2
        color: row.session && row.session.state === "finished" ? Theme.foam : Theme.accent
      }

      Text {
        x: 38
        y: 16 - height / 2
        width: ageText.x - x - 8
        elide: Text.ElideRight
        text: row.session ? row.session.project : ""
        color: Theme.inkPrimary
        font.family: Theme.uiFont
        font.pixelSize: Theme.activityRowTitleSize
        font.weight: Theme.weightSemi
      }

      Text {
        x: 38
        y: 33 - height / 2
        width: parent.width - x - 16
        elide: Text.ElideRight
        text: row.session ? (row.session.state === "finished" ? "Finished — waiting for input" : row.session.detail) : ""
        color: Theme.inkSecondary
        font.family: Theme.uiFont
        font.pixelSize: 11
      }

      Text {
        id: ageText

        x: parent.width - 16 - width
        y: 16 - height / 2
        text: row.session ? root.age(row.session.since) : ""
        color: Theme.inkTertiary
        font.family: Theme.uiFont
        font.pixelSize: Theme.momentSubtitleSize
      }

      MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (row.session)
          root.act(row.session, ClaudeSessions.open)
      }
    }
  }

  Text {
    visible: root.several && root.sessions.length > 3
    x: Theme.activityCardPad
    y: 64 + 3 * 52 + 4
    text: "+" + (root.sessions.length - 3) + " more"
    color: Theme.inkTertiary
    font.family: Theme.uiFont
    font.pixelSize: Theme.sectionSize
  }
}
