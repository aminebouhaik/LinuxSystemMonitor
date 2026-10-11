# SPDX-License-Identifier: GPL-3.0-or-later
project('linux-system-monitor', ['c', 'vala'],
  version: '0.1.0',
  license: 'GPL-3.0-or-later',
  meson_version: '>= 0.60.0',
)

glib_dep    = dependency('glib-2.0')
gobject_dep = dependency('gobject-2.0')
gtk_dep     = dependency('gtk4')

executable('linux-system-monitor',
  files(
    'src/main.vala',
    'src/application.vala',
    'src/window.vala',
    'src/system_info.vala',
    'src/cpu_stats.vala',
    'src/ring_buffer.vala',
    'src/history_graph.vala',
    'src/metric_card.vala',
  ),
  dependencies: [glib_dep, gobject_dep, gtk_dep],
  install: true,
)

# Application menu entry. The file name must match the application ID.
install_data('data/io.github.aminebouhaik.SystemMonitor.desktop',
  install_dir: get_option('datadir') / 'applications',
)

# Pure logic (no GTK) is compiled separately so tests stay fast and simple.
test_cpu_stats = executable('test-cpu-stats',
  files('tests/test_cpu_stats.vala', 'src/cpu_stats.vala'),
  dependencies: [glib_dep, gobject_dep],
)
test('cpu-stats', test_cpu_stats)

test_ring_buffer = executable('test-ring-buffer',
  files('tests/test_ring_buffer.vala', 'src/ring_buffer.vala'),
  dependencies: [glib_dep, gobject_dep],
)
test('ring-buffer', test_ring_buffer)
