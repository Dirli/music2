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
    [DBus (name = "org.mpris.MediaPlayer2.Player")]
    public class Core.MprisPlayer : GLib.Object {
        public signal void seeked (int64 position);

        private Core.Player player;
        private GLib.DBusConnection conn;

        private bool _can_go_next;
        public bool can_go_next {
            get {return can_control && _can_go_next;}
        }
        private bool _can_go_previous;
        public bool can_go_previous {
            get {return can_control && _can_go_previous;}
        }
        public bool can_play {
            get {return can_control && true;}
        }
        public bool can_pause {
            get {return can_control && true;}
        }
        public bool can_seek {
            get {return can_control && true;}
        }
        public bool can_control {
            get {return true;}
        }

        private GLib.HashTable<string, GLib.Variant> _metadata;
        public GLib.HashTable<string, GLib.Variant>? metadata { //a{sv}
            owned get {
                return _metadata;
            }
        }

        public int64 position { // microseconds
            get {
                return (player.position / Constants.MILI_INV);
            }
        }

        // missing from the specification
        public int64 duration { // microseconds
            get {
                return player.duration / Constants.MILI_INV;
            }
        }

        public string playback_status {
            owned get {
                return player.get_state_str ();
            }
        }

        public double rate {
            get {return 1.0;}
            set {}
        }

        public double volume {
            get {
                return player.get_volume ();
            }
            set {
                if (value != player.get_volume ()) {
                    player.set_volume (value < 0 ? 0.0 : value);
                }
            }
        }

        public MprisPlayer (DBusConnection connection, Core.Player player) {
            this.player = player;

            _metadata = new GLib.HashTable<string, GLib.Variant> (str_hash, str_equal);

            _can_go_previous = this.player.get_nav_state (Enums.NavType.PREV);
            _can_go_next = this.player.get_nav_state (Enums.NavType.NEXT);

            conn = connection;

            this.player.changed_track.connect (on_changed_track);
            this.player.changed_state.connect (on_changed_state);
            this.player.changed_duration.connect (on_changed_duration);
            this.player.changed_volume.connect (on_changed_volume);
            this.player.changed_navigation.connect (on_changed_navigation);

            if (player.current_index > 0) {
                var m = player.get_track (player.current_index);
                if (m != null) {
                    on_changed_track (m, true);
                }
            }
        }

        public void next () throws GLib.Error {
            player.next ();
        }

        public void previous () throws GLib.Error {
            player.prev ();
        }

        public void pause () throws GLib.Error {
            if (player.get_state () == Gst.State.PLAYING) {
                player.pause ();
            }
        }

        public void play_pause () throws GLib.Error {
            player.toggle_playing ();
        }

        public void stop () throws GLib.Error {
            var state = player.get_state ();
            if (state == Gst.State.PLAYING || state == Gst.State.PAUSED) {
                player.stop ();
            }
        }

        public void play () throws GLib.Error {
            var state = player.get_state ();
            if (state == Gst.State.PAUSED || state == Gst.State.READY) {
                player.play ();
            }
        }

        public void seek (int64 offset) throws GLib.Error {
            int64 mod_position = player.position + offset * Constants.MILI_INV;

            if (mod_position < 0) {
                mod_position = 0;
            }

            if (mod_position < player.duration) {
                set_position (0, mod_position);
                seeked (mod_position);
            } else if (can_go_next) {
                next ();
            }
        }

        public void set_position (uint tid, int64 pos) throws GLib.Error {
            if (tid > 0) {
                player.launch = true;
                player.current_index = tid;
            }

            player.position = pos;
        }

        public void open_uri (string uri) throws GLib.Error {
            // TODO
        }

        // missing from the specification
        public int64 get_track_position () throws GLib.Error {
            return player.position / Constants.MILI_INV;
        }

        private void on_changed_state (string state) {
            if (player.get_state () == Gst.State.NULL) {
                _metadata.remove_all ();
            }
            send_properties ("PlaybackStatus", state);
        }

        private void on_changed_duration (int64 d) {
            if (d > 0) {
                send_properties ("Duration", (d / Constants.MILI_INV));
            }
        }

        private void on_changed_volume (double v) {
            send_properties ("Volume", v);
        }

        private void on_changed_navigation (Enums.NavType t, bool can_nav) {
            if (t == Enums.NavType.PREV) {
                _can_go_previous = can_nav;
                send_properties ("CanGoPrevious", can_nav);
            } else if (t == Enums.NavType.NEXT) {
                _can_go_next = can_nav;
                send_properties ("CanGoNext", can_nav);
            }

        }

        private void on_changed_track (CObjects.Media m, bool run_track) {
            _metadata = new HashTable<string, Variant> (null, null);

            _metadata.insert ("mpris:trackid",(int64) m.tid);
            _metadata.insert ("mpris:length", (int64) (player.duration / Constants.MILI_INV));

            string cov_name = m.year.to_string () + m.album;
            string cov_path = GLib.Path.build_path (GLib.Path.DIR_SEPARATOR_S,
                                                    GLib.Environment.get_user_cache_dir (),
                                                    Constants.APP_NAME,
                                                    "covers",
                                                    cov_name.hash ().to_string ());

            string icon_uri = "";
            if (GLib.FileUtils.test (cov_path, GLib.FileTest.EXISTS)) {
                var icon_file = GLib.File.new_for_path (cov_path);
                icon_uri = icon_file.get_uri ();
            }

            _metadata.insert ("mpris:artUrl", icon_uri);
            _metadata.insert ("xesam:trackNumber", (int32) m.track);
            _metadata.insert ("xesam:title", m.get_display_title ());
            _metadata.insert ("xesam:album", m.get_display_album ());
            _metadata.insert ("music2:year", (uint16) m.year);
            _metadata.insert ("xesam:artist", Tools.String.get_simple_string_array (m.get_display_artist ()));
            _metadata.insert ("xesam:genre", Tools.String.get_simple_string_array (m.get_display_genre ()));
            _metadata.insert ("xesam:url", m.uri);

            send_properties ("Metadata", _metadata);
        }

        private bool send_properties (string property, Variant val) {
            var property_list = new GLib.HashTable<string, GLib.Variant> (str_hash, str_equal);
            property_list.insert (property, val);

            var builder = new GLib.VariantBuilder (GLib.VariantType.ARRAY);
            var invalidated_builder = new GLib.VariantBuilder (new GLib.VariantType("as"));
            foreach (string name in property_list.get_keys ()) {
                GLib.Variant variant = property_list.lookup (name);
                builder.add ("{sv}", name, variant);
            }

            try {
                conn.emit_signal (null,
                                  "/org/mpris/MediaPlayer2",
                                  "org.freedesktop.DBus.Properties",
                                  "PropertiesChanged",
                                  new Variant ("(sa{sv}as)",
                                               "org.mpris.MediaPlayer2.Player",
                                               builder,
                                               invalidated_builder));

            } catch (Error e) {
                print ("Could not send MPRIS property change: %s\n", e.message);
            }

            return false;
        }
    }
}
