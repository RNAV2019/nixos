;; Steel init script, run by the plugin-enabled Helix after helix.scm.
;; Everything else (theme, editor options, languages) still comes from the
;; home-manager-generated config.toml / languages.toml.

(require "helix/keymaps.scm")
(require "forest/forest.scm")

;; Sidebar side, plus entries the tree never shows.
(forest-configure! 'left
                   #:ignore (list ".git" ".direnv" "target" "node_modules" "__pycache__" "result"))

;; 'snacks = persistent sidebar, 'mini = floating Miller columns.
(forest-set-style! 'snacks)

;; Left unset on purpose: giving the sidebar its own background would paint over
;; rose_pine_transparent.
;; (forest-set-sidebar-bg! #:focused "#191724" #:unfocused "#1f1d2e")

;; The divider now defaults to the fg helix uses for its own split dividers
;; (rose-pine overlay, #26233a). Override with a rose-pine value if you want it
;; louder: highlight_med #403d52, muted #6e6a86.
;; (forest-set-separator-color! "#403d52")

(keymap (global)
        (normal (space (e ":forest-toggle"))))
