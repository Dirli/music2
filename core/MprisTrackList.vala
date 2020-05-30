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
    [DBus (name = "org.mpris.MediaPlayer2.TrackList")]
    public class Core.MprisTrackList : GLib.Object {
        public signal void track_list_replaced (uint[] tracks, uint current_track);
        public signal void track_added (GLib.HashTable<string, GLib.Variant> metadata, uint after_tid = 0);
        public signal void track_removed (uint track_id);

        private Core.Player player;

        public uint[] tracks {
            owned get {
                return player.get_queue ();
            }
        }

        public MprisTrackList (Core.Player p) {
            player = p;
            player.added_to_queue.connect (on_added_to_queue);
            player.tracklist_replaced.connect (on_tracklist_replaced);
            player.removed_from_queue.connect ((tid) => {
                track_removed (tid);
            });
        }

        // missing from the specification
        public uint[] get_tracklist () throws GLib.Error {
            return player.get_queue ();
        }

        public GLib.HashTable<string, GLib.Variant>[] get_tracks_metadata (uint[] tids) throws GLib.Error {
            GLib.HashTable<string, GLib.Variant>[] tracks_arr = {};
            foreach (var tid in tids) {
                var m = player.get_track (tid);
                if (m != null) {
                    var meta = media_to_metadata (m);
                    tracks_arr += meta;
                }
            }

            return tracks_arr;
        }

        public void add_track (string uri, uint after, bool current) throws GLib.Error {
            player.try_add (uri);
        }

        public void remove_track (uint tid) throws GLib.Error {
            if (tid > 0) {
                player.remove_track (tid);
            }
        }

        public void go_to (uint tid) throws GLib.Error {
            if (tid > 0) {
                player.launch = true;
                player.current_index = tid;
            }
        }

        private void on_added_to_queue (CObjects.Media m) {
            var meta = media_to_metadata (m);
            track_added (meta);
        }

        private void on_tracklist_replaced (uint[] tracks_id) {
            track_list_replaced (tracks_id, player.current_index);
        }

        private HashTable<string, Variant> media_to_metadata (CObjects.Media m) {
            var _metadata = new HashTable<string, Variant> (null, null);

            _metadata.insert ("mpris:trackid", (int64) m.tid);
            _metadata.insert ("mpris:length", (int64) m.length);
            _metadata.insert ("xesam:trackNumber", (int32) m.track);
            _metadata.insert ("music2:year", (uint16) m.year);
            _metadata.insert ("xesam:title", m.get_display_title ());
            _metadata.insert ("xesam:album", m.get_display_album ());
            _metadata.insert ("xesam:artist", Tools.String.get_simple_string_array (m.get_display_artist ()));
            _metadata.insert ("xesam:genre", Tools.String.get_simple_string_array (m.get_display_genre ()));
            _metadata.insert ("xesam:url", m.uri);

            return _metadata;
        }
    }
}
