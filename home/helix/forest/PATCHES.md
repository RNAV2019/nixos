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
