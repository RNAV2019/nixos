// Helix's `gw` for web pages. Typing g then w outside a text field puts a two-letter label on
// every link, control and block of text in view; typing a label moves focus there. As in Helix,
// labels are handed out alternately after and before the cursor (here, the focused element),
// the first letter narrows them down, and any other key cancels. j and k scroll the page down
// and up, gliding like a held arrow key.
(() => {
  if (globalThis.__jumpLabels) {
    return;
  }
  globalThis.__jumpLabels = true;

  const ALPHABET = "abcdefghijklmnopqrstuvwxyz"; // Helix's default jump-label-alphabet
  const CHORD_TIMEOUT = 1000; // ms allowed between g and w
  const SCROLL_SETTLE = 120; // ms without scrolling before labels are measured
  const SETTLE_LIMIT = 600; // ms after which labels show even if something keeps scrolling
  const FLASH = 360; // ms the jumped-to element stays outlined
  const LOOSE_TEXT = 20; // characters loose text (not in a p, li…) needs to earn a label
  const SCROLL_STEP = 60; // px per j or k, and per key repeat while one is held, as in Vimium
  const SCROLL_EASE = 70; // ms time constant of the glide toward where j and k aim
  const XHTML = "http://www.w3.org/1999/xhtml";

  const CONTROL = [
    "a[href]", "area[href]", "button", "input:not([type=hidden])", "select", "textarea",
    "summary", "iframe", "audio[controls]", "video[controls]",
    "[contenteditable]:not([contenteditable=false])",
    ...["button", "link", "checkbox", "radio", "switch", "tab", "menuitem", "option",
      "treeitem", "combobox", "textbox", "searchbox", "slider"].map((r) => `[role=${r}]`),
  ].join(",");
  // Focusable regions: cards and scroll areas with a tabindex. One is labelled only when
  // nothing inside it is, since some sites (GitHub) wrap the whole page in one.
  const REGION = "[tabindex]:not([tabindex='-1'])";
  const TEXT = "h1,h2,h3,h4,h5,h6,p,li,dt,dd,blockquote,pre,figcaption";
  const TARGET = `${CONTROL},${REGION},${TEXT}`;
  // What the text inside an element belongs to when labels are handed out.
  const OWNER = `${CONTROL},${TEXT}`;
  // Inline wrappers that loose text often comes in (<div><span>…</span></div>).
  const INLINE = new Set([
    "a", "abbr", "b", "bdi", "bdo", "cite", "code", "em", "font", "i", "kbd", "mark", "q", "s",
    "small", "span", "strong", "sub", "sup", "time", "u", "var",
  ]);
  // Inputs where typing g and w is not text entry.
  const NON_TEXT_INPUTS = new Set([
    "button", "checkbox", "color", "file", "image", "radio", "range", "reset", "submit",
  ]);

  // Closed shadow roots are looked for on custom elements only, which is where web components
  // put them: asking chrome.dom about every element of a long page takes over 50 ms, where the
  // open shadowRoot getter takes a few. (chrome.dom also throws for non-HTML elements.)
  const shadowRootOf = (el) =>
    el.localName.includes("-") && el instanceof HTMLElement
      ? chrome.dom?.openOrClosedShadowRoot?.(el) ?? el.shadowRoot
      : el.shadowRoot;

  let gAt = -Infinity; // timeStamp of a g that may start the chord
  let scrolledAt = -Infinity;
  let session = null;
  let overlay = null;
  const swallowedKeyUps = new Set(); // codes whose keydown was consumed

  // Label colours per desktop theme, keyed by the palette label that names Helium's theme
  // extension; background.js stores the current one. Rose Pine is the desktop default.
  const THEMES = @themes@;
  const DEFAULT_THEME = @defaultTheme@;
  let colours = THEMES[DEFAULT_THEME];

  // The overlay lives in the top layer, above page z-indices and modal dialogs, behind a
  // closed shadow root so page styles can't reach the labels.
  const css = () => `
    .label, .flash { position: absolute; box-sizing: border-box; }
    .label {
      font: 700 12px/16px monospace; height: 16px; padding: 0 3px; border-radius: 3px;
      color: ${colours.fg}; background: ${colours.bg}; box-shadow: 0 1px 3px rgb(0 0 0 / 0.5);
      white-space: pre; letter-spacing: 0.02em;
    }
    .gutter { transform: translateX(-100%); }
    .flash {
      border: 2px solid ${colours.bg}; border-radius: 4px;
      animation: fade ${FLASH}ms ease-out forwards;
    }
    @keyframes fade { from { opacity: 1; } to { opacity: 0; } }
  `;

  function openOverlay() {
    closeOverlay();
    const host = document.createElementNS(XHTML, "jump-labels");
    host.setAttribute("popover", "manual");
    host.style.cssText = [
      "all: initial", "display: block", "position: fixed", "inset: 0", "width: 100vw",
      "height: 100vh", "margin: 0", "padding: 0", "border: 0", "background: transparent",
      "overflow: visible", "pointer-events: none", "z-index: 2147483647",
    ].map((d) => `${d} !important;`).join("");
    const root = host.attachShadow({ mode: "closed" });
    const style = document.createElementNS(XHTML, "style");
    style.textContent = css();
    root.append(style);
    document.documentElement.append(host);
    try {
      host.showPopover();
    } catch {
      // Not fully active, or no popover support: the fixed z-index has to do.
    }
    overlay = { host, root, style };
    return root;
  }

  function closeOverlay() {
    overlay?.host.remove();
    overlay = null;
  }

  // Follow theme switches live, open labels included.
  function setTheme(name) {
    colours = THEMES[name] ?? THEMES[DEFAULT_THEME];
    if (overlay) {
      overlay.style.textContent = css();
    }
  }
  chrome.storage.local.get("theme").then(({ theme }) => setTheme(theme), () => {});
  chrome.storage.onChanged.addListener((changes, area) => {
    if (area === "local" && changes.theme) {
      setTheme(changes.theme.newValue);
    }
  });

  // "control", "text", "region" or null, cached for one round of labelling: matching these
  // selector lists is most of what labelling a big page costs.
  const kinds = new Map();
  function kindOf(el) {
    let kind = kinds.get(el);
    if (kind === undefined) {
      kind = !el.matches(TARGET) ? null
        : el.matches(CONTROL) ? "control"
        : el.matches(TEXT) ? "text"
        : "region";
      kinds.set(el, kind);
    }
    return kind;
  }

  function editable(el) {
    if (!(el instanceof Element)) {
      return false;
    }
    if (el.isContentEditable || el.localName === "textarea" || el.localName === "select" ||
      el.matches("[role=textbox],[role=searchbox]")) {
      return true;
    }
    return el.localName === "input" && !NON_TEXT_INPUTS.has(el.type);
  }

  // The key's target is the host when focus is inside a closed shadow root (a search box in a
  // web component), so the focused element is asked too.
  function editableTarget(e) {
    return document.designMode === "on" || editable(e.composedPath()[0]) ||
      editable(deepActiveElement());
  }

  // The letter a key types, whatever Caps Lock or the layout's script (Cyrillic, Greek) say.
  function letter(e) {
    if (e.key.length !== 1 || e.shiftKey) {
      return null;
    }
    const key = e.key.toLowerCase();
    if (ALPHABET.includes(key)) {
      return key;
    }
    const code = /^Key([A-Z])$/.exec(e.code);
    return code ? code[1].toLowerCase() : null;
  }

  function deepActiveElement() {
    let el = document.activeElement;
    for (let root; el && (root = shadowRootOf(el))?.activeElement; ) {
      el = root.activeElement;
    }
    return el;
  }

  // Elements in composed document order, shadow trees included.
  function* walk(root) {
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT);
    for (let el; (el = walker.nextNode()); ) {
      yield el;
      const shadow = shadowRootOf(el);
      if (shadow) {
        yield* walk(shadow);
      }
    }
  }

  function composedContains(outer, node) {
    for (let n = node; n; n = n.parentNode ?? n.host) {
      if (n === outer) {
        return true;
      }
    }
    return false;
  }

  function hitTest(x, y) {
    let hit = document.elementFromPoint(x, y);
    for (let shadow; hit && (shadow = shadowRootOf(hit)); ) {
      const inner = shadow.elementFromPoint(x, y);
      if (!inner || inner === hit) {
        break;
      }
      hit = inner;
    }
    return hit;
  }

  const viewport = () => ({ w: document.documentElement.clientWidth || innerWidth, h: innerHeight });

  function inView(r, vp) {
    return r.width >= 2 && r.height >= 2 && r.bottom > 0 && r.right > 0 && r.top < vp.h && r.left < vp.w;
  }

  // Whether some point of the rect's on-screen part shows the element rather than whatever
  // covers it (sticky headers, cookie banners, scroll clipping). Hit testing passes through
  // elements with pointer-events: none, so for those whatever lies beneath has to do.
  function uncovered(el, r, vp) {
    const left = Math.max(r.left, 0);
    const right = Math.min(r.right, vp.w - 1);
    const top = Math.max(r.top, 0);
    const bottom = Math.min(r.bottom, vp.h - 1);
    const midY = (top + bottom) / 2;
    for (const x of [(left + right) / 2, left + Math.min(4, (right - left) / 2)]) {
      const hit = hitTest(x, midY);
      if (hit && (composedContains(el, hit) ||
        (composedContains(hit, el) && getComputedStyle(el).pointerEvents === "none"))) {
        return true;
      }
    }
    return false;
  }

  // The first on-screen rect that shows the element: a line that has scrolled under a sticky
  // header gives way to the next one.
  function shownRect(el, rects, vp) {
    let tries = 6;
    for (const r of rects) {
      if (!inView(r, vp)) {
        continue;
      }
      if (uncovered(el, r, vp)) {
        return r;
      }
      if (!--tries) {
        break;
      }
    }
    return null;
  }

  function interactiveAnchor(el, vp) {
    if (el.matches(":disabled") || el.closest("[inert]")) {
      return null;
    }
    // Links wrapping block content can have empty line boxes; fall back to their box.
    return shownRect(el, el.getClientRects(), vp) ??
      shownRect(el, [el.getBoundingClientRect()], vp);
  }

  // Whether an element lays out as a block of its own rather than flowing in a line. Inline
  // tags count as inline even where a flex or grid parent makes blocks of them, so that loose
  // text in a <span> goes to the block around it.
  function blockish(el) {
    if (INLINE.has(el.localName)) {
      return false;
    }
    const { display } = getComputedStyle(el);
    return display !== "inline" && display !== "contents";
  }

  // Whether an element may hold loose text: text of its own, or inline wrappers around some.
  function mayHoldText(el) {
    for (let n = el.firstChild; n; n = n.nextSibling) {
      if (n.nodeType === Node.TEXT_NODE ? n.data.trim() : INLINE.has(n.localName)) {
        return true;
      }
    }
    return false;
  }

  // A text block is labelled at the start of the first on-screen line of its own text: text
  // that isn't inside a nested block or a control, which get their own labels. The line is
  // widened to the block's content edge, since a link may start it. Blocks that are mostly
  // links (a date beside a post title, a link with a dash of caption) leave it to the links.
  // Loose text is text outside any text block or control, as in a comment whose first
  // paragraph sits bare in a div; it belongs to its nearest block-level element.
  function textAnchor(el, vp, loose) {
    if (el.closest(CONTROL) || el.closest("[inert]")) {
      return null;
    }
    let own = 0;
    let linked = 0;
    const walker = document.createTreeWalker(el, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT, (n) => {
      if (n.nodeType === Node.TEXT_NODE) {
        return NodeFilter.FILTER_ACCEPT;
      }
      const kind = kindOf(n);
      if (kind === "control" || kind === "text") {
        linked += kind === "control" ? n.textContent.trim().length : 0;
        return NodeFilter.FILTER_REJECT;
      }
      return n.namespaceURI !== XHTML || (loose && blockish(n))
        ? NodeFilter.FILTER_REJECT
        : NodeFilter.FILTER_SKIP;
    });
    const range = document.createRange();
    let line = null;
    for (let node; (node = walker.nextNode()); ) {
      const length = node.data.trim().length;
      if (!length) {
        continue;
      }
      own += length;
      if (!line) {
        range.selectNodeContents(node);
        line = shownRect(el, range.getClientRects(), vp);
      }
    }
    if (!line || own < linked || (loose && own < LOOSE_TEXT)) {
      return null;
    }
    const box = el.getBoundingClientRect();
    const style = getComputedStyle(el);
    const contentLeft = box.left + parseFloat(style.borderLeftWidth) + parseFloat(style.paddingLeft);
    const left = Math.min(line.left, Math.max(contentLeft, 0));
    return new DOMRect(left, line.top, line.right - left, line.height);
  }

  function collect() {
    const vp = viewport();
    const active = deepActiveElement();
    const cursorOnScreen =
      active && active !== document.body && active !== document.documentElement &&
      inView(active.getBoundingClientRect(), vp);
    const targets = [];
    const regions = []; // labelled focusable regions, dropped once something inside is labelled
    let split = -1; // targets before this index precede the cursor in the document
    let lastControl = null;
    for (const el of walk(document)) {
      if (cursorOnScreen && el === active) {
        split = targets.length;
      }
      if (el === active) {
        continue;
      }
      const kind = kindOf(el) ??
        (el instanceof HTMLElement && !INLINE.has(el.localName) && mayHoldText(el) ? "loose" : null);
      if (!kind) {
        continue;
      }
      const box = el.getBoundingClientRect();
      if (box.bottom <= 0 || box.top >= vp.h || box.right <= 0 || box.left >= vp.w) {
        continue;
      }
      if (kind === "loose" && (!blockish(el) || el.closest(OWNER))) {
        continue;
      }
      if (!el.checkVisibility({ opacityProperty: true, visibilityProperty: true })) {
        continue;
      }
      const interactive = kind === "control" || kind === "region";
      const anchor = interactive ? interactiveAnchor(el, vp) : textAnchor(el, vp, kind === "loose");
      if (!anchor) {
        continue;
      }
      // A control wrapped by another of the same size (a button in a link) would stack two
      // labels in one place.
      if (interactive && lastControl && composedContains(lastControl.el, el) &&
        Math.abs(lastControl.anchor.left - anchor.left) < 4 &&
        Math.abs(lastControl.anchor.top - anchor.top) < 4) {
        continue;
      }
      const target = { el, anchor, text: !interactive };
      for (const region of regions) {
        region.drop ||= composedContains(region.el, el);
      }
      if (kind === "control") {
        lastControl = target;
      } else if (kind === "region") {
        regions.push(target);
      }
      targets.push(target);
    }
    const kept = targets.filter((t) => !t.drop);
    if (split < 0) {
      return kept;
    }
    split -= targets.slice(0, split).filter((t) => t.drop).length;
    // Helix's order: the nearest target after the cursor, then the nearest before it, and so on.
    const after = kept.slice(split);
    const before = kept.slice(0, split).reverse();
    const ordered = [];
    for (let i = 0; i < Math.max(after.length, before.length); i++) {
      if (i < after.length) {
        ordered.push(after[i]);
      }
      if (i < before.length) {
        ordered.push(before[i]);
      }
    }
    return ordered;
  }

  function start() {
    stopGlide();
    const targets = collect().slice(0, ALPHABET.length ** 2);
    kinds.clear();
    if (!targets.length) {
      return;
    }
    const root = openOverlay();
    const vp = viewport();
    const labels = targets.map((target, i) => {
      const name = ALPHABET[Math.floor(i / ALPHABET.length)] + ALPHABET[i % ALPHABET.length];
      const node = document.createElementNS(XHTML, "div");
      node.className = "label";
      node.textContent = name;
      const r = target.anchor;
      // Text labels sit in the gutter left of the line so they don't cover links that start it.
      const gutter = target.text && r.left >= 30;
      node.classList.toggle("gutter", gutter);
      const x = gutter ? r.left - 4 : Math.min(Math.max(r.left, 0), vp.w - 24);
      const y = r.height <= 40 ? r.top + (r.height - 16) / 2 : Math.max(r.top, 0) + 2;
      node.style.left = `${x}px`;
      node.style.top = `${Math.min(Math.max(y, 0), vp.h - 16)}px`;
      root.append(node);
      return { name, node, target, x, gone: false };
    });
    unstack(labels, vp);
    session = { labels, typed: "" };
    addEventListener("scroll", sessionScroll, { capture: true, passive: true });
    addEventListener("resize", cancel);
    addEventListener("blur", cancel);
    addEventListener("pointerdown", cancel, true);
    document.addEventListener("visibilitychange", cancel);
  }

  // Labels of targets closer together than a label is wide (a short link, then the next) would
  // hide each other's letters. Left to right, each moves right until it is clear.
  function unstack(labels, vp) {
    const boxes = labels.map(({ node }) => node.getBoundingClientRect());
    const order = labels.map((_, i) => i).sort((a, b) => boxes[a].left - boxes[b].left);
    const placed = [];
    for (const i of order) {
      const { left, top, width, height } = boxes[i];
      let x = left;
      for (let moved = true; moved; ) {
        moved = false;
        for (const p of placed) {
          if (x < p.right && p.left < x + width && top < p.bottom && p.top < top + height) {
            x = p.right + 1;
            moved = true;
          }
        }
      }
      if (x + width > vp.w) {
        x = left; // no room: better stacked than off screen
      }
      if (x !== left) {
        labels[i].node.style.left = `${labels[i].x + x - left}px`;
      }
      placed.push({ left: x, right: x + width, top, bottom: top + height });
    }
  }

  function end() {
    session = null;
    removeEventListener("scroll", sessionScroll, { capture: true });
    removeEventListener("resize", cancel);
    removeEventListener("blur", cancel);
    removeEventListener("pointerdown", cancel, true);
    document.removeEventListener("visibilitychange", cancel);
  }

  function cancel() {
    end();
    closeOverlay();
  }

  // Scrolling the page moves every target, so it cancels. Scrolling an inner scroller (a
  // carousel turning by itself, a sidebar) only takes the labels inside it away.
  function sessionScroll(e) {
    const scroller = e.target;
    if (!(scroller instanceof Element) || scroller === document.scrollingElement) {
      cancel();
      return;
    }
    for (const label of session.labels) {
      if (!label.gone && composedContains(scroller, label.target.el)) {
        label.gone = true;
        label.node.hidden = true;
      }
    }
    if (session.labels.every(({ gone }) => gone)) {
      cancel();
    }
  }

  function narrow(typed) {
    session.typed = typed;
    for (const { name, node, gone } of session.labels) {
      node.hidden = gone || !name.startsWith(typed);
      node.textContent = name.slice(typed.length);
    }
  }

  function jump(target) {
    end();
    const { el, anchor } = target;
    if (!el.isConnected) {
      // The page replaced it while the labels were up.
      closeOverlay();
      return;
    }
    const focused = () => deepActiveElement() === el;
    if (target.text) {
      // Put the caret at the start of the labelled line, so caret browsing, Shift+arrows and
      // find-next carry on from there.
      const pos = document.caretPositionFromPoint?.(anchor.left + 1, anchor.top + anchor.height / 2);
      try {
        getSelection().collapse(pos.offsetNode, pos.offset);
      } catch {
        // No caret position there (a shadow tree, or an image line); focus alone will do.
      }
    }
    el.focus({ preventScroll: true });
    if (!focused() && !el.hasAttribute("tabindex")) {
      // Text blocks and click-handler controls can't take focus; lend them a tabindex until
      // they lose it. Tab then continues from here.
      el.setAttribute("tabindex", "-1");
      el.addEventListener("blur", () => el.removeAttribute("tabindex"), { once: true });
      el.focus({ preventScroll: true });
    }
    flash(target.text ? el.getBoundingClientRect() : anchor);
  }

  function flash(r) {
    const root = openOverlay();
    const vp = viewport();
    const left = Math.max(r.left, 0) - 3;
    const top = Math.max(r.top, 0) - 3;
    const ring = document.createElementNS(XHTML, "div");
    ring.className = "flash";
    Object.assign(ring.style, {
      left: `${left}px`,
      top: `${top}px`,
      width: `${Math.min(r.right, vp.w) + 3 - left}px`,
      height: `${Math.min(r.bottom, vp.h) + 3 - top}px`,
    });
    root.append(ring);
    const host = overlay.host;
    setTimeout(() => overlay?.host === host && closeOverlay(), FLASH);
  }

  function consume(e) {
    e.preventDefault();
    e.stopImmediatePropagation();
    swallowedKeyUps.add(e.code);
  }

  function sessionKey(e) {
    if (e.ctrlKey || e.altKey || e.metaKey) {
      cancel();
      return;
    }
    if (["Shift", "CapsLock"].includes(e.key)) {
      return;
    }
    consume(e);
    if (e.key === "Backspace" && session.typed) {
      narrow("");
      return;
    }
    const key = letter(e);
    if (!key) {
      cancel();
      return;
    }
    const typed = session.typed + key;
    const matches = session.labels.filter(({ name, gone }) => !gone && name.startsWith(typed));
    if (!matches.length) {
      cancel();
    } else if (typed.length === 2) {
      jump(matches[0].target);
    } else {
      narrow(typed);
    }
  }

  // Measure once scrolling has settled, so labels from a smooth scroll still in flight don't
  // land in the wrong place, or vanish as soon as they appear. Something that never stops
  // scrolling (a self-turning carousel) only delays them.
  function startWhenSettled(since = performance.now()) {
    const wait = Math.min(scrolledAt + SCROLL_SETTLE, since + SETTLE_LIMIT) - performance.now();
    if (wait > 0) {
      setTimeout(() => startWhenSettled(since), wait);
    } else {
      start();
    }
  }

  // j and k move a target scroll offset and the scroller glides after it. A press moves the
  // target a step, so a tap eases out; once the key repeats, the target moves steadily at a
  // step per repeat until the key comes up, so a held key scrolls evenly rather than in
  // pulses. They scroll what the focus or the last click is in, as arrow keys do, falling
  // back to the page, then to the largest scroller on screen for pages that scroll a div.
  let glide = null;
  let pressed = null; // WeakRef to the element last clicked
  let noScrollerAt = -Infinity; // when the search for a scroller last came up empty
  let repeatEvery = 40; // ms between key repeats, learnt as they come (Hyprland's default 25/s)

  // Whether the user could scroll el further in direction dy.
  function hasRoom(el, dy) {
    const max = el.scrollHeight - el.clientHeight;
    if (max < 1) {
      return false;
    }
    let overflow;
    if (el === document.scrollingElement) {
      // The viewport takes the root's overflow, or the body's when the root's is visible.
      overflow = getComputedStyle(document.documentElement).overflowY;
      if (overflow === "visible" && document.body) {
        overflow = getComputedStyle(document.body).overflowY;
      }
      if (overflow === "hidden" || overflow === "clip") {
        return false; // locked, as under a modal
      }
    } else {
      overflow = getComputedStyle(el).overflowY;
      if (overflow !== "auto" && overflow !== "scroll" && overflow !== "overlay") {
        return false;
      }
    }
    return dy > 0 ? el.scrollTop < max - 0.5 : el.scrollTop > 0.5;
  }

  function scrollerFor(dy) {
    const active = deepActiveElement();
    const from = active && active !== document.body && active !== document.documentElement
      ? active
      : pressed?.deref();
    for (let n = from?.isConnected ? from : null; n; n = n.parentNode ?? n.host) {
      if (n instanceof Element && hasRoom(n, dy)) {
        return n;
      }
    }
    const root = document.scrollingElement;
    if (root && hasRoom(root, dy)) {
      return root;
    }
    if (performance.now() - noScrollerAt < 1000) {
      return null; // a page that doesn't scroll: don't search it on every key repeat
    }
    const vp = viewport();
    let best = null;
    let bestArea = 0;
    for (const el of walk(document)) {
      if (el.scrollHeight - el.clientHeight < 1) {
        continue;
      }
      const r = el.getBoundingClientRect();
      const area = Math.max(0, Math.min(r.right, vp.w) - Math.max(r.left, 0)) *
        Math.max(0, Math.min(r.bottom, vp.h) - Math.max(r.top, 0));
      if (area > bestArea && hasRoom(el, dy)) {
        best = el;
        bestArea = area;
      }
    }
    if (!best) {
      noScrollerAt = performance.now();
    }
    return best;
  }

  // dir is 1 for j (down) and -1 for k (up).
  function scrollKey(dir, e) {
    if (e.repeat && glide?.dir === dir) {
      const since = e.timeStamp - glide.heldAt;
      if (since < 200) {
        repeatEvery += (since - repeatEvery) / 4;
      }
      glide.heldAt = e.timeStamp;
      return;
    }
    if (!glide) {
      const dy = dir * SCROLL_STEP;
      const el = scrollerFor(dy);
      if (!el) {
        return;
      }
      if (getComputedStyle(el).scrollSnapType !== "none") {
        // Gliding through snap points would snap back every frame; let the browser pick the
        // next one.
        el.scrollBy({ top: dy, behavior: "smooth" });
        return;
      }
      const top = el.scrollTop;
      glide = { el, pos: top, target: top, set: top, last: 0, frame: 0 };
      glide.frame = requestAnimationFrame(glideFrame);
    }
    Object.assign(glide, { dir, code: e.code, heldAt: 0 });
    moveTarget(glide, dir * SCROLL_STEP);
  }

  function moveTarget(g, dy) {
    g.target = Math.min(Math.max(g.target + dy, 0), g.el.scrollHeight - g.el.clientHeight);
  }

  function glideFrame(now) {
    const g = glide;
    if (!g.el.isConnected || Math.abs(g.el.scrollTop - g.set) > 1) {
      glide = null; // something else scrolled it (the wheel, the page): leave it be
      return;
    }
    const dt = g.last ? now - g.last : 16;
    g.last = now;
    if (g.heldAt && performance.now() - g.heldAt > 3 * repeatEvery + 50) {
      g.heldAt = 0; // repeats stopped without a key-up (focus left the page)
    }
    if (g.heldAt) {
      moveTarget(g, g.dir * SCROLL_STEP * dt / repeatEvery);
    }
    g.pos += (g.target - g.pos) * (1 - Math.exp(-dt / SCROLL_EASE));
    if (Math.abs(g.target - g.pos) < 0.5) {
      g.pos = g.target;
    }
    // Instant, or a page's scroll-behavior: smooth would animate every frame's step again.
    g.el.scrollTo({ top: g.pos, behavior: "instant" });
    g.set = g.el.scrollTop;
    if (g.pos === g.target && !g.heldAt) {
      glide = null;
    } else {
      g.frame = requestAnimationFrame(glideFrame);
    }
  }

  function stopGlide() {
    if (glide) {
      cancelAnimationFrame(glide.frame);
      glide = null;
    }
  }

  // Window capture listeners registered at document_start run before the page's own handlers.
  addEventListener("scroll", (e) => (scrolledAt = e.timeStamp), { capture: true, passive: true });
  addEventListener("pointerdown", (e) => (pressed = new WeakRef(e.composedPath()[0])), true);

  addEventListener("keydown", (e) => {
    if (!e.isTrusted) {
      return;
    }
    if (session) {
      sessionKey(e);
      return;
    }
    if (e.repeat || e.isComposing || e.ctrlKey || e.altKey || e.metaKey || editableTarget(e)) {
      gAt = -Infinity;
      return;
    }
    const key = letter(e);
    if (key === "g") {
      gAt = e.timeStamp; // let it through: the page may have its own g chords
    } else if (key === "w" && e.timeStamp - gAt < CHORD_TIMEOUT) {
      gAt = -Infinity;
      consume(e);
      closeOverlay();
      startWhenSettled();
    } else if (e.key !== "Shift") {
      gAt = -Infinity;
    }
  }, true);

  // j and k are decided after the page has seen the key: sites with j and k of their own
  // (YouTube's pause, Gmail's next message) cancel the key's default, and keep them.
  addEventListener("keydown", (e) => {
    if (!e.isTrusted || e.isComposing || e.ctrlKey || e.altKey || e.metaKey || editableTarget(e)) {
      return;
    }
    const key = letter(e);
    if (key === "j" || key === "k") {
      setTimeout(() => e.defaultPrevented || scrollKey(key === "j" ? 1 : -1, e));
    }
  });

  addEventListener("keyup", (e) => {
    if (glide?.code === e.code) {
      glide.heldAt = 0;
    }
    if (swallowedKeyUps.delete(e.code)) {
      e.preventDefault();
      e.stopImmediatePropagation();
    }
  }, true);
})();
