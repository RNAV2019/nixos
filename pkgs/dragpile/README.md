| `tab_drags` | true | draw a browser tab drag's preview as a card on the springs |
# dragpile

A Hyprland plugin that turns every file drag into board 16d's pile of cards. It works for any
Wayland client and needs no shell. The cards sit below and to the right of the pointer and follow
it on springs. One card is drawn per file, up to `max_cards`, and a count badge appears once there
is more than one file. A card shows a thumbnail where one exists, otherwise a file-type glyph.

## How it works

- **Hooks.** It hooks four private functions in Hyprland's `wl_data_device` implementation
  (`CWLDataDeviceProtocol::initiateDrag`, `renderDND`, `dropDrag`, `abortDrag`).
- **Reading the files.** When a drag offers `text/uri-list`, the plugin asks the source for the
  list itself, the same way a drop target would. Only local `file://` URIs make a pile. Any other
  drag (text, links) keeps the client's own icon.
- **Browser tabs.** Chromium (Helium included) drags a tab out of its strip as a drag offering
  only `chromium/x-window-drag`, with a preview of the page as the icon. With `tab_drags` on, that
  icon becomes a single card on the same springs: offset from the pointer like the pile, swinging
  a little (less the bigger it is), with `card_radius` corners, the `col.border` hairline and a
  soft shadow. It lifts off from where the client put its icon. Each commit to the icon is copied
  from its wl_shm buffer and re-dressed, so a new preview, size or buffer scale is picked up mid
  drag. An icon that isn't wl_shm (dmabuf) is drawn bare from its texture instead.
- **Drawing.** While the pile is up, the client's drag icon is hidden. Its frame callbacks keep
  coming so the source app doesn't stall. The cards are textures drawn in the drag icon's place
  each frame.
- **Physics.** Each card is a damped spring chasing the card in front of it, with a rope limit
  (`max_stretch`) on how far it may trail. Each card also swings on a torsional spring driven by
  its velocity.
- **Card images.** A worker thread builds them, glyph cards first and then thumbnails. Thumbnails
  come from the freedesktop cache (`~/.cache/thumbnails`), or from decoding the image directly
  when it's under `thumbnail_max_mb`.
- **Ending.** A drop sinks the pile into the pointer. A cancel springs it back to where the drag
  began, then fades it out.
- **Events.** It emits `dragstart>>N` and `dragend>>dropped|cancelled` on Hyprland's event
  socket for shells that want to react.

```
hyprctl dragpile                   # state as JSON
hyprctl dragpile demo <paths...>   # a pile without a drag, for tuning (ends after 6 s)
hyprctl dragpile end drop|cancel   # end the demo pile now
```

## Options

All options live under `plugin:dragpile:`. In a Lua config that is
`hl.config({ plugin = { dragpile = { … } } })`. Colours use the usual `rgba(rrggbbaa)` strings.

| option | default | |
|---|---|---|
| `enabled`, `physics`, `thumbnails` | true | `physics = false` snaps the pile to the pointer |
| `card_size`, `card_radius` | 46, 10 | |
| `offset_x`, `offset_y` | 9, 21.5 | front card's top-left corner, measured from the pointer's tip |
| `max_cards` | 5 | |
| `stiffness`, `damping` | 800, 0.68 | the front card's spring; damping below 1 overshoots |
| `follow_falloff`, `max_stretch` | 0.85, 22 | stiffness multiplier per card further back; how far a card may trail its place |
| `tilt_max`, `tilt_lean`, `tilt_stiffness`, `tilt_damping` | 9, 0.0055, 180, 0.45 | |
| `glyph_size`, `glyph_stroke` | 22, 1.6 | |
| `badge_size`, `badge_font`, `badge_font_size` | 20, Inter, 11 | |
| `thumbnail_max_mb` | 64 | |
| `cursor` | "" | cursor shape during a drag; empty keeps Hyprland's `grabbing` |
| `col.card`, `col.border`, `col.badge`, `col.badge_ring`, `col.badge_text` | board 16d | |
| `col.glyph`, `col.glyph_{folder,image,pdf,archive,audio,video}` | board 16d | |

`home/theme.nix` sets the colours per theme. `home/desktop.nix` loads the plugin.

## Testing

`test/dragsrc.c` is a scripted Wayland drag source. It has its own window and a red drag icon,
which should never appear while the plugin is working. It drives a `zwlr_virtual_pointer_v1`.
With `--drive`, it only moves and presses the pointer, so a real application under it starts the
drag. With `--tab` it acts like Chromium dragging a tab: it offers only `chromium/x-window-drag`
and its icon is a 240x150 gradient grabbed at (60, 20); `--icon-scale 2` gives it a HiDPI buffer,
and the script step `icon` swaps the preview mid-drag.

`test/vpointer.c` drives the pointer of whatever runs in the compositor, at absolute positions:
`vpointer --extent W H "abs X Y" "move DX DY MS" down "glide X Y MS" up "wait MS" click …`
(layout px; steps also from `--script FILE`). `test/build.sh` builds both into
`/tmp/dragpile-test/bin`.

- `test/run.sh` runs the scenarios in `test/scenarios` inside a nested Hyprland, on a headless
  output. `DRAGPILE_OPTS="tab_drags = false"` adds plugin options.
- `test/run-live.sh` runs them on an empty workspace of the live session.

Both take grim screenshots at the times listed in each `.shots` file.

**Limits.**
- Drags started by X11 apps are not covered, since Hyprland doesn't bridge them into Wayland.
- A Flatpak source that offers only `application/vnd.portal.filetransfer` keeps its own icon.
- During a workspace-switch animation, the pile slides with the workspace, as Hyprland's own drag
  icons do.
