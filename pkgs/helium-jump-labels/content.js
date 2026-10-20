// Helix's `gw` for web pages. Typing g then w outside a text field puts a two-letter label on
// every link, control and block of text in view; typing a label moves focus there. As in Helix,
// labels are handed out alternately after and before the cursor (here, the focused element),
// the first letter narrows them down, and any other key cancels.
(() => {
  if (globalThis.__jumpLabels) {
    return;
  }
  globalThis.__jumpLabels = true;

  const ALPHABET = "abcdefghijklmnopqrstuvwxyz"; // Helix's default jump-label-alphabet
  const CHORD_TIMEOUT = 1000; // ms allowed between g and w
  const SCROLL_SETTLE = 120; // ms without scrolling before labels are measured
  const FLASH = 360; // ms the jumped-to element stays outlined
  const XHTML = "http://www.w3.org/1999/xhtml";

  const INTERACTIVE = [
    "a[href]", "area[href]", "button", "input:not([type=hidden])", "select", "textarea",
    "summary", "iframe", "audio[controls]", "video[controls]",
    "[contenteditable]:not([contenteditable=false])", "[tabindex]:not([tabindex='-1'])",
    ...["button", "link", "checkbox", "radio", "switch", "tab", "menuitem", "option",
      "treeitem", "combobox", "textbox", "searchbox", "slider"].map((r) => `[role=${r}]`),
  ].join(",");
  const TEXT = "h1,h2,h3,h4,h5,h6,p,li,dt,dd,blockquote,pre,figcaption";
  const TARGET = `${INTERACTIVE},${TEXT}`;
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

  function editableTarget(e) {
    if (document.designMode === "on") {
      return true;
    }
    const el = e.composedPath()[0];
    if (!(el instanceof Element)) {
      return false;
    }
    if (el.isContentEditable || el.localName === "textarea" || el.localName === "select") {
      return true;
    }
    return el.localName === "input" && !NON_TEXT_INPUTS.has(el.type);
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
  // covers it (sticky headers, cookie banners, scroll clipping).
  function uncovered(el, r, vp) {
    const left = Math.max(r.left, 0);
    const right = Math.min(r.right, vp.w - 1);
    const top = Math.max(r.top, 0);
    const bottom = Math.min(r.bottom, vp.h - 1);
    const midY = (top + bottom) / 2;
    for (const x of [(left + right) / 2, left + Math.min(4, (right - left) / 2)]) {
      const hit = hitTest(x, midY);
      if (hit && composedContains(el, hit)) {
        return true;
      }
    }
    return false;
  }

  function firstVisibleRect(rects, vp) {
    for (const r of rects) {
      if (inView(r, vp)) {
        return r;
      }
    }
    return null;
  }

  function interactiveAnchor(el, vp) {
    if (el.matches(":disabled") || el.closest("[inert]")) {
      return null;
    }
    // Links wrapping block content can have empty line boxes; fall back to their box.
    let r = firstVisibleRect(el.getClientRects(), vp);
    r ??= firstVisibleRect([el.getBoundingClientRect()], vp);
    return r && uncovered(el, r, vp) ? r : null;
  }

  // A text block is labelled at the start of the first on-screen line of its own text: text
  // that isn't inside a nested block or a control, which get their own labels. The line is
  // widened to the block's content edge, since a link may start it. Blocks that are mostly
  // links (a date beside a post title, a link with a dash of caption) leave it to the links.
  function textAnchor(el, vp) {
    if (el.closest(INTERACTIVE) || el.closest("[inert]")) {
      return null;
    }
    const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
    const range = document.createRange();
    let line = null;
    let own = 0;
    let linked = 0;
    for (let node; (node = walker.nextNode()); ) {
      const length = node.data.trim().length;
      if (!length) {
        continue;
      }
      const owner = node.parentElement.closest(TARGET);
      if (owner !== el) {
        linked += owner.matches(INTERACTIVE) && el.contains(owner) ? length : 0;
        continue;
      }
      own += length;
      if (!line) {
        range.selectNodeContents(node);
        const r = firstVisibleRect(range.getClientRects(), vp);
        line = r && uncovered(el, r, vp) ? r : null;
      }
    }
    if (!line || own < linked) {
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
    let split = -1; // targets before this index precede the cursor in the document
    let lastInteractive = null;
    for (const el of walk(document)) {
      if (cursorOnScreen && el === active) {
        split = targets.length;
      }
      if (el === active || !el.matches(TARGET)) {
        continue;
      }
      const box = el.getBoundingClientRect();
      if (box.bottom <= 0 || box.top >= vp.h || box.right <= 0 || box.left >= vp.w) {
        continue;
      }
      if (!el.checkVisibility({ opacityProperty: true, visibilityProperty: true })) {
        continue;
      }
      const interactive = el.matches(INTERACTIVE);
      const anchor = interactive ? interactiveAnchor(el, vp) : textAnchor(el, vp);
      if (!anchor) {
        continue;
      }
      // A control wrapped by another of the same size (a button in a focusable card) would
      // stack two labels in one place.
      if (interactive && lastInteractive && composedContains(lastInteractive.el, el) &&
        Math.abs(lastInteractive.anchor.left - anchor.left) < 4 &&
        Math.abs(lastInteractive.anchor.top - anchor.top) < 4) {
        continue;
      }
      const target = { el, anchor, text: !interactive };
      if (interactive) {
        lastInteractive = target;
      }
      targets.push(target);
    }
    if (split < 0) {
      return targets;
    }
    // Helix's order: the nearest target after the cursor, then the nearest before it, and so on.
    const after = targets.slice(split);
    const before = targets.slice(0, split).reverse();
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
    const targets = collect().slice(0, ALPHABET.length ** 2);
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
      return { name, node, target };
    });
    session = { labels, typed: "" };
    addEventListener("scroll", cancel, { capture: true, passive: true });
    addEventListener("resize", cancel);
    addEventListener("blur", cancel);
    addEventListener("pointerdown", cancel, true);
    document.addEventListener("visibilitychange", cancel);
  }

  function end() {
    session = null;
    removeEventListener("scroll", cancel, { capture: true });
    removeEventListener("resize", cancel);
    removeEventListener("blur", cancel);
    removeEventListener("pointerdown", cancel, true);
    document.removeEventListener("visibilitychange", cancel);
  }

  function cancel() {
    end();
    closeOverlay();
  }

  function narrow(typed) {
    session.typed = typed;
    for (const { name, node } of session.labels) {
      const shown = name.startsWith(typed);
      node.hidden = !shown;
      node.textContent = name.slice(typed.length);
    }
  }

  function jump(target) {
    end();
    const { el, anchor } = target;
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
    if (e.key.length !== 1 || !ALPHABET.includes(e.key)) {
      cancel();
      return;
    }
    const typed = session.typed + e.key;
    const matches = session.labels.filter(({ name }) => name.startsWith(typed));
    if (!matches.length) {
      cancel();
    } else if (typed.length === 2) {
      jump(matches[0].target);
    } else {
      narrow(typed);
    }
  }

  // Measure once scrolling has settled, so labels from a smooth scroll still in flight don't
  // land in the wrong place, or vanish as soon as they appear.
  function startWhenSettled() {
    const wait = scrolledAt + SCROLL_SETTLE - performance.now();
    if (wait > 0) {
      setTimeout(startWhenSettled, wait);
    } else {
      start();
    }
  }

  // Window capture listeners registered at document_start run before the page's own handlers.
  addEventListener("scroll", (e) => (scrolledAt = e.timeStamp), { capture: true, passive: true });

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
    if (e.key === "g") {
      gAt = e.timeStamp; // let it through: the page may have its own g chords
    } else if (e.key === "w" && e.timeStamp - gAt < CHORD_TIMEOUT) {
      gAt = -Infinity;
      consume(e);
      closeOverlay();
      startWhenSettled();
    } else if (e.key !== "Shift") {
      gAt = -Infinity;
    }
  }, true);

  addEventListener("keyup", (e) => {
    if (swallowedKeyUps.delete(e.code)) {
      e.preventDefault();
      e.stopImmediatePropagation();
    }
  }, true);
})();
