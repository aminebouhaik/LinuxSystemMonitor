# Linux System Monitor

A GTK4 system monitor written in Vala. It shows live CPU and memory usage
as scrolling history graphs. It reads data only from the Linux `/proc`
filesystem and needs no special privileges.

**Status:** early development, version 0.1.0.
Implemented: CPU utilization, memory utilization, animated history graphs.
Planned: process list, disk and network monitoring.

## Build dependencies

Ubuntu / Debian package names:

    valac meson ninja-build libgtk-4-dev

Tested with: valac 0.56.18, GTK 4.22.4, GLib 2.88, Meson 1.10.1,
gcc 15.2, Ubuntu <fill in release, e.g. 25.10>.

## Build, test, install

    meson setup build --prefix=/usr
    meson compile -C build
    meson test -C build --print-errorlogs
    meson install -C build --destdir "$PWD/stage"

`--destdir` stages the files without touching the system. Without it,
`meson install` installs into the prefix directly.

Installed files:

    <prefix>/bin/linux-system-monitor
    <prefix>/share/applications/com.example.SystemMonitor.desktop

## Runtime behaviour (what it touches)

- Reads `/proc/stat` and `/proc/meminfo` once per second. Read-only.
- Writes no files, opens no network connections, never needs root.
- Runs on the GTK main loop in a single thread.

## How CPU usage is calculated

`/proc/stat` holds cumulative CPU time counters (in ticks, 1/100 s
each) since boot. The app reads them twice, one second apart:

    busy % = 100 * (total ticks - idle ticks) / total ticks

measured over that interval. "Idle" is idle + iowait. Guest time is
not added to the total, because the kernel already counts it inside
user time. 100% means all logical CPUs were fully busy. The first
sample is shown as "calculating" because one reading cannot give a rate.

## Memory

Used memory = MemTotal - MemAvailable, as a percentage of MemTotal.
MemAvailable is the kernel's estimate of memory available to new
programs without swapping, including reclaimable cache.

## Source layout

| File | Purpose |
|---|---|
| src/cpu_stats.vala | parses /proc/stat, computes CPU % from two samples |
| src/system_info.vala | reads /proc files, feeds the parsers |
| src/ring_buffer.vala | fixed-size history of recent samples |
| src/history_graph.vala | scrolling graph drawn with Cairo |
| src/metric_card.vala | title, current value and graph in one widget |
| src/window.vala | main window and the 1-second timer |
| tests/ | unit tests for the parser, calculator and ring buffer |

## Known limitations

- No application icon yet (uses the theme's system-monitor icon).
- Memory parsing has no fallback for kernels without MemAvailable.

## License

Copyright (C) 2026 <your full name>

Linux System Monitor is free software: you can redistribute it and/or
modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

It is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. The full text is in the LICENSE file.

## Author

<your amine bouhaik> — https://github.com/aminebouhaik