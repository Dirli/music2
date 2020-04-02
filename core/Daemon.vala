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
    public class Core.Daemon : GLib.Application {
        private static Daemon? instance = null;
        private Core.Server player_server = null;

        public static unowned Daemon get_instance () {
            if (instance == null) {
                instance = new Daemon ();
            }

            return instance;
        }

        private Daemon () {}

        construct {
            flags |= ApplicationFlags.HANDLES_OPEN;
            application_id = "io.elementary.music2d";
        }

        public override void activate () {
            if (player_server == null) {
                player_server = new Core.Server (this);
                hold ();
            }
        }

        public override void open (GLib.File[] files, string hint) {
            activate ();
            player_server.open_files (files);
        }

        public static void on_exit (int signum) {
            GLib.Application.get_default ().release ();
        }
    }
}

public static int main (string [] args) {
    Gst.init (ref args);
    GLib.Process.signal (GLib.ProcessSignal.INT, Music2.Core.Daemon.on_exit);
    GLib.Process.signal (GLib.ProcessSignal.TERM, Music2.Core.Daemon.on_exit);
    return Music2.Core.Daemon.get_instance ().run (args);
}
