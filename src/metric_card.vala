// SPDX-License-Identifier: GPL-3.0-or-later
namespace SystemMonitor {

    /** A titled card: name on the left, current value on the right, graph below. */
    public class MetricCard : Gtk.Box {
        private Gtk.Label value_label;
        private HistoryGraph graph;

        public MetricCard(string title, string color_css) {
            Object(orientation: Gtk.Orientation.VERTICAL, spacing: 8);

            var title_label = new Gtk.Label(title);
            title_label.halign = Gtk.Align.START;
            title_label.hexpand = true;
            title_label.opacity = 0.7;

            value_label = new Gtk.Label("calculating...");
            value_label.halign = Gtk.Align.END;

            var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
            header.append(title_label);
            header.append(value_label);

            graph = new HistoryGraph(color_css);

            append(header);
            append(graph);
        }

        /** Adds a sample to the graph and shows `text` as the current value. */
        public void push(double value, string text) {
            graph.push(value);
            value_label.set_markup(
                "<span size='x-large' weight='bold'>%s</span>".printf(
                    Markup.escape_text(text)));
        }

        /** No trustworthy value: say so instead of drawing a fake 0. */
        public void set_unavailable() {
            value_label.set_text("unavailable");
        }
    }
}