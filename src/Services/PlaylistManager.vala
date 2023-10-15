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
        public signal void add_media (int pid);
        public signal void added_playlist (int pid, string name, Enums.Hint hint, GLib.Icon icon, GLib.Icon? activatable_icon = null);

        public int scan_pid = -1;

        public GLib.AsyncQueue<CObjects.Media> ext_tracks;

        private string ext_playlist_path;

        private Gee.HashMap<int, string> playlists_hash;
        private Gee.HashMap<int, string> ext_playlists_hash;

        private Services.DataBaseManager? db_manager;

        public int auto_length {
            get; set;
        }

        public PlaylistManager () {
            ext_tracks = new GLib.AsyncQueue<CObjects.Media> ();
            ext_playlist_path = Tools.FileUtils.get_cache_directory ("ext").get_path ();

            db_manager = Services.DataBaseManager.get_instance ();
            playlists_hash = db_manager != null 
                             ? db_manager.get_playlists ()
                             : new Gee.HashMap<int, string> ();

            ext_playlists_hash = new Gee.HashMap<int, string> (); 
        }
        
        public void load_playlists () {
            playlists_hash.foreach ((entry) => {
                added_playlist (entry.key, entry.value, Enums.Hint.PLAYLIST, new ThemedIcon ("playlist"));
                return true;
            });
            
            try {
                string name;
                int i = 0;
                GLib.Dir dir = GLib.Dir.open (ext_playlist_path, 0);
                while ((name = dir.read_name ()) != null) {
                    if (name.has_suffix (".m3u")) {
                        name = name.replace (".m3u", "");
                        ext_playlists_hash[i] = name;
                        added_playlist (i++, name, Enums.Hint.EXTERNAL_PLAYLIST, new ThemedIcon ("playlist"));
                    }
                }
            } catch (Error e) {
                warning (e.message);
            }
        }
        
        public CObjects.Media get_external_iter () {
            var m = ext_tracks.pop ();
            return m;
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
        
        public string get_playlist_path (int pid) {
            return ext_playlists_hash.has_key (pid)
            ? ext_playlist_path + "/" + ext_playlists_hash[pid] + ".m3u"
            : "";
        }
        
        public int create_external_playlist () {
            int i = 0;
            string new_name = "ext_playlist";
            var names = ext_playlists_hash.values;
            while (names.contains (new_name)) {
                new_name = "%s %d".printf (new_name, i++);
            }
            
            var new_pid = ext_playlists_hash.size;
            while (ext_playlists_hash.has_key (new_pid)) {
                ++new_pid;
            }
            
            ext_playlists_hash[new_pid] = new_name;
            
            return new_pid;
        }
        
        public int create_internal_playlist (string name) {
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

        public void select_int_playlist (int pid, Enums.Hint hint) {
            if (db_manager != null) {
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
        }
        
        public void select_ext_playlist (int pid) {
            if (!ext_playlists_hash.has_key (pid)) {
                return;
            }
            
            ext_tracks = null;
            ext_tracks = new GLib.AsyncQueue<CObjects.Media> ();
            
            var f = GLib.File.new_for_path (ext_playlist_path + "/" + ext_playlists_hash[pid] + ".m3u");
            
            var pl_content = Tools.FileUtils.get_playlist_m3u (f.get_uri ());
            if (pl_content == null) {
                return;
            }

            var uri_scanner = CObjects.UriScanner.init_scanner ();
            if (uri_scanner != null) {
                foreach (var t_uri in pl_content.split ("\n")) {
                    var m = uri_scanner.add_discover_uri (t_uri);
                    
                    if (scan_pid != pid) {
                        break;
                    }

                    if (m != null) {
                        ext_tracks.@lock ();
                        ext_tracks.push_unlocked (m);
                        ext_tracks.@unlock ();
                        
                        add_media (pid);
                    }
                }
            }
        }
        
        public void import_ext_playlist (string to_save) {
            var uri_scanner = CObjects.UriScanner.init_scanner ();
            if (uri_scanner == null) {
                return;
            }
            
            var pid = create_external_playlist ();

            //  scan_pid = pid;
            //  ext_tracks = null;
            //  ext_tracks = new GLib.AsyncQueue<CObjects.Media> ();
            
            CObjects.Media[] tracks = {};
            foreach (var t_uri in to_save.split ("\n")) {
                var m = uri_scanner.add_discover_uri (t_uri);
                if (m != null) {
                    tracks += m;
                    //  if (scan_pid != pid) {
                        //      ext_tracks.push (m);
                        //      add_media (pid);
                    //  }
                }
            }
            
            if (tracks.length != 0) {
                var p = get_playlist_path (pid);
                if (p != "" && Tools.FileUtils.save_playlist_m3u (p, tracks)) {
                    added_playlist (pid, ext_playlists_hash[pid], Enums.Hint.EXTERNAL_PLAYLIST, new ThemedIcon ("playlist"));
                }
            }
        }
        
        public void add_to_playlist (int pid, uint tid) {
            if (db_manager == null || tid == 0 || !playlists_hash.has_key (pid)) {
                return;
            }

            db_manager.add_to_playlist (pid, tid);
        }

        public string edit_playlist (int pid, string name, Enums.Hint hint) {
            if (hint == Enums.Hint.EXTERNAL_PLAYLIST) {
                if (ext_playlists_hash.has_key (pid)) {
                    var i = 1;
                    string new_name = name;
                    var names = ext_playlists_hash.values;
                    while (names.contains (new_name)) {
                        new_name = "%s %d".printf (new_name, i++);
                    }
                    var path = get_playlist_path (pid);
                    if (path != "" && GLib.FileUtils.rename (path, ext_playlist_path + "/" + new_name + ".m3u") == 0) {
                        ext_playlists_hash[pid] = new_name;
                        return "";
                    }

                    return ext_playlists_hash[pid];
                }
            } else {
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

        public bool remove_playlist (int pid, Enums.Hint hint, bool active_playlist) {
            if (hint == Enums.Hint.EXTERNAL_PLAYLIST) {
                if (ext_playlists_hash.has_key (pid)) {
                    var path  = get_playlist_path (pid);
                    if (path != "" && GLib.FileUtils.remove (path) == 0) {
                        ext_playlists_hash.unset (pid);
                        return true;
                    }
                }
            } else {
                if (db_manager != null) {
                    if (playlists_hash.has_key (pid) && db_manager.remove_playlist (pid)) {
                        playlists_hash.unset (pid);
                        if (active_playlist) {
                            cleared_playlist ();
                        }
                        
                        return true;
                    }
                }
            }

            return false;
        }
    }
}
