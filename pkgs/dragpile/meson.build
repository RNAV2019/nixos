project('dragpile', 'cpp',
  version: '0.1',
  default_options: ['buildtype=release', 'cpp_std=c++23'],
)

add_project_arguments(['-Wno-narrowing'], language: 'cpp')

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
