import QtQuick
import qs.Commons
import "Markdown.js" as Markdown

// One turn of the launcher's chat. The user's is a line or two in primary ink beside an
// accent marker; Claude's is Markdown, its fenced code lifted out into mono blocks (Qt's
// Markdown sets code in the system monospace, flush with the prose, which reads as noise).
Item {
  id: root

  property real gutterX: 0
  property real textX: 0
  property real textWidth: 0
  property bool user: false
  property string body: ""
  // "" or ClaudeChat's kind: "missing", "auth", "limit", "failed", "stopped".
  property string errorKind: ""
  property string errorDetail: ""
  property bool waiting: false

  implicitHeight: content.height
  height: implicitHeight

  // Prose and fenced code in order; an unclosed fence, mid-stream, is code already.
  readonly property var segments: root.split(root.body)

  function split(body) {
    var out = [];
    var lines = body.split("\n");
    var code = false;
    var buf = [];
    for (var i = 0; i <= lines.length; i++) {
      var fence = i < lines.length && /^\s*```/.test(lines[i]);
      if (i < lines.length && !fence) {
        buf.push(lines[i]);
        continue;
      }
      var t = buf.join("\n");
      if (code ? buf.length > 0 : t.trim().length > 0)
        out.push({
          code: code,
          text: code ? t : t.trim()
        });
      buf = [];
      code = !code;
    }
    return out;
  }

  // Colours go to the rich text as CSS; an alpha one as rgba(), which Qt reads.
  function css(c) {
    return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + c.a.toFixed(3) + ")";
  }

  readonly property var markdownStyle: ({
      mono: Theme.monoFont,
      codeSize: Theme.launcherChatCodeSize,
      codeColor: css(Theme.inkPrimary),
      codeFill: css(Theme.launcherChatCodeFill),
      link: css(Theme.accent),
      quote: css(Theme.inkSecondary),
      block: "margin-top:0px; margin-bottom:" + Theme.launcherChatParaGap + "px;",
      item: "margin-top:0px; margin-bottom:" + Theme.launcherChatItemGap + "px;",
      indent: Theme.launcherChatIndent
    })

  readonly property var detailStyle: Object.assign({}, root.markdownStyle, {
    codeSize: Theme.launcherDescSize,
    block: "margin:0px;"
  })

  readonly property var errorText: ({
      missing: ["Claude Code isn’t installed", "No `claude` on the shell’s PATH."],
      auth: ["Not signed in", "Run `claude` in a terminal and sign in with /login."],
      limit: ["Usage limit reached", ""],
      failed: ["Claude couldn’t answer", ""],
      stopped: ["Stopped", ""]
    })

  // The gutter mark, centred on the first line.
  Rectangle {
    x: root.gutterX + (Theme.launcherIconSize - width) / 2
    y: (firstLine.height - height) / 2
    width: Theme.launcherMarkerWidth
    height: Theme.launcherChatUserSize + 2
    radius: width / 2
    color: Theme.accent
    visible: root.user
  }

  Text {
    x: root.gutterX + (Theme.launcherIconSize - width) / 2
    y: (firstLine.height - height) / 2
    text: Icons.assistant
    color: root.errorKind && root.errorKind !== "stopped" ? Theme.urgent : Theme.inkTertiary
    visible: !root.user
    font.family: Theme.iconFont
    font.pixelSize: Theme.launcherChatGutterGlyphSize
  }

  // A line's height in body type, which the gutter marks centre on.
  Text {
    id: firstLine

    visible: false
    text: "X"
    font.family: Theme.uiFont
    font.pixelSize: root.user ? Theme.launcherChatUserSize : Theme.launcherChatBodySize
    lineHeight: Theme.launcherChatLeading
  }

  Column {
    id: content

    x: root.textX
    width: root.textWidth
    spacing: Theme.launcherChatCodePad

    Text {
      width: parent.width
      visible: root.user
      text: root.body
      color: Theme.inkPrimary
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
      lineHeight: Theme.launcherChatLeading
      font.family: Theme.uiFont
      font.pixelSize: Theme.launcherChatUserSize
      font.weight: Theme.weightSemi
    }

    Repeater {
      model: root.user ? [] : root.segments

      delegate: Item {
        id: seg

        required property var modelData

        width: content.width
        height: seg.modelData.code ? codeText.height + Theme.launcherChatCodePad * 2 : prose.height

        Text {
          id: prose

          width: parent.width
          visible: !seg.modelData.code
          text: seg.modelData.code ? "" : Markdown.toHtml(seg.modelData.text, root.markdownStyle)
          textFormat: Text.RichText
          color: Theme.inkPrimary
          linkColor: Theme.accent
          wrapMode: Text.Wrap
          lineHeight: Theme.launcherChatLeading
          font.family: Theme.uiFont
          font.pixelSize: Theme.launcherChatBodySize
        }

        Rectangle {
          anchors.fill: parent
          visible: seg.modelData.code
          radius: Theme.launcherChatCodeRadius
          color: Theme.launcherChatCodeFill

          Text {
            id: codeText

            x: Theme.launcherChatCodePad
            y: Theme.launcherChatCodePad
            width: parent.width - Theme.launcherChatCodePad * 2
            text: seg.modelData.code ? seg.modelData.text : ""
            textFormat: Text.PlainText
            // No horizontal scroll without a pointer, so long lines wrap.
            wrapMode: Text.WrapAnywhere
            color: Theme.inkPrimary
            font.family: Theme.monoFont
            font.pixelSize: Theme.launcherChatCodeSize
          }
        }
      }
    }

    // Waiting on the first words: three dots breathing in turn.
    Row {
      height: firstLine.height
      spacing: Theme.launcherChatDotGap
      visible: root.waiting

      Repeater {
        model: 3

        delegate: Rectangle {
          required property int index

          anchors.verticalCenter: parent.verticalCenter
          width: Theme.launcherChatDotSize
          height: width
          radius: width / 2
          color: Theme.inkTertiary
          opacity: 0.3

          SequentialAnimation on opacity {
            running: root.waiting
            loops: Animation.Infinite

            PauseAnimation {
              duration: index * Theme.morphAmbient / 3
            }
            NumberAnimation {
              to: 1
              duration: Theme.morphAmbient / 2
              easing.type: Easing.InOutSine
            }
            NumberAnimation {
              to: 0.3
              duration: Theme.morphAmbient / 2
              easing.type: Easing.InOutSine
            }
            PauseAnimation {
              duration: (2 - index) * Theme.morphAmbient / 3
            }
          }
        }
      }
    }

    Column {
      width: parent.width
      visible: root.errorKind !== ""
      spacing: 2

      Text {
        text: root.errorText[root.errorKind] ? root.errorText[root.errorKind][0] : ""
        color: root.errorKind === "stopped" ? Theme.inkTertiary : Theme.urgent
        font.family: Theme.uiFont
        font.pixelSize: root.errorKind === "stopped" ? Theme.launcherChatMetaSize : Theme.launcherChatBodySize
        font.weight: Theme.weightSemi
      }

      Text {
        // The CLI's own words when it gave any, else ours. Signed out, its "Please run
        // /login" means nothing outside a terminal, so ours stand.
        readonly property string fixed: root.errorText[root.errorKind] ? root.errorText[root.errorKind][1] : ""
        readonly property string said: root.errorDetail && root.errorKind !== "auth" ? root.errorDetail : fixed

        width: parent.width
        text: Markdown.toHtml(said, root.detailStyle)
        visible: said.length > 0
        color: Theme.inkTertiary
        wrapMode: Text.Wrap
        textFormat: Text.RichText
        font.family: Theme.uiFont
        font.pixelSize: Theme.launcherDescSize
      }
    }
  }
}
