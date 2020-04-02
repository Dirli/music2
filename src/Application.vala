/*
 * Copyright (c) 2020 Dirli <litandrej85@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

namespace Music2 {
    public class App : Gtk.Application {
        private MainWindow main_window;

        construct {
            // flags |= ApplicationFlags.HANDLES_OPEN;
            application_id = Constants.APP_NAME;
        }

        public override void open (GLib.File[] files, string hint) {

        }

        protected override void activate () {
            if (main_window == null) {
                main_window = new MainWindow (this);
            }

            main_window.present ();
        }
    }
}

public static int main (string[] args) {
    try {
        Gst.init_check (ref args);
    } catch (Error err) {
        error ("Could not init GStreamer: %s", err.message);
    }

    var app = new Music2.App ();
    return app.run (args);
}
