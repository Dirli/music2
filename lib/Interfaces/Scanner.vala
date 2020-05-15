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
    public abstract class Interfaces.Scanner : GLib.Object {
        public abstract void start_scan (string uri);

        public signal void finished_scan (int64 scan_time = -1);
        public signal void added_track (CObjects.Media m, int artist_id, int album_id);
        public signal void total_found (uint total);

        protected bool stop_flag;

        public void stop_scan () {
            lock (stop_flag) {
                stop_flag = true;
            }
        }
    }
}
