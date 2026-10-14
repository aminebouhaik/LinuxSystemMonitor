# Development Log: Linux System Monitor

Author: Amine (GitHub: aminebouhaik)
Project: A small Linux system monitor app (like a simple "Task Manager"), written in Vala with GTK4.

---

## My work on 11 October 2026, step by step

Setup

1. I ran `sudo apt install valac meson ninja-build libgtk-4-dev`. Everything was already installed.

### Fixing the CPU reading

2. I fixed my first CPU code: guest time was counted twice, the first reading showed `0.0%` like a real value, a number going backwards gave a huge wrong value, and the math was mixed with file reading so it could not be tested.
3. I moved the CPU logic into `cpu_stats.vala`, wrote `test_cpu_stats.vala` with 10 checks, and updated `meson.build`, `system_info.vala` and `window.vala`.
4. I ran `meson compile -C build`. The test program compiled, but the app failed with an error in `window.vala` (errors 1 and 2 below).
5. I ran `meson test -C build --print-errorlogs`: `cpu-stats OK`, `Ok: 1  Fail: 0`. My CPU test passes on my laptop.
6. I measured my real CPU load with `top` (about 26% busy) and ran `yes > /dev/null` to keep one CPU busy, as a baseline to compare the app against.
7. I ran `meson test` in the wrong folder (error 3 below).

### Making the window look like a real monitor

8. My window only showed the CPU and memory percentages as text, so nothing moved. I picked the GNOME Resources app as the target look and split the work: graphs first, sidebar and process table later.
9. The graph code is ready: a ring buffer for the last 60 seconds, a history graph drawn with Cairo, a metric card, and 4 more tests. It moves smoothly with two clocks: new data every second and redrawing about 60 times a second.
10. I worked through how the kernel and `/proc` work.

### I had an issue with `meson.build`

11. I applied a new `meson.build` and the build failed because stray numbers were pasted into line 2. I also ran `meson setup --wipe` without the folder name (errors 5 and 4 below).

Project decisions

12. I chose the license GPL-3.0 (`GPL-3.0-or-later`) and the application ID `io.github.aminebouhaik.SystemMonitor`, replacing `com.example.SystemMonitor`.

---

## Errors I faced and how they were fixed

Error 1: `The root namespace already contains a definition for 'main'`
- Cause: only a small piece of new code stayed in `window.vala`, and the start of the file was gone. Vala treated the loose lines as a second `main` program.
- Fix: use the complete `window.vala` file. Lesson: replace whole files instead of splicing.

Error 2: `./build/linux-system-monitor: No such file or directory`
- Cause: error 1 stopped the build, so the program was never created. I also typed `/build/...` with a leading slash, which is the wrong place.
- Fix: fix error 1 and run `./build/linux-system-monitor`.

Error 3: `No such build data file .../meson-private/build.dat`
- Cause: I ran `meson test` in the project folder without telling Meson where the build folder is.
- Fix: `meson test -C build`.

Error 4: `Must specify at least one directory name`
- Cause: `meson setup --wipe` needs the build folder name.
- Fix: `meson setup --wipe build`. It was not needed in the end.

Error 5: `meson.build:2:24: ERROR: Expecting rparen got number`
- Cause: stray numbers (`1743 0 0 0`) from terminal output were pasted into line 2 of `meson.build`.
- Fix: write the file again with one terminal command. Lesson: read the line number in the error message.

Error 6: compiler warnings such as `variable set but not used`
- Cause: noise from code that Vala generates. They are warnings, not errors, so I ignored them.

---

## What I learned

1. The kernel counts CPU time, and CPU usage is the change between two counts.

- Where in my code: `CpuUsageCalculator.update()` in `cpu_stats.vala`. The numbers come from `CpuTimes.parse()` in `cpu_stats.vala`, and `read_cpu_usage()` in `system_info.vala` calls both.
- In easy words: the kernel keeps counters of how long the CPUs have been busy and how long they have been idle. The counters only go up and never reset, like the odometer in a car. An odometer shows the total distance, not the speed right now. So one reading tells me nothing about the CPU right now.
- What `update()` does: it remembers the previous reading and compares it with the new one. The formula is: busy percent = 100 × (ticks that passed − idle ticks that passed) ÷ ticks that passed.
- Example from my test `test_percent_from_two_samples()` in `test_cpu_stats.vala`: 900 ticks passed and 500 of them were idle, so 400 were busy. 400 ÷ 900 = 44.4%.

2. `/proc` looks like a folder, but nothing in it is saved on the disk.

- Where in my code: `read_cpu_usage()` in `system_info.vala` reads `/proc/stat`, and `get_memory_usage()` in the same file reads `/proc/meminfo`. Both use `FileUtils.get_contents()`.
- In easy words: `/proc` looks like a normal folder with normal files. But when my code reads `/proc/stat`, the kernel writes the text at that moment from its own counters, like a live display.
- How I can prove it: `ls -l /proc/stat` shows a size of 0, but `cat /proc/stat` prints many lines. The file is empty on the disk, and the text is created only when it is read.
- My app only reads from `/proc`. It never writes there.

3. MemAvailable is the right memory number to show.

- Where in my code: `get_memory_usage()` in `system_info.vala`. It reads the lines `MemTotal:` and `MemAvailable:` and calculates: used percent = (total − available) ÷ total × 100.
- In easy words: Linux fills spare memory with a cache (copies of files) to make the computer faster, and it gives that memory back as soon as a program needs it. So the "free" number always looks small, but the computer is not really full.
- MemAvailable is the kernel's own estimate of how much memory a new program can really use, including that cache.
- Example: 8 GB total and 7 GB available means 1 GB is used, which is 12.5%.
- Still to do: if the `MemAvailable:` line is missing, `get_memory_usage()` shows a wrong value (100% used). I plan to add a fallback.

4. Keeping reading files, doing math and drawing in separate code makes testing possible.

- Where in my code: `CpuTimes.parse()` in `system_info.vala` only turns text into numbers. `read_cpu_usage()` in `system_info.vala` reads the file and passes the text on. `HistoryGraph.draw_graph()` in `history_graph.vala` only draws.
- In easy words: each function does one job. `parse()` takes plain text as input, so my tests in `test_cpu_stats.vala` (for example `test_parse_reads_aggregate_line()`) can give it fake text and check the answer. They need no real `/proc` and no window.
- If everything was in one function, I could not test the math alone, and a bug would be hard to find.

5. Read the first error message first.

- Where in my code: error 1 involved the `MainWindow()` constructor in `window.vala` and `main()` in `main.vala`. Error 5 was in `meson.build`, which is not a Vala file.
- In easy words: Vala said `The root namespace already contains a definition for 'main'`. That first message was the real cause. `window.vala` had lost its beginning, so the loose line `var system_info = new SystemInfo();` became a second hidden `main`, which clashed with my real `main()` in `main.vala`.
- Everything after that, like `No such file or directory` for `./build/linux-system-monitor`, was only a result. The program was never created because the build failed.
- So I read the first error, fix it, rebuild, and only then look at the rest.
---

## Where the project stands at the end of 11 October

- Done and tested: the CPU reading (the CPU test passes on my laptop).
-- Done and tested: the memory reading (the memory test passes on my laptop)
- Ready, but not yet confirmed running: the graph window.
- Not started: process list, disk and network monitoring, sidebar layout.

---

