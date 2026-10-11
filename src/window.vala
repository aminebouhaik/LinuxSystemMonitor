// SPDX-License-Identifier: GPL-3.0-or-later
namespace SystemMonitor {

    public class MainWindow : Gtk.ApplicationWindow {

        public MainWindow(Gtk.Application app) {
            Object(
                application: app,
                title: "Linux System Monitor",
                default_width: 900,
                default_height: 600
            );

            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            box.set_margin_top(24);
            box.set_margin_bottom(24);
            box.set_margin_start(24);
            box.set_margin_end(24);

            var title_label = new Gtk.Label("Linux System Monitor");
            title_label.add_css_class("title-1");

            var subtitle = new Gtk.Label(
                "Monitor your system performance in real time."
            );

            box.append(title_label);
            box.append(subtitle);

            set_child(box);

            var system_info = new SystemInfo();

            var cpu_card = new MetricCard("CPU", "#3584e4");
            var memory_card = new MetricCard("Memory", "#c061cb");

            box.append(cpu_card);
            box.append(memory_card);

            // Baseline CPU sample, so the first timer tick has a previous
            // sample to compare against.
            double baseline;
            system_info.read_cpu_usage(out baseline);

            Timeout.add_seconds(1, () => {
                double cpu;
                if (system_info.read_cpu_usage(out cpu)) {
                    cpu_card.push(cpu, "%.1f%%".printf(cpu));
                } else {
                    cpu_card.set_unavailable();
                }

                double memory = system_info.get_memory_usage();
                memory_card.push(memory, "%.1f%%".printf(memory));

                return Source.CONTINUE;
            });
        }
    }
}