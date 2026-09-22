;; Steel init script, run after helix.scm. Other settings live in the
;; home-manager-generated config.toml / languages.toml.

(require "helix/keymaps.scm")
(require "forest/forest.scm")

;; Sidebar side, plus entries the tree never shows.
(forest-configure! 'left
                   #:ignore (list ".git" ".direnv" "target" "node_modules" "__pycache__" "result"))

;; 'snacks = persistent sidebar, 'mini = floating Miller columns.
(forest-set-style! 'snacks)

;; No sidebar background, so the transparent theme shows through.
;; (forest-set-sidebar-bg! #:focused "#191724" #:unfocused "#1f1d2e")

;; The divider matches Helix's own split dividers by default.
;; (forest-set-separator-color! "#403d52")

(keymap (global)
        (normal (space (e ":forest-toggle"))))
