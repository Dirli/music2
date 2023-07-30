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
    public class Services.PlaylistManager : GLib.Object {
        public signal void cleared_playlist ();
        public signal bool add_view (uint tid);
        public signal void added_playlist (int pid, string name, Enums.Hint hint, GLib.Icon icon, GLib.Icon? activatable_icon = null);

        public int modified_pid = 0;

        private Gee.HashMap<int, string> playlists_hash;

        private Services.DataBaseManager? db_manager;

        public int auto_length {
            get; set;
        }

        public PlaylistManager () {
            db_manager = Services.DataBaseManager.get_instance ();

            playlists_hash = new Gee.HashMap<int, string> ();
        }

        public void load_playlists () {
            if (db_manager == null) {
                return;
            }

            playlists_hash = db_manager.get_playlists ();
            playlists_hash.foreach ((entry) => {
                added_playlist (entry.key, entry.value, Enums.Hint.PLAYLIST, new ThemedIcon ("playlist"));
                return true;
            });
        }

        public Gee.ArrayQueue<uint>? get_playlist (int pid) {
            if (db_manager != null) {
                return pid < 0 ?
                       db_manager.get_automatic_playlist (pid, auto_length) :
                       db_manager.get_playlist_tracks (pid);
            }

            return null;
        }

        public Gee.HashMap<int, string> get_available_playlists (uint tid) {
            var available_pl = new Gee.HashMap<int, string> ();

            if (db_manager != null) {
                db_manager.get_available_playlists (tid).foreach ((p_id) => {
                    if (playlists_hash.has_key (p_id)) {
                        available_pl[p_id] = playlists_hash[p_id];
                    }

                    return true;
                });

            }

            return available_pl;
        }

        public int create_playlist (string name) {
            if (db_manager != null) {
                int i = 1;
                string new_name = name;
                var names = playlists_hash.values;
                while (names.contains (new_name)) {
                    new_name = "%s %d".printf (name, i++);
                }

                var pid = db_manager.add_playlist (new_name);
                if (pid > 0 && !playlists_hash.has_key (pid)) {
                    playlists_hash[pid] = new_name;
                    added_playlist (pid, new_name, Enums.Hint.PLAYLIST, new ThemedIcon ("playlist"));

                    return pid;
                }
            }

            return -1;
        }

        public void select_playlist (int pid, Enums.Hint hint) {
            if (db_manager == null) {
                return;
            }

            Gee.ArrayQueue<uint> tids = null;
            if (hint == Enums.Hint.SMART_PLAYLIST) {
                tids = db_manager.get_automatic_playlist (pid, auto_length);
            } else if (playlists_hash.has_key (pid)) {
                tids = db_manager.get_playlist_tracks (pid);
            }

            if (tids != null) {
                tids.foreach ((tid) => {
                    add_view (tid);
                    return true;
                });
            }
        }

        public void add_to_playlist (int pid, uint tid) {
            if (db_manager == null || tid == 0 || !playlists_hash.has_key (pid)) {
                return;
            }

            db_manager.add_to_playlist (pid, tid);
        }

        public string edit_playlist (int pid, string name) {
            if (db_manager != null && playlists_hash.has_key (pid)) {
                var old_name = playlists_hash[pid];
                if (old_name != name) {
                    var new_name = name;
                    var i = 1;
                    var names = playlists_hash.values;
                    while (names.contains (new_name)) {
                        new_name = "%s %d".printf (name, i++);
                    }

                    if (db_manager.edit_playlist_name (pid, new_name)) {
                        playlists_hash[pid] = new_name;
                        return new_name == name ? "" : new_name;
                    }
                }
            }

            return "";
        }

        public void update_playlist (int pid, Gee.ArrayQueue<uint> tracks) {
            if (db_manager == null || !playlists_hash.has_key (pid)) {
                return;
            }

            db_manager.update_playlist (pid, tracks);
        }

        public void clear_playlist (int pid, bool active_playlist) {
            if (db_manager == null) {
                return;
            }

            if (db_manager.clear_playlist (pid) && active_playlist) {
                cleared_playlist ();
            }
        }

        public bool remove_playlist (int pid, bool active_playlist) {
            if (db_manager != null) {
                if (playlists_hash.has_key (pid) && db_manager.remove_playlist (pid)) {
                    playlists_hash.unset (pid);
                    if (active_playlist) {
                        cleared_playlist ();
                    }

                    return true;
                }
            }

            return false;
        }
    }
}
