// Runs in the bundled PDF.js viewer before its modules. The patched pdf.mjs asks
// globalThis.bionic which glyphs of each text run to bold, and draws those with an extra
// stroke in the fill colour, so the PDF keeps its own fonts and layout.
(() => {
  // background.js redirects to ?bionic-src=<raw URL>; PDF.js wants it encoded in ?file=.
  const PREFIX = "?bionic-src=";
  if (location.search.startsWith(PREFIX)) {
    const src = location.search.slice(PREFIX.length);
    history.replaceState(
      null,
      "",
      `${location.pathname}?file=${encodeURIComponent(src)}${location.hash}`,
    );
  }

  // Without a file, open nothing rather than PDF.js's sample document.
  document.addEventListener(
    "webviewerloaded",
    () => {
      globalThis.PDFViewerApplicationOptions.set("defaultUrl", "");
    },
    { once: true },
  );

  const LETTER = /^[\p{L}\p{M}]/u;
  // A kerning gap wider than this (thousandths of an em) separates words in PDFs that
  // position words without space glyphs.
  const WORD_GAP = 180;
  // Extra stem thickness for bolded glyphs, in ems.
  const WEIGHT = 0.05;

  // Where the last text run on each canvas ended, and how many letters of an unfinished word
  // it drew, so a word split across runs keeps counting.
  const ends = new WeakMap();
  let pendingCarry = 0;

  globalThis.bionic = {
    enabled: false,

    marks(ctx, glyphs, em) {
      pendingCarry = 0;
      if (!this.enabled) {
        return null;
      }
      const m = ctx.getTransform();
      const last = ends.get(ctx.canvas);
      const emPx = Math.hypot(m.a, m.b) * Math.abs(em);
      let carry = last && Math.hypot(m.e - last.x, m.f - last.y) < 0.15 * emPx ? last.carry : 0;

      const out = new Uint8Array(glyphs.length);
      let word = [];
      const endWord = () => {
        const n = globalThis.bionicFixation(carry + word.length);
        word.forEach((g, k) => {
          if (carry + k < n) {
            out[g] = 1;
          }
        });
        word = [];
        carry = 0;
      };
      glyphs.forEach((g, i) => {
        if (typeof g === "number") {
          if (-g > WORD_GAP) {
            endWord();
          }
          return;
        }
        const u = g.unicode;
        if (!g.isSpace && LETTER.test(u) && !globalThis.bionicUnsegmented.test(u)) {
          word.push(i);
        } else {
          endWord();
        }
      });
      // A word still open at the end may continue in the next run.
      if (word.length) {
        pendingCarry = carry + word.length;
        endWord();
      }
      return out;
    },

    ended(ctx, x) {
      const m = ctx.getTransform();
      ends.set(ctx.canvas, { x: m.a * x + m.e, y: m.b * x + m.f, carry: pendingCarry });
      pendingCarry = 0;
    },

    embolden(ctx, character, x, y, em) {
      ctx.save();
      ctx.strokeStyle = ctx.fillStyle;
      ctx.lineWidth = Math.abs(em) * WEIGHT;
      ctx.lineJoin = "round";
      ctx.strokeText(character, x, y);
      ctx.restore();
    },

    // Glyph outlines drawn as paths are already scaled to one unit per em.
    emboldenPath(ctx, path) {
      ctx.save();
      ctx.strokeStyle = ctx.fillStyle;
      ctx.lineWidth = WEIGHT;
      ctx.lineJoin = "round";
      ctx.stroke(path);
      ctx.restore();
    },
  };

  // Redraw every page and thumbnail when the toggle changes.
  const rerender = () => {
    const app = globalThis.PDFViewerApplication;
    if (!app?.pdfDocument) {
      return;
    }
    for (const page of app.pdfViewer._pages) {
      page.reset();
    }
    for (const thumbnail of app.pdfThumbnailViewer?._thumbnails ?? []) {
      thumbnail.reset();
    }
    app.pdfViewer.update();
    app.pdfRenderingQueue.renderHighestPriority();
  };

  const set = (enabled) => {
    if (globalThis.bionic.enabled !== enabled) {
      globalThis.bionic.enabled = enabled;
      rerender();
    }
  };
  chrome.storage.local.get({ enabled: false }).then(({ enabled }) => set(enabled));
  chrome.storage.onChanged.addListener((changes, area) => {
    if (area === "local" && "enabled" in changes) {
      set(changes.enabled.newValue);
    }
  });
})();
