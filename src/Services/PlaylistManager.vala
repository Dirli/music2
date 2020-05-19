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
        public signal void selected_playlist (int pid, Enums.Hint hint, Enums.SourceType type);
        public signal void add_view (uint tid, uint count);
        public signal int remove_view (uint tid);
        public signal void added_playlist (int pid, string name, Enums.Hint hint, GLib.Icon icon);

        private int active_pid = -1;
        public int modified_pid = 0;

        private DataBaseManager db_manager;

        private Gee.HashMap<int, Structs.Playlist?> playlists_hash;
        private Gee.ArrayList<string> names_list;

        public PlaylistManager () {
            db_manager = new DataBaseManager ();
            names_list = new Gee.ArrayList<string> ();
            playlists_hash = db_manager.get_playlists ();
        }

        public int get_playlist_id (string name) {
            return db_manager.get_playlist_id (name);
        }

        public Gee.ArrayList<uint>? get_playlist (int pid) {
            if (playlists_hash.has_key (pid)) {
                return playlists_hash[pid].tracks;
            }

            return null;
        }

        public void load_playlists () {
            playlists_hash.foreach ((entry) => {
                var pl_name = entry.value.name;
                added_playlist (entry.key, pl_name, Enums.Hint.PLAYLIST, new ThemedIcon ("playlist"));
                names_list.add (pl_name);
                return true;
            });
        }

        public void update_playlist_sync () {
            if (modified_pid > 0 && playlists_hash.has_key (modified_pid)) {
                uint[] arr_to_write = playlists_hash[modified_pid].tracks.to_array ();
                db_manager.update_playlist (modified_pid, arr_to_write);
            }
        }

        public void update_playlist (int pid, bool clear = false) {
            if (playlists_hash.has_key (pid)) {
                new Thread<void*> ("update_playlist", () => {
                    uint[] arr_to_write = playlists_hash[pid].tracks.to_array ();
                    db_manager.update_playlist (pid, arr_to_write);
                    if (clear) {
                        modified_pid = 0;
                    }
                    return null;
                });
            }
        }

        public int create_playlist (string name) {
            int i = 1;
            string new_name = name;

            while (names_list.contains (new_name)) {
                new_name = "%s %d".printf (name, i++);
            }

            var pid = db_manager.add_playlist (new_name);

            if (pid > 0 && !playlists_hash.has_key (pid)) {
                Structs.Playlist pl = {};
                pl.type = Enums.SourceType.PLAYLIST;
                pl.name = new_name;
                pl.id = pid;
                pl.tracks = new Gee.ArrayList<uint> ();

                playlists_hash[pid] = pl;
                added_playlist (pid, new_name, Enums.Hint.PLAYLIST, new ThemedIcon ("playlist"));
                if (!names_list.contains (new_name)) {
                    names_list.add (new_name);
                }

                return pid;
            }

            return -1;
        }

        public bool remove_playlist (int pid) {
            if (playlists_hash.has_key (pid) && db_manager.remove_playlist (pid)) {
                names_list.remove (playlists_hash[pid].name);
                playlists_hash.unset (pid);
                return true;
            }

            return false;
        }

        public void add_to_playlist (int pid, uint tid) {
            if (playlists_hash.has_key (pid) && !playlists_hash[pid].tracks.contains (tid)) {
                if (modified_pid != 0 && modified_pid != pid) {
                    update_playlist (modified_pid);
                }

                modified_pid = pid;
                playlists_hash[pid].tracks.add (tid);
                if (active_pid == pid) {
                    var total = playlists_hash[pid].tracks.size;
                    add_view (tid, total);
                }
            }
        }

        public string edit_playlist (int pid, string name) {
            if (playlists_hash.has_key (pid)) {
                var old_name = playlists_hash[pid].name;
                if (old_name != name) {
                    var new_name = name;
                    var i = 1;
                    while (names_list.contains (new_name)) {
                        new_name = "%s %d".printf (name, i++);
                    }

                    if (db_manager.edit_playlist_name (pid, new_name)) {
                        names_list.remove (old_name);
                        names_list.add (new_name);
                        return new_name == name ? "" : new_name;
                    }
                }
            }

            return "";
        }

        public void remove_from_playlist (int pid, uint tid) {
            if (playlists_hash.has_key (pid) && playlists_hash[pid].tracks.contains (tid)) {
                playlists_hash[pid].tracks.remove (tid);

                new Thread<void*> ("remove_from _playlist", () => {
                    db_manager.remove_from_playlist (pid, tid);
                    return null;
                });

                if (active_pid == pid) {
                    remove_view (tid);
                }
            }
        }

        public void select_playlist (int pid, Enums.Hint hint) {
            if (playlists_hash.has_key (pid)) {
                var type = playlists_hash[pid].type;

                selected_playlist (pid, hint, type);

                if (pid != active_pid) {
                    active_pid = pid;
                    uint total = 0;
                    playlists_hash[pid].tracks.foreach ((t) => {
                        add_view (t, ++total);
                        return true;
                    });
                }
            }
        }
    }
}
