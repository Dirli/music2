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
    public class Core.Queue : GLib.Object {
        public int repeat_mode = 0;
        public bool shuffle_mode = false;

        public bool can_next {
            get; set;
        }

        public bool can_prev {
            get; set;
        }

        private Gee.ArrayList<uint> tracks_queue;
        private Gee.ArrayList<uint> past_tracks;
        private Gee.ArrayList<uint> hits_map;
        private Gee.HashMap<uint, uint> hits_hash;

        public Queue () {
            tracks_queue = new Gee.ArrayList<uint> ();
            past_tracks = new Gee.ArrayList<uint> ();
            hits_map = new Gee.ArrayList<uint> ();
            hits_hash = new Gee.HashMap<uint, uint> ();
        }

        public void add_index (uint i, uint h, bool past = false) {
            hits_hash[i] = h == 0 ? 1 : h > 10 ? 10 : h;

            if (!past) {
                if (!can_next) {
                    can_next = true;
                }

                fill_map (i);

                tracks_queue.add (i);
            } else {
                if (!can_prev) {
                    can_prev = true;
                }

                past_tracks.add (i);
            }
        }

        private bool fill_map (uint i) {
            if (!shuffle_mode) {
                return false;
            }

            hits_map.add (i);

            // if (!hits_hash.has_key (i)) {
            //     return true;
            // }

            var hits_value = hits_hash[i];

            var hits_count = 1;
            while (hits_count < hits_value) {
                hits_map.add (i);

                ++hits_count;
            }

            return true;
        }

        private void remove_i_map (uint i) {
            if (shuffle_mode) {
                int secure_counter = 0;
                while (hits_map.remove (i) && secure_counter < 10) {
                    ++secure_counter;
                }
            }
        }

        public bool remove_index (uint i) {
            if (tracks_queue.index_of (i) >= 0) {
                if (tracks_queue.remove (i)) {
                    remove_i_map (i);
                    hits_hash.unset (i);
                    return true;
                }
            } else if (past_tracks.index_of (i) >= 0) {
                if (past_tracks.remove (i)) {
                    hits_hash.unset (i);
                    return true;
                }
            }

            update_navigation ();
            return false;
        }

        public void set_index (uint i) {
            if (tracks_queue.size == 0 || i == tracks_queue[0]) {
                return;
            }

            var index = tracks_queue.index_of (i);
            if (index >= 0) {
                if (shuffle_mode) {
                    var random_val = tracks_queue.remove_at (index);
                    tracks_queue.insert (0, random_val);
                } else {
                    past_tracks.add_all (tracks_queue.slice (0, index));
                    tracks_queue = tracks_queue.slice (index, tracks_queue.size) as Gee.ArrayList<uint>;
                    if (repeat_mode == Enums.RepeatMode.ON) {
                        tracks_queue.add_all (past_tracks);
                        past_tracks.clear ();
                    }
                }
            } else {
                var past_index = past_tracks.index_of (i);
                if (past_index >= 0) {
                    var tmp_past = past_tracks.slice (past_index, past_tracks.size) as Gee.ArrayList<uint>;
                    for (var arr_i = tmp_past.size - 1 ; arr_i >= 0; arr_i--) {
                        tracks_queue.insert (0, tmp_past[arr_i]);
                        fill_map (arr_i);
                    }
                    if (past_index > 0) {
                        past_tracks = past_tracks.slice (0, past_index) as Gee.ArrayList<uint>;
                    } else {
                        past_tracks.clear ();
                    }
                }
            }

            update_navigation ();
        }

        public int get_size () {
            return tracks_queue.size - 1;
        }

        public uint get_first () {
            return tracks_queue.size == 0 ? 0 : tracks_queue.@get (0);
        }

        public uint get_next_index () {
            if (tracks_queue.size == 0 || !can_next) {
                return 0;
            }

            var i = tracks_queue.remove_at (0);
            past_tracks.add (i);
            remove_i_map (i);

            if (tracks_queue.size == 0 && repeat_mode == Enums.RepeatMode.ON) {
                tracks_queue.add_all (past_tracks);
                past_tracks.clear ();
            }

            if (shuffle_mode && tracks_queue.size > 1) {
                var random_val = get_random_tid ();
                if (random_val > 0) {
                    tracks_queue.insert (0, random_val);
                }
            }

            update_navigation ();
            // Yes, it's redundant, but I'll leave it at that.
            return tracks_queue.size == 0 ? 0 : tracks_queue.@get (0);
        }

        public uint get_prev_index () {
            if (past_tracks.size == 0 || !can_prev) {
                return 0;
            }

            var i = past_tracks.remove_at (past_tracks.size - 1);
            tracks_queue.insert (0, i);
            fill_map (i);

            update_navigation ();
            // Yes, it's redundant, but I'll leave it at that.
            return i;
        }

        private uint get_random_tid () {
            uint random_val = hits_map.@get (GLib.Random.int_range (0, hits_map.size));
            var tracks_index = tracks_queue.index_of (random_val);

            return tracks_index > 0 ? tracks_queue.remove_at (tracks_index) : 0;
        }

        public void reset_queue (uint[] tracks) {
            clear_queue (false);

            if (tracks.length > 0) {
                can_next = true;
            }

            foreach (var t in tracks) {
                tracks_queue.add (t);
            }

            hits_hash.keys.foreach (fill_map);
        }

        public void clear_queue (bool full) {
            past_tracks.clear ();
            tracks_queue.clear ();
            hits_map.clear ();

            if (full) {
                hits_hash.clear ();
            }

            update_navigation ();
        }

        private void update_navigation () {
            can_next = (tracks_queue.size > 1);
            can_prev = (past_tracks.size > 0);
        }
    }
}
