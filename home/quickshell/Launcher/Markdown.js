.pragma library

// The Markdown a chat reply uses, as Qt rich text: paragraphs, headings, lists, quotes,
// emphasis, links and inline code. Qt's own MarkdownText sets inline code in the system
// monospace at its own size, which towers over the prose; here code takes the theme's mono
// face at a given size. Fenced blocks never get here (Launcher/ChatTurn.qml lifts them out).
// `style` is { mono, codeSize, codeColor, codeFill, link, quote, block, item, indent }: colours
// as CSS; `block` and `item` the margins of a paragraph and a list item; `indent` an item's
// hanging indent in px.

function escape(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

function inline(s, style) {
  // Code spans first, parked, so nothing inside them is read as emphasis.
  var spans = [];
  s = s.replace(/`([^`]+)`/g, function (m, code) {
    spans.push("<span style=\"font-family:'" + style.mono + "'; font-size:" + style.codeSize + "px; color:" + style.codeColor + "; background-color:" + style.codeFill + ";\">&#8239;" + escape(code) + "&#8239;</span>");
    return "\u0000" + (spans.length - 1) + "\u0000";
  });
  s = escape(s);
  s = s.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, "<a href=\"$2\" style=\"color:" + style.link + "; text-decoration:none;\">$1</a>");
  s = s.replace(/\*\*([^*]+)\*\*|__([^_]+)__/g, function (m, a, b) {
    return "<b>" + (a || b) + "</b>";
  });
  s = s.replace(/(^|[^*\w])\*([^*\s][^*]*)\*(?!\*)|(^|\W)_([^_\s][^_]*)_(?!\w)/g, function (m, p1, a, p2, b) {
    return (p1 || p2 || "") + "<i>" + (a || b) + "</i>";
  });
  s = s.replace(/~~([^~]+)~~/g, "<s>$1</s>");
  return s.replace(/\u0000(\d+)\u0000/g, function (m, i) {
    return spans[Number(i)];
  });
}

function toHtml(text, style) {
  var lines = String(text).split("\n");
  var out = [];
  var para = [];
  var list = null;

  function flushPara() {
    if (para.length > 0)
      out.push("<p style=\"" + style.block + "\">" + para.join("<br>") + "</p>");
    para = [];
  }
  // The last item takes a paragraph's gap below it, the rest an item's.
  function flushList() {
    if (list && out.length > 0)
      out[out.length - 1] = out[out.length - 1].replace(style.item, style.block);
    list = null;
  }

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    var m;
    if (/^\s*$/.test(line)) {
      flushPara();
      flushList();
      continue;
    }
    if ((m = /^(#{1,6})\s+(.*)$/.exec(line))) {
      flushPara();
      flushList();
      out.push("<p style=\"" + style.block + "\"><b>" + inline(m[2], style) + "</b></p>");
      continue;
    }
    if (/^\s*([-*_])(\s*\1){2,}\s*$/.test(line)) {
      flushPara();
      flushList();
      continue;
    }
    // Items are paragraphs on a hanging indent: Qt's own lists indent a full 40 px.
    if ((m = /^(\s*)(?:([-*+])|(\d+)[.)])\s+(.*)$/.exec(line))) {
      flushPara();
      list = "item";
      var depth = Math.min(2, Math.floor(m[1].length / 2));
      var mark = m[2] ? "\u2022" : m[3] + ".";
      out.push("<p style=\"" + style.item + " margin-left:" + (style.indent * (depth + 1)) + "px; text-indent:-" + style.indent + "px;\">" + mark + "&#8197;" + inline(m[4], style) + "</p>");
      continue;
    }
    if ((m = /^\s*>\s?(.*)$/.exec(line))) {
      flushPara();
      flushList();
      out.push("<p style=\"" + style.block + " color:" + style.quote + ";\">" + inline(m[1], style) + "</p>");
      continue;
    }
    // A wrapped list item carries on in the item.
    if (list && /^\s+\S/.test(line) && out.length > 0) {
      out[out.length - 1] = out[out.length - 1].replace(/<\/p>$/, " " + inline(line.trim(), style) + "</p>");
      continue;
    }
    flushList();
    para.push(inline(line, style));
  }
  flushPara();
  flushList();
  return out.join("");
}
