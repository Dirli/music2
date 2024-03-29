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
    public class Core.Player : GLib.Object {
        public signal void changed_track (CObjects.Media m, bool run_track);
        public signal void changed_state ();
        public signal void changed_volume (double v);
        public signal void changed_duration (int64 d);
        public signal void changed_navigation (Enums.NavType t, bool can_nav);
        public signal void added_to_queue (CObjects.Media m);
        public signal void removed_from_queue (uint tid);
        public signal void tracklist_replaced (uint[] tracks_id);
        public signal void try_add (string uri);

        private Gee.HashMap<uint, CObjects.Media> tracks_hash;
        private Core.Queue tracks_queue;
        private GLib.Array<uint> tracks_list;

        public bool launch = false;

        private int _repeat_mode;
        public int repeat_mode {
            get {return _repeat_mode;}
            set {
                _repeat_mode = value;
                tracks_queue.repeat_mode = value;
            }
        }

        private bool _shuffle_mode;
        public bool shuffle_mode {
            get {
                return _shuffle_mode;
            }
            set {
                _shuffle_mode = value;
                tracks_queue.shuffle_mode = value;
                if (_current_index > 0) {
                    tracks_queue.reset_queue (tracks_list.data);
                    tracks_queue.set_index (_current_index);
                }
            }
        }

        private uint _current_index;
        public uint current_index {
            get {return _current_index;}
            set {
                _current_index = value;

                if (tracks_hash.has_key (value)) {
                    tracks_queue.set_index (value);
                    if (launch) {
                        set_track (value);
                    } else {
                        load_track (value, false);
                    }
                }
            }
        }

        private dynamic Gst.Element playbin;
        public dynamic Gst.Element audiobin;
        public dynamic Gst.Element audiosink;
        public dynamic Gst.Element eq_element;
        public dynamic Gst.Element audiosinkqueue;

        private Gst.Bus bus;
        private Gst.Format fmt = Gst.Format.TIME;
        public unowned int64 duration {
            get {
                int64 d = 0;
                playbin.query_duration (fmt, out d);
                return d;
            }
        }

        public unowned int64 position {
            set {
                playbin.seek_simple (fmt, Gst.SeekFlags.FLUSH, value);
            }
            get {
                int64 d = 0;
                playbin.query_position (fmt, out d);
                return d;
            }
        }

        public Player (Gst.Element? eq) {
            _current_index = 0;

            tracks_hash = new Gee.HashMap<uint, CObjects.Media> ();
            tracks_queue = new Core.Queue ();
            tracks_queue.notify["can-next"].connect (() => {
                changed_navigation (Enums.NavType.NEXT, tracks_queue.can_next);
            });
            tracks_queue.notify["can-prev"].connect (() => {
                changed_navigation (Enums.NavType.PREV, tracks_queue.can_prev);
            });
            tracks_list = new GLib.Array<uint> ();

            playbin = Gst.ElementFactory.make ("playbin", "play");


            if (eq != null) {
                audiosinkqueue = Gst.ElementFactory.make ("queue", null);
                audiosink = Gst.ElementFactory.make ("autoaudiosink", "auto_sink");
                audiobin = new Gst.Bin ("audiobin");

                if (audiobin != null && audiosinkqueue != null && audiosink != null) {
                    eq_element = eq;

                    ((Gst.Bin) audiobin).add_many (audiosinkqueue, eq_element, audiosink);
                    audiosinkqueue.link_many (audiosink);

                    var ghost_pad = new Gst.GhostPad ("sink", audiosinkqueue.get_static_pad ("sink"));
                    // ghost_pad.set_active (true);
                    audiobin.add_pad (ghost_pad);
                    playbin.set ("audio-sink", audiobin);
                }
            }

            bus = playbin.get_bus ();
            bus.add_watch (0, bus_callback);
            bus.enable_sync_message_emission ();
        }

        public bool get_nav_state (Enums.NavType n_type) {
            return n_type == Enums.NavType.NEXT ? tracks_queue.can_next : tracks_queue.can_prev;
        }

        public void enable_equalizer () {
            if (audiobin != null) {
                audiosinkqueue.unlink (audiosink);
                audiosinkqueue.link (eq_element);
                eq_element.link (audiosink);
            }
        }

        public void disable_equalizer () {
            if (audiobin != null) {
                audiosinkqueue.unlink (eq_element);
                eq_element.unlink (audiosink);
                audiosinkqueue.link (audiosink);
            }
        }

        private void state_changed (Gst.State state) {
            playbin.set_state (state);

            if (state == Gst.State.NULL) {
                return;
            }

            changed_state ();
        }

        public void toggle_playing () {
            var state = get_state ();
            if (state == Gst.State.PLAYING) {
                pause ();
            } else if (state == Gst.State.PAUSED || state == Gst.State.READY) {
                play ();
            }
        }

        public void play () {
            state_changed (Gst.State.PLAYING);
        }

        public void pause () {
            state_changed (Gst.State.PAUSED);
        }

        public void stop () {
            state_changed (Gst.State.READY);
        }

        public void next () {
            if (_current_index == 0) {
                return;
            }

            var proposed_index = tracks_queue.get_next_index ();
            if (set_track (proposed_index)) {
                _current_index = proposed_index;
            }
        }

        public void prev () {
            if (_current_index == 0) {
                return;
            }

            var proposed_index = tracks_queue.get_prev_index ();
            if (set_track (proposed_index)) {
                _current_index = proposed_index;
            }
        }

        private bool set_track (uint track_index) {
            if (track_index == 0 || !tracks_hash.has_key (track_index)) {
                return false;
            }

            load_track (track_index, true);
            play ();

            return true;
        }

        private void load_track (uint i, bool run, bool skip_reset = false) {
            var last_state = get_state ();

            if (!skip_reset) {
                state_changed (Gst.State.NULL);
                stop ();
            }

            playbin.uri = tracks_hash[i].uri;
            playbin.set_state (Gst.State.PLAYING);

            while (duration < 1) {};

            changed_duration (duration);

            if (last_state != Gst.State.PLAYING) {
                pause ();
            }

            changed_track (tracks_hash[i], run);
        }

        public void set_volume (double val) {
            if (0.0 <= val && val <= 100.0) {
                playbin.set_property ("volume", val);
                changed_volume (val);
            }
        }

        public double get_volume () {
            var val = GLib.Value (typeof (double));
            playbin.get_property ("volume", ref val);
            return (double) val;
        }

        public Gst.State get_state () {
            Gst.State state = Gst.State.NULL;
            Gst.State pending;
            playbin.get_state (out state, out pending, (Gst.ClockTime) (Gst.SECOND));
            return state;
        }

        public string get_state_str () {
            switch (get_state ()) {
                case Gst.State.PLAYING:
                    return "Playing";
                case Gst.State.PAUSED:
                    return "Paused";
                default:
                    return "Stopped";
            }
        }

        public bool add_to_queue (CObjects.Media m) {
            var tid = m.tid;
            if (tracks_hash.has_key (tid)) {
                return false;
            }

            tracks_hash[tid] = m;
            tracks_queue.add_index (tid, m.hits);
            tracks_list.append_val (tid);

            return true;
        }

        public uint[] get_queue () {
            return tracks_list.data;
        }

        public GLib.File[] get_uris_queue () {
            GLib.File[] files_arr = {};
            foreach (uint tid in tracks_list.data) {
                if (tracks_hash.has_key (tid)) {
                    files_arr += GLib.File.new_for_uri (tracks_hash[tid].uri);
                }
            }

            return files_arr;
        }

        public void remove_track (uint tid) {
            if (current_index == tid) {
                next ();
            }

            int t_index = 0;
            bool t_found = false;
            foreach (uint t in tracks_list.data) {
                if (t == tid) {
                    t_found = true;
                    break;
                }

                t_index++;
            }

            if (t_found) {
                tracks_list._remove_index (t_index);
            }

            if (tracks_queue.remove_index (tid)) {
                removed_from_queue (tid);
            }
        }

        private void reset_queue () {
            state_changed (Gst.State.NULL);
            tracks_queue.reset_queue (tracks_list.data);

            _current_index = tracks_queue.get_first ();

            stop ();

            if (tracks_hash.has_key (current_index)) {
                // playbin.uri = tracks_hash[current_index].uri;
                load_track (current_index, false, true);
            }
        }

        public void clear_queue () {
            uint[] zero_arr = {};
            tracklist_replaced (zero_arr);
            current_index = 0;

            state_changed (Gst.State.NULL);

            tracks_hash.clear ();
            tracks_queue.clear_queue (true);
            tracks_list = new GLib.Array<uint> ();
        }

        private bool bus_callback (Gst.Bus bus, Gst.Message message) {
            switch (message.type) {
                case Gst.MessageType.ERROR:
                    GLib.Error err;
                    string debug;
                    message.parse_error (out err, out debug);
                    warning ("Error: %s\n%s\n", err.message, debug);
                    if (tracks_queue.get_size () > 0) {
                        next ();
                    }
                    break;
                case Gst.MessageType.EOS:
                    if (tracks_queue.get_size () > 0 || repeat_mode == Enums.RepeatMode.ON) {
                        if (repeat_mode == Enums.RepeatMode.MEDIA) {
                            stop ();
                            play ();
                        } else {
                            next ();
                        }
                    } else {
                        reset_queue ();
                    }
                    break;
                default:
                    break;
            }

            return true;
        }

        public CObjects.Media? get_track (uint tid) {
            return tracks_hash.has_key (tid) ? tracks_hash[tid] : null;
        }
    }
}
