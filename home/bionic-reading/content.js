// Bionic reading for web pages. Each text node keeps its place in the DOM holding the last
// part of its text; the bolded word starts and the gaps between them are inserted before it.
// Frameworks that hold on to their text nodes can still update or remove them, and the
// observer below repairs the split when they do.
(() => {
  const TAG = "bionic-b";
  const XHTML = "http://www.w3.org/1999/xhtml";
  const SKIP = new Set([
    "script", "style", "noscript", "template", "textarea", "input", "select", "option",
    "code", "kbd", "samp", "var", "canvas", "iframe", "object", "embed", "title", "head", TAG,
  ]);
  // Plain-text documents are a single <pre>; elsewhere <pre> is code.
  if (document.contentType !== "text/plain") {
    SKIP.add("pre");
  }
  // Ligature icon fonts turn words like "home" into icons; splitting them breaks the icon.
  // Only the first family counts: font stacks often end in "Segoe UI Symbol".
  const ICON_FONT = /icon|symbol|glyph|awesome/i;
  const WORD = /[\p{L}\p{M}]+(?:['’][\p{L}\p{M}]+)*/gu;
  const LETTER = /\p{L}/u;
  const MARK = /\p{M}/u;
  const BATCH = 250;

  const records = new WeakMap(); // text node -> { inserted, value, full }
  const owners = new WeakMap(); // inserted node -> its text node
  const roots = new Set(); // document and every shadow root being watched
  const pendingHosts = new Set(); // custom elements that may attach a shadow root later
  const queue = new Set(); // nodes whose subtrees need processing
  let work = [];
  let workIndex = 0;
  let enabled = false;
  let observer = null;
  let idle = 0;
  let lastHostCheck = 0;

  const shadowRootOf = (el) => chrome.dom?.openOrClosedShadowRoot?.(el) ?? el.shadowRoot;

  function skipElement(el) {
    if (el.namespaceURI !== XHTML || SKIP.has(el.localName)) {
      return true;
    }
    const editable = el.getAttribute("contenteditable");
    return editable !== null && editable !== "false";
  }

  function blocked(node) {
    if (document.designMode === "on") {
      return true;
    }
    for (let el = node.parentElement; el; el = el.parentElement) {
      if (skipElement(el)) {
        return true;
      }
    }
    const root = node.getRootNode();
    return root instanceof ShadowRoot && (skipElement(root.host) || blocked(root.host));
  }

  function attachRoot(root) {
    if (!roots.has(root)) {
      roots.add(root);
      observer.observe(root, { childList: true, subtree: true, characterData: true });
      queue.add(root);
    }
  }

  function watchShadow(el) {
    const root = shadowRootOf(el);
    if (root) {
      pendingHosts.delete(el);
      attachRoot(root);
    } else if (el.localName.includes("-")) {
      pendingHosts.add(el);
    }
  }

  function checkHosts() {
    const now = performance.now();
    if (now - lastHostCheck < 500) {
      return;
    }
    lastHostCheck = now;
    for (const el of pendingHosts) {
      if (!el.isConnected) {
        pendingHosts.delete(el);
      } else if (shadowRootOf(el)) {
        watchShadow(el);
      }
    }
  }

  const candidate = (t) =>
    !records.has(t) && !owners.has(t) && LETTER.test(t.nodeValue);

  // Queue the eligible text nodes under `node`.
  function expand(node) {
    if (!node.isConnected) {
      return;
    }
    if (node.nodeType === Node.TEXT_NODE) {
      if (candidate(node) && !blocked(node)) {
        work.push(node);
      }
      return;
    }
    if (node.nodeType === Node.ELEMENT_NODE) {
      if (skipElement(node) || blocked(node)) {
        return;
      }
      watchShadow(node);
    } else if (node instanceof ShadowRoot && blocked(node.host)) {
      return;
    }
    const walker = document.createTreeWalker(node, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT, {
      acceptNode(n) {
        if (n.nodeType === Node.ELEMENT_NODE) {
          if (skipElement(n)) {
            return NodeFilter.FILTER_REJECT;
          }
          watchShadow(n);
          return NodeFilter.FILTER_SKIP;
        }
        return candidate(n) ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_SKIP;
      },
    });
    for (let n = walker.nextNode(); n; n = walker.nextNode()) {
      work.push(n);
    }
  }

  // Read phase: everything that needs computed style, before any DOM writes.
  function plan(t, styles) {
    if (!t.isConnected || !candidate(t)) {
      return null;
    }
    const parent = t.parentElement ?? t.getRootNode().host;
    if (!parent) {
      return null;
    }
    let style = styles.get(parent);
    if (!style) {
      const cs = getComputedStyle(parent);
      style = {
        // Split text in a flex or grid container becomes separate items that the container
        // spaces apart, and capitalize treats every split piece as a new word.
        skip:
          ICON_FONT.test(cs.fontFamily.split(",")[0]) ||
          /flex|grid/.test(cs.display) ||
          cs.textTransform === "capitalize",
        weight: parseInt(cs.fontWeight, 10) >= 600 ? "900" : "700",
      };
      styles.set(parent, style);
    }
    return style.skip ? null : { t, text: t.nodeValue, weight: style.weight };
  }

  // Write phase.
  function apply({ t, text, weight }) {
    if (t.nodeValue !== text || !t.parentNode) {
      return;
    }
    const frag = document.createDocumentFragment();
    const inserted = [];
    const add = (node) => {
      frag.append(node);
      inserted.push(node);
    };
    let pos = 0;
    for (const m of text.matchAll(WORD)) {
      const word = m[0];
      if (globalThis.bionicUnsegmented.test(word)) {
        continue;
      }
      let cut = globalThis.bionicFixation([...word].length);
      // Count by code points, and keep combining marks with their letter.
      cut = [...word].slice(0, cut).join("").length;
      while (cut < word.length && MARK.test(word[cut])) {
        cut++;
      }
      if (m.index > pos) {
        add(document.createTextNode(text.slice(pos, m.index)));
      }
      const b = document.createElement(TAG);
      b.textContent = word.slice(0, cut);
      b.style.setProperty("font-weight", weight, "important");
      add(b);
      pos = m.index + cut;
    }
    if (!inserted.length) {
      return;
    }
    t.parentNode.insertBefore(frag, t);
    const value = text.slice(pos);
    t.nodeValue = value;
    records.set(t, { inserted, value, full: text });
    for (const node of inserted) {
      owners.set(node, t);
    }
  }

  // Put a text node back the way the page made it. With keepValue, the page has just set its
  // text, so only the inserted nodes go.
  function restore(t, keepValue) {
    const record = records.get(t);
    if (!record) {
      return;
    }
    records.delete(t);
    for (const node of record.inserted) {
      owners.delete(node);
      node.remove();
    }
    if (!keepValue) {
      t.nodeValue = record.full;
    }
  }

  function handle(mutations) {
    for (const m of mutations) {
      if (m.type === "characterData") {
        const t = m.target;
        const record = records.get(t);
        if (record && t.nodeValue !== record.value) {
          restore(t, true);
          queue.add(t);
        } else if (!record && !owners.has(t)) {
          queue.add(t);
        }
        continue;
      }
      for (const n of m.removedNodes) {
        if (records.has(n)) {
          restore(n, false);
        }
      }
      for (const n of m.addedNodes) {
        if (owners.has(n)) {
          continue;
        }
        // Inserted between a node's bolded start and its tail: undo and redo that node.
        const owner = n.previousSibling && owners.get(n.previousSibling);
        if (owner && owner.parentNode === n.parentNode &&
            n.compareDocumentPosition(owner) & Node.DOCUMENT_POSITION_FOLLOWING) {
          restore(owner, false);
          queue.add(owner);
        }
        queue.add(n);
      }
    }
  }

  // Process queued work for up to `budget` ms; the rest waits for idle time.
  function flush(budget) {
    idle = 0;
    if (!enabled) {
      return;
    }
    handle(observer.takeRecords());
    checkHosts();
    for (const node of queue) {
      expand(node);
    }
    queue.clear();
    const end = performance.now() + budget;
    while (workIndex < work.length && performance.now() < end) {
      const styles = new Map();
      const plans = [];
      for (const t of work.slice(workIndex, workIndex + BATCH)) {
        const p = plan(t, styles);
        if (p) {
          plans.push(p);
        }
      }
      workIndex += BATCH;
      plans.forEach(apply);
    }
    // Drop the records of our own writes.
    observer.takeRecords();
    if (workIndex < work.length) {
      later();
    } else {
      work = [];
      workIndex = 0;
    }
  }

  function later() {
    idle ||= requestIdleCallback((deadline) => flush(Math.max(deadline.timeRemaining(), 8)), {
      timeout: 250,
    });
  }

  function onMutations(mutations) {
    handle(mutations);
    // Small updates are done before the next paint, so new content never shows unbolded.
    flush(8);
  }

  function enable() {
    if (enabled) {
      return;
    }
    enabled = true;
    observer ??= new MutationObserver(onMutations);
    attachRoot(document);
    later();
    // Custom elements often attach their shadow roots after the first pass.
    for (const delay of [1000, 3000]) {
      setTimeout(() => {
        lastHostCheck = 0;
        if (enabled) {
          flush(8);
        }
      }, delay);
    }
  }

  function disable() {
    if (!enabled) {
      return;
    }
    enabled = false;
    if (idle) {
      cancelIdleCallback(idle);
      idle = 0;
    }
    observer.disconnect();
    for (const root of roots) {
      const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
      const tracked = [];
      for (let n = walker.nextNode(); n; n = walker.nextNode()) {
        if (records.has(n)) {
          tracked.push(n);
        }
      }
      for (const t of tracked) {
        restore(t, false);
      }
    }
    roots.clear();
    pendingHosts.clear();
    queue.clear();
    work = [];
    workIndex = 0;
  }

  const set = (on) => (on ? enable() : disable());
  chrome.storage.local.get({ enabled: false }).then(({ enabled: on }) => set(on));
  chrome.storage.onChanged.addListener((changes, area) => {
    if (area === "local" && "enabled" in changes) {
      set(changes.enabled.newValue);
    }
  });
})();
