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
    public abstract class Interfaces.GSTagger : GLib.Object {
        public signal void discovered_new_item (CObjects.Media m);

        protected abstract CObjects.Media? create_media (Gst.PbUtils.DiscovererInfo info);
        protected Gst.PbUtils.Discoverer? discoverer;
        protected int total_scan;

        public bool launched = false;

        public void init () {
            try {
                total_scan = 0;
                discoverer = new Gst.PbUtils.Discoverer ((Gst.ClockTime) (5 * Gst.SECOND));
                discoverer.start ();
                discoverer.discovered.connect (discovered);
            } catch (Error e) {
                warning (e.message);
            }
        }

        public void stop_discovered () {
            discoverer.stop ();
            discoverer.discovered.disconnect (discovered);
            total_scan = 0;
        }

        private void discovered (Gst.PbUtils.DiscovererInfo info, Error? err) {
            ++total_scan;
            new Thread<void*> (null, () => {
                string uri = info.get_uri ();
                if (info.get_result () != Gst.PbUtils.DiscovererResult.OK) {
                    if (err != null) {
                        warning ("DISCOVER ERROR: '%d' %s %s\n(%s)", err.code, err.message, info.get_result ().to_string (), uri);
                    }
                } else {
                    var tags = info.get_tags ();
                    if (tags != null) {
                        var m = create_media (info);

                        discovered_new_item (m);
                    }
                }

                info.dispose ();
                return null;
            });
        }

        public void add_discover_uri (string uri) {
            if (!launched) {
                launched = true;
            }

            discoverer.discover_uri_async (uri);
        }
    }
}
