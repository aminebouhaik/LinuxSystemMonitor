// SPDX-License-Identifier: GPL-3.0-or-later
namespace SystemMonitor {

    /**
     * A scrolling line graph of the most recent samples, drawn with Cairo
     * in a Gtk.DrawingArea. Samples arrive about once per second; drawing
     * runs every frame and interpolates, so the graph scrolls smoothly.
     */
    public class HistoryGraph : Gtk.DrawingArea {

        /** Value that maps to the top edge (100 for percentages). */
        public double max_value = 100.0;

        /** Expected time between push() calls; sets the scroll speed. */
        public int sample_interval_ms = 1000;

        private const double CORNER_RADIUS = 8.0;

        private RingBuffer history;
        private int visible_points;
        private int64 total_pushed = 0;
        private int64 last_push_time;
        private Gdk.RGBA line_color;

        public HistoryGraph(string color_css = "#3584e4", int visible_points = 60) {
            this.visible_points = visible_points;

            // +2: one point that just left the left edge and one about to
            // enter from the right. Without them the line would visibly
            // start or stop inside the graph while scrolling.
            history = new RingBuffer(visible_points + 2);
            last_push_time = GLib.get_monotonic_time();

            line_color = Gdk.RGBA();
            if (!line_color.parse(color_css)) {
                warning("Invalid graph colour: %s", color_css);
            }

            content_height = 110;
            hexpand = true;

            // Both callbacks are stored inside the widget itself. They use
            // their argument (area / widget) instead of `this`, so they do
            // not hold a strong reference back to the widget. A reference
            // cycle like that would keep the widget alive forever.
            set_draw_func((area, cr, width, height) => {
                ((HistoryGraph) area).draw_graph(cr, width, height);
            });

            add_tick_callback((widget, frame_clock) => {
                if (Gtk.Settings.get_default().gtk_enable_animations) {
                    widget.queue_draw();
                }
                return Source.CONTINUE;
            });
        }

        /** Adds a sample. Call about once per sample_interval_ms. */
        public void push(double value) {
            history.push(value);
            total_pushed++;
            last_push_time = GLib.get_monotonic_time();
            queue_draw();
        }

        /* 0.0 right after a sample arrived, 1.0 one interval later.
         * If the user turned animations off (accessibility), always 1.0:
         * the graph then steps once per sample instead of scrolling. */
        private double animation_progress() {
            if (!Gtk.Settings.get_default().gtk_enable_animations) {
                return 1.0;
            }
            double elapsed_ms = (GLib.get_monotonic_time() - last_push_time) / 1000.0;
            double progress = elapsed_ms / sample_interval_ms;
            if (progress < 0.0) {
                progress = 0.0;
            }
            if (progress > 1.0) {
                progress = 1.0;
            }
            return progress;
        }

        private double value_to_y(double value, double h) {
            double ratio = value / max_value;
            if (ratio < 0.0) {
                ratio = 0.0;
            }
            if (ratio > 1.0) {
                ratio = 1.0;
            }
            double top = 3.0;
            double bottom = h - 3.0;
            return bottom - ratio * (bottom - top);
        }

        private void trace_line(Cairo.Context cr, double x_newest, double step,
                                double h, int count) {
            for (int i = 0; i < count; i++) {
                double x = x_newest - (count - 1 - i) * step;
                double y = value_to_y(history[i], h);
                if (i == 0) {
                    cr.move_to(x, y);
                } else {
                    cr.line_to(x, y);
                }
            }
        }

        private static void rounded_rectangle(Cairo.Context cr, double x, double y,
                                              double w, double h, double r) {
            double degrees = Math.PI / 180.0;
            cr.new_sub_path();
            cr.arc(x + w - r, y + r,     r, -90 * degrees,   0 * degrees);
            cr.arc(x + w - r, y + h - r, r,   0 * degrees,  90 * degrees);
            cr.arc(x + r,     y + h - r, r,  90 * degrees, 180 * degrees);
            cr.arc(x + r,     y + r,     r, 180 * degrees, 270 * degrees);
            cr.close_path();
        }

        private void draw_graph(Cairo.Context cr, int width, int height) {
            double w = width;
            double h = height;

            // Theme text colour, so grid lines work in light and dark mode.
            Gdk.RGBA fg = get_style_context().get_color();

            int count = history.count;
            double step = w / (visible_points - 1);
            // Newest sample starts one step beyond the right edge and
            // slides in to the edge over one sample interval.
            double x_newest = w + (1.0 - animation_progress()) * step;

            // 1. Frame: tinted background; everything else is clipped to it.
            cr.save();
            rounded_rectangle(cr, 0.5, 0.5, w - 1.0, h - 1.0, CORNER_RADIUS);
            cr.set_source_rgba(fg.red, fg.green, fg.blue, 0.05);
            cr.fill_preserve();
            cr.clip();

            // 2. Horizontal grid lines at 25 %, 50 % and 75 %.
            cr.set_line_width(1.0);
            cr.set_source_rgba(fg.red, fg.green, fg.blue, 0.10);
            for (int k = 1; k < 4; k++) {
                double y = (int) (h * k / 4.0) + 0.5;
                cr.move_to(0, y);
                cr.line_to(w, y);
            }
            cr.stroke();

            // 3. Vertical grid lines, one per 10 samples. They are tied to
            //    sample numbers, so they scroll with the data and show the
            //    motion even when the line itself is flat.
            for (int i = 0; i < count; i++) {
                int64 sample_number = total_pushed - count + i;
                if (sample_number % 10 == 0) {
                    double x = x_newest - (count - 1 - i) * step;
                    cr.move_to(x, 0);
                    cr.line_to(x, h);
                }
            }
            cr.stroke();

            // 4. Data: translucent fill under the line, then the line.
            if (count >= 2) {
                double x_oldest = x_newest - (count - 1) * step;

                cr.new_path();
                trace_line(cr, x_newest, step, h, count);
                cr.line_to(x_newest, h);
                cr.line_to(x_oldest, h);
                cr.close_path();
                cr.set_source_rgba(line_color.red, line_color.green,
                                   line_color.blue, 0.25);
                cr.fill();

                cr.new_path();
                trace_line(cr, x_newest, step, h, count);
                cr.set_line_width(2.0);
                cr.set_line_join(Cairo.LineJoin.ROUND);
                cr.set_source_rgba(line_color.red, line_color.green,
                                   line_color.blue, 1.0);
                cr.stroke();
            }
            cr.restore();

            // 5. Border, drawn last and unclipped.
            rounded_rectangle(cr, 0.5, 0.5, w - 1.0, h - 1.0, CORNER_RADIUS);
            cr.set_line_width(1.0);
            cr.set_source_rgba(fg.red, fg.green, fg.blue, 0.15);
            cr.stroke();
        }
    }
}