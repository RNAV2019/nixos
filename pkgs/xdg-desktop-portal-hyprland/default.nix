# xdg-desktop-portal-hyprland, handing the requesting app's id to the share picker.
{xdg-desktop-portal-hyprland}:
xdg-desktop-portal-hyprland.overrideAttrs (old: {
  patches = (old.patches or []) ++ [./app-id.patch];
})
