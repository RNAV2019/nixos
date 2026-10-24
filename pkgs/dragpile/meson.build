project('dragpile', 'cpp',
  version: '0.1',
  default_options: ['buildtype=release', 'cpp_std=c++23'],
)

# Without -fno-gnu-unique the inline globals (PHANDLE, g_pPile, Hyprland's g_p*) become
# STB_GNU_UNIQUE: dlclose can't unmap the plugin, and a rebuilt copy at a new store path
# binds to the old copy's globals, fails to find its hooks and crashes Hyprland on reload.
add_project_arguments(['-Wno-narrowing', '-fno-gnu-unique'], language: 'cpp')

shared_module('dragpile',
  'src/main.cpp',
  'src/Pile.cpp',
  'src/Cards.cpp',
  dependencies: [
    dependency('hyprland'),
    dependency('hyprgraphics'),
    dependency('cairo'),
    dependency('pangocairo'),
    dependency('glib-2.0'),
    dependency('pixman-1'),
    dependency('libdrm'),
    dependency('libinput'),
    dependency('libudev'),
    dependency('wayland-server'),
    dependency('xkbcommon'),
  ],
  name_prefix: 'lib',
  install: true,
)
