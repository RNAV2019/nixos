# Local patches

Vendored from [Ra77a3l3-jar/forest.hx](https://github.com/Ra77a3l3-jar/forest.hx)
at upstream commit `7a67b05c6919c9a670a5591fe1e21832d1edcdda`.

## Divergence: all search is removed, from both styles

Upstream's `snacks` sidebar reserves three rows at the top for a rounded,
focus-coloured fuzzy search box. Helix's own file picker already covers that job,
so the box is gone here: the sidebar is now a single centred `Explorer` title row
with the tree starting directly beneath it, which returns two rows of vertical
space and drops the `fuzzy-match` code path entirely.

### `snacks`

Removed:

- The search box render block, the `> query` prompt line, and the `n/m` match counter.
- `*forest-query*`, `*forest-all-files*`, `*forest-search-results*`, `*forest-typing?*`
  and the five `*forest-search-color-*` globals.
- `forest-searching?`, `forest-scan-files!`, `forest-refresh-search!`, `forest-type!`,
  `forest-backspace!`, `forest-enter-search!`, `forest-clear-search!`.
- `forest-match-positions`, `forest-match-style`, `forest-render-name-hl`,
  `forest-search-tree-insert`, `forest-search-build-tree`, `forest-search-flatten` —
  the whole flattened-match renderer.
- `forest-handle-event-typing` and `forest-cursor-fn-fg`, so the fg component has no
  modal typing state and places no caret. Every dual-mode branch
  (`forest-current-entry`, `forest-active-count`, `forest-hit-cursor-for`,
  `forest-render-bg`) collapsed to its browse path.
- `forest-set-search-color!` — **removed from the public API**. Delete any call to it
  from `init.scm` or the plugin will fail to load.
- The `'search` clause in `forest-command-action!` and the `'search` mouse target,
  so `/` and clicks above the tree do nothing in the sidebar.

`forest-scan-files!`'s removal also means opening or refreshing the sidebar no longer
walks the entire workspace recursively.

### `mini`

Upstream's `mini` search is a modal `Search:` input prompt that fuzzy-matches the whole
workspace and re-cascades the column stack onto the hit. Removed:

- `forest-mini-prompt-search!` and `forest-mini-scan-files` — the latter was a second
  full recursive workspace walk, run on every search.
- The `'search` clause in `forest-mini-command-action!` and the `"Fuzzy search"` row in
  `forest-mini-help-rows`.

Nothing else in `mini` changed; the Miller columns and live preview are untouched.

### Shared

With neither style using it, `'search "/"` is gone from `*forest-default-keybinds*`.
`/` is now unbound in both styles and falls through to the catch-all consume, and
`fuzzy-match` is no longer called anywhere in the plugin.

## Re-syncing with upstream

This is a hard fork of a single 2000-line file, not a patch series; expect to redo the
removals by hand. `git diff --no-index` against a fresh clone of the upstream commit
above is the practical starting point.

## Divergence: local fixes and behaviour changes

Applied on top of the search removal above.

### Fixes

- `forest-wider!`, `forest-narrower!` and the unfocused re-render path called
  `(helix.redraw '())`. `redraw` in `helix/commands.scm` is `(define (redraw . args)
  (helix.redraw args))`, so the explicit `'()` arrived as a one-element arg list
  holding an empty list, which the typed-command shim cannot convert to strings —
  `+` silently did nothing and `-` raised `ConversionError: redraw: Could not
  convert SteelVal list to Vector of values`. All three calls are now
  `(helix.redraw)`.

### Behaviour

- `forest-toggle` added and exported, so one key can open and close the sidebar.
  While the tree is focused the fg component swallows every keypress, so a global
  leader binding only ever fires with the editor focused — which is exactly when
  the toggle needs to close the panel.
- `forest-activate!` now calls `forest-close!` when activating a file, so opening
  from the sidebar dismisses it. This mirrors what `mini` already did.
- The which-key popover draws a `Space` title over its top border, one column in,
  matching how Helix renders the node name on its own which-key box.
- The vertical divider took `border-style` from `ui.background`, which in a
  transparent theme carries no foreground at all and so rendered in the terminal's
  default (bright) foreground. It now takes only a foreground — the configured
  colour, else `ui.window`'s fg, the same one Helix uses for its own split
  dividers — and keeps the panel background, so transparency survives.
- `forest-set-separator-color!` added and exported to override that colour with an
  `#rrggbb` string.
- `'quit` rebound from `"q"` to `"e"`, and the `snacks` help row relabelled to
  match. The `'quit` clauses in both command dispatchers are untouched, so
  `(forest-set-keybinds! (hash 'quit "q"))` puts the old key back.
- That rebind is what makes the panel closable from inside itself. The fg
  component owns every keypress while the tree holds focus, so a global leader
  binding never reaches Helix's keymap layer from in there — `space` opens
  forest's own which-key instead, and an unbound key there just dismisses the
  menu. With `'quit` on `"e"`, `space e` dispatches `forest-close!` through that
  menu, matching the global `space e` toggle. Bare `e` closes too, the way every
  forest binding works both directly and through the menu.
- `mini` still closes on any unbound key; that is its own catch-all, not this
  binding.
