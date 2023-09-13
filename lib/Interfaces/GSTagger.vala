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
    public abstract class Interfaces.GSTagger {
        public signal void discovered_new_item (CObjects.Media? m);

        protected abstract CObjects.Media? create_media (Gst.PbUtils.DiscovererInfo info);
        protected Gst.PbUtils.Discoverer? discoverer;

        protected bool stop_flag = false;

        public bool init () {
            try {
                discoverer = new Gst.PbUtils.Discoverer ((Gst.ClockTime) (5 * Gst.SECOND));

                return true;
            } catch (Error e) {
                warning (e.message);
            }

            return false;
        }

        public void stop_scan () {
            lock (stop_flag) {
                stop_flag = true;
            }
        }

        public CObjects.Media? add_discover_uri (string? uri) {
            // discoverer.discover_uri_async (uri);

            if (uri != null && uri != "") {
                try {
                    var info = discoverer.discover_uri (uri);
                    if (info.get_result () == Gst.PbUtils.DiscovererResult.OK) {
                        return create_media (info);
                    }
                } catch (Error e) {
                    warning ("DISCOVER ERROR: '%d' %s", e.code, e.message);
                }
            }

            return null;
        }
    }
}
