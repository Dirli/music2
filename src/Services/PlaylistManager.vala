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
        public signal bool selected_playlist (int pid, Enums.Hint hint);
        public signal void cleared_playlist ();
        public signal void add_view (uint tid, uint count);
        public signal int remove_view (uint tid);
        public signal void added_playlist (int pid, string name, Enums.Hint hint, GLib.Icon icon, GLib.Icon? activatable_icon = null);

        private int active_pid = -1;
        public int modified_pid = 0;

        private Gee.HashMap<int, Structs.Playlist?> playlists_hash;
        private Gee.HashMap<int, string> names_hash;

        public int auto_length {
            get; set;
        }

        public PlaylistManager () {
            names_hash = new Gee.HashMap<int, string> ();
            var db_manager = DataBaseManager.to_read ();
            if (db_manager != null) {
                playlists_hash = db_manager.get_playlists ();
            } else {
                playlists_hash = new Gee.HashMap<int, Structs.Playlist?> ();
            }
        }

        public int get_playlist_id (string name) {
            var db_manager = DataBaseManager.to_read ();
            return db_manager != null ? db_manager.get_playlist_id (name) : -1;
        }

        public Gee.HashMap<int, string> get_available_playlists (uint tid) {
            var available_hash = new Gee.HashMap<int, string> ();
            playlists_hash.values.foreach ((pl) => {
                if (!pl.tracks.contains (tid)) {
                    available_hash[pl.id] = names_hash[pl.id];
                }

                return true;
            });

            return available_hash;
        }

        public Gee.ArrayQueue<uint>? get_playlist (int pid) {
            if (pid < 0) {
                var db_manager = DataBaseManager.to_read ();
                if (db_manager != null) {
                    return db_manager.get_automatic_playlist (pid, auto_length);
                }
            } else if (playlists_hash.has_key (pid)) {
                if (pid == modified_pid) {
                    update_playlist (modified_pid, true);
                }

                return playlists_hash[pid].tracks;
            }

            return null;
        }

        public void load_playlists () {
            playlists_hash.foreach ((entry) => {
                var pl_name = entry.value.name;
                added_playlist (entry.key, pl_name, Enums.Hint.PLAYLIST, new ThemedIcon ("playlist"));
                names_hash[entry.key] = pl_name;
                return true;
            });
        }

        public void update_playlist_sync () {
            if (modified_pid > 0 && playlists_hash.has_key (modified_pid)) {
                uint[] arr_to_write = playlists_hash[modified_pid].tracks.to_array ();
                var db_manager = DataBaseManager.to_write ();
                if (db_manager != null) {
                    db_manager.update_playlist (modified_pid, arr_to_write, true);
                }
            }
        }

        private void update_playlist (int pid, bool clear = false) {
            if (playlists_hash.has_key (pid)) {
                new Thread<void*> ("update_playlist", () => {
                    uint[] arr_to_write = playlists_hash[pid].tracks.to_array ();
                    var db_manager = DataBaseManager.to_write ();
                    if (db_manager != null) {
                        db_manager.update_playlist (pid, arr_to_write, true);
                    }
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

            var names = names_hash.values;
            while (names.contains (new_name)) {
                new_name = "%s %d".printf (name, i++);
            }

            var db_manager = DataBaseManager.to_write ();
            if (db_manager == null) {
                return -1;
            }

            var pid = db_manager.add_playlist (new_name);
            if (pid > 0 && !playlists_hash.has_key (pid)) {
                Structs.Playlist pl = {};
                pl.name = new_name;
                pl.id = pid;
                pl.tracks = new Gee.ArrayQueue<uint> ();

                playlists_hash[pid] = pl;
                added_playlist (pid, new_name, Enums.Hint.PLAYLIST, new ThemedIcon ("playlist"));
                names_hash[pid] = new_name;

                return pid;
            }

            return -1;
        }

        public void clear_playlist (int pid) {
            new Thread<void*> ("clear_pl", () => {
                var db_manager = DataBaseManager.to_write ();
                if (db_manager != null) {
                    return null;
                }

                if (db_manager.clear_playlist (pid)) {
                    if (playlists_hash.has_key (pid)) {
                        playlists_hash[pid].tracks.clear ();

                        if (active_pid == pid) {
                            cleared_playlist ();
                        }
                    }
                }

                return null;
            });
        }

        public bool remove_playlist (int pid) {
            var db_manager = DataBaseManager.to_write ();
            if (db_manager != null) {
                return false;
            }

            if (playlists_hash.has_key (pid) && db_manager.remove_playlist (pid)) {
                names_hash.unset (pid);
                playlists_hash.unset (pid);
                return true;
            }

            return false;
        }

        public void add_to_playlist (int pid, uint tid) {
            if (tid == 0) {
                return;
            }

            if (playlists_hash.has_key (pid) && !playlists_hash[pid].tracks.contains (tid)) {
                if (modified_pid != 0 && modified_pid != pid) {
                    update_playlist (modified_pid);
                }

                modified_pid = pid;
                playlists_hash[pid].tracks.offer (tid);

                if (active_pid == pid) {
                    var total = playlists_hash[pid].tracks.size;
                    add_view (tid, total);
                }
            }
        }

        public string edit_playlist (int pid, string name) {
            if (playlists_hash.has_key (pid)) {
                var db_manager = DataBaseManager.to_read ();
                if (db_manager == null) {
                    return "";
                }

                var old_name = playlists_hash[pid].name;
                if (old_name != name) {
                    var new_name = name;
                    var i = 1;
                    var names = names_hash.values;
                    while (names.contains (new_name)) {
                        new_name = "%s %d".printf (name, i++);
                    }

                    if (db_manager.edit_playlist_name (pid, new_name)) {
                        names_hash[pid] = new_name;
                        playlists_hash[pid].name = new_name;
                        return new_name == name ? "" : new_name;
                    }
                }
            }

            return "";
        }

        public void remove_from_playlist (int pid, uint tid) {
            if (playlists_hash.has_key (pid) && playlists_hash[pid].tracks.contains (tid)) {
                playlists_hash[pid].tracks.remove (tid);

                new Thread<void*> ("remove_from_playlist", () => {
                    var db_manager = DataBaseManager.to_write ();
                    if (db_manager != null) {
                        db_manager.remove_from_playlist (pid, tid);
                    }
                    return null;
                });

                if (active_pid == pid) {
                    remove_view (tid);
                }
            }
        }

        public void select_playlist (int pid, Enums.Hint hint) {
            if (hint == Enums.Hint.SMART_PLAYLIST) {
                active_pid = pid;
                if (selected_playlist (pid, hint)) {
                    var t = new Thread<void*> ("select_auto_playlist", () => {
                        var db_manager = DataBaseManager.to_read ();
                        if (db_manager == null) {
                            return null;
                        }

                        var tids = db_manager.get_automatic_playlist (active_pid, auto_length);
                        if (tids != null) {
                            uint total = 0;
                            tids.foreach ((tid) => {
                                add_view (tid, ++total);
                                return true;
                            });
                        }

                        return null;
                    });

                    t.join ();
                }
            } else if (playlists_hash.has_key (pid)) {
                if (selected_playlist (pid, hint)) {
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
}
