// SPDX-License-Identifier: GPL-3.0-or-later
namespace SystemMonitor {
    public class Application : Gtk.Application {

        public Application() {
            Object(
                application_id: "io.github.aminebouhaik.SystemMonitor",
                flags: ApplicationFlags.DEFAULT_FLAGS
            );
        }

        protected override void activate() {
            var window = new MainWindow(this);
            window.present();
        }
    }
}