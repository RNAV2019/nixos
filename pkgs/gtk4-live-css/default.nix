# GTK 4 that reloads ~/.config/gtk-4.0/gtk.css when it, or any link it resolves through,
# changes, so open libadwaita apps follow `theme-switch`. After
# github.com/saneaspect/gtk4-live-css, extended to links mid-path: the theme's gtk.css sits
# behind ~/.local/state/theme/current, a directory link the switch repoints.
#
# Same name and version as gtk4, so modules/system grafts it into the closure with
# system.replaceDependencies instead of rebuilding everything that links GTK 4.
{gtk4}:
gtk4.overrideAttrs (old: {
  patches = (old.patches or []) ++ [./user-css-live-reload.patch];
})
