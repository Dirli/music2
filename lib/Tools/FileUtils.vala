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

namespace Music2.Tools.FileUtils {
    public string get_tmp_path () {
        return GLib.Path.build_path (GLib.Path.DIR_SEPARATOR_S,
                                     GLib.Environment.get_tmp_dir (),
                                     Constants.APP_NAME,
                                     "cpl");
    }

    public GLib.File get_tmp_directory () {
        string dir_path = GLib.Path.build_path (GLib.Path.DIR_SEPARATOR_S,
                                                GLib.Environment.get_tmp_dir (),
                                                Constants.APP_NAME);

        var cache_dir = GLib.File.new_for_path (dir_path);

        if (!GLib.FileUtils.test (dir_path, GLib.FileTest.IS_DIR)) {
            try {
                cache_dir.make_directory_with_parents (null);
            } catch (Error e) {
                warning (e.message);
            }
        }

        return cache_dir;
    }

    public GLib.File get_cache_directory (string child_dir = "") {
        string dir_path = GLib.Path.build_path (GLib.Path.DIR_SEPARATOR_S,
                                                GLib.Environment.get_user_cache_dir (),
                                                Constants.APP_NAME,
                                                child_dir);

        var cache_dir = GLib.File.new_for_path (dir_path);

        if (!GLib.FileUtils.test (dir_path, GLib.FileTest.IS_DIR)) {
            try {
                cache_dir.make_directory_with_parents (null);
            } catch (Error e) {
                warning (e.message);
            }
        }

        return cache_dir;
    }

    public string[] get_audio_files (GLib.File d) {
        string[] total_files = {};
        var dir_path = d.get_path ();
        if (dir_path == null) {
            return total_files;
        }

        GLib.List<string> uris_list = new GLib.List<string> ();
        try {
            string name;
            GLib.Dir dir = GLib.Dir.open (dir_path, 0);
            while ((name = dir.read_name ()) != null) {
                if (name != "") {
                    uris_list.append (name);
                }
            }
        } catch (GLib.FileError err) {
            warning (err.message);
        }

        uris_list.sort ((a, b) => {
            return GLib.strcmp (a, b);
        });
        
        uris_list.foreach ((entry) => {
            try {
                var f = GLib.File.new_for_path (dir_path + "/" + entry);
                var file_info = f.query_info ("standard::*," + GLib.FileAttribute.STANDARD_CONTENT_TYPE, GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                
                if (!file_info.get_is_hidden ()
                 && !file_info.get_is_symlink ()
                 && file_info.get_file_type () != FileType.DIRECTORY
                 && is_audio_file (file_info)) {
                    total_files += f.get_uri ();
                }
            } catch (Error err) {
                warning ("%s\n%s", err.message, d.get_uri ());
            }
        });

        return total_files;
    }

    public string get_cover_path (uint year, string album_name) {
        string cov_name = year.to_string () + album_name;
        string cov_path = GLib.Path.build_path (GLib.Path.DIR_SEPARATOR_S,
            GLib.Environment.get_user_cache_dir (),
            Constants.APP_NAME,
            "covers",
                                                cov_name.hash ().to_string ());
                                                
        return GLib.FileUtils.test (cov_path, GLib.FileTest.EXISTS) ? cov_path : "";
    }

    public bool save_cover_file (GLib.File file, uint year, string album_name) {
        string cov_name = year.to_string () + album_name;
        
        var dest = get_cache_directory ("covers").get_child (cov_name.hash ().to_string ());
        
        try {
            file.copy (dest, GLib.FileCopyFlags.OVERWRITE);
            return true;
        } catch (Error e) {
            warning (e.message);
        }

        return false;
    }
    
    public bool save_playlist (string to_save, string playlist_path) {
        if (to_save != "") {
            var playlist_file = GLib.File.new_for_path (playlist_path);
            try {
                if (playlist_file.query_exists ()) {
                    playlist_file.delete ();
                }
                
                var file_stream = playlist_file.create (GLib.FileCreateFlags.PRIVATE);
                
                var data_stream = new GLib.DataOutputStream (file_stream);
                data_stream.put_string (to_save);
                
                return true;
            } catch (Error e) {
                warning (e.message);
            }
        }
        
        return false;
    }

    public bool save_playlist_m3u (string playlist_path, CObjects.Media[] tracks) {
        string to_save = get_m3u_content (tracks);
        GLib.File dest = GLib.File.new_for_path (playlist_path);
        
        try {
            if (dest.query_exists ()) {
                dest.delete ();
            }

            var file_stream = dest.create (GLib.FileCreateFlags.REPLACE_DESTINATION);
            var data_stream = new GLib.DataOutputStream (file_stream);
            data_stream.put_string (to_save);

            return true;
        } catch (Error e) {
            warning ("Could not save playlist %s to m3u file %s: %s\n", playlist_path, dest.get_path (), e.message);
        }

        return false;
    }
    
    private string get_m3u_content (CObjects.Media[] tracks) {
        string to_save = "#EXTM3U";
        
        foreach (unowned CObjects.Media t in tracks) {
            if (t == null) {
                continue;
            }
            
            var sec = Tools.TimeUtils.mili_to_sec (t.length).to_string ();
            
            to_save += "\n\n#EXTINF:" + sec + ", " + t.get_display_artist () + " - " + t.get_display_title ();
            to_save += "\n" + GLib.File.new_for_uri (t.uri).get_path ();
        }

        return to_save;
    }
    
    public string? get_playlist_m3u (string playlist_uri) {
        string tracks = "";

        var pl_file = GLib.File.new_for_uri (playlist_uri);
        if (!pl_file.query_exists ()) {
            warning ("The imported playlist doesn't exist!");
            return null;
        }

        try {
            string line;
            bool correct = false;
            var dis = new GLib.DataInputStream (pl_file.read ());
            while ((line = dis.read_line ()) != null) {
                if (!correct) {
                    if (line != "#EXTM3U") {
                        throw new IOError.INVALID_DATA ("The file does not meet the requirements");
                    } else {
                        correct = true;
                    }
                }

                if (!line.has_prefix ("http")) {
                    if (line[0] != '#' && line.replace (" ", "").length > 0) {
                        var f = GLib.File.new_for_path (line);
                        if (f.query_exists ()) {
                            tracks += @"$(f.get_uri ())\n";
                        }
                    }
                }

            }
        } catch (Error e) {
            warning ("Could not load m3u file at %s: %s\n", pl_file.get_path (), e.message);
            return null;
        }
        
        return tracks;
    }

    public string source_to_str (string[] uris) {
        var path_file = GLib.File.new_for_uri (uris[0].replace ("#", "%23"));
        var file_type = path_file.query_file_type (GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
        
        var tracks_str = "";
        if (file_type == GLib.FileType.DIRECTORY) {
            foreach (var s in get_audio_files (path_file)) {
                tracks_str += @"$(s)\n";
            }
        } else if (file_type == GLib.FileType.REGULAR) {
            var file_name = path_file.get_basename ();
            if (file_name != null) {
                if (file_name.has_suffix (".m3u")) {
                    var str = get_playlist_m3u (uris[0]);
                    if (str != null) {
                        tracks_str = str;
                    }
                } else {
                    try {
                        foreach (var u in uris) {
                            var f = GLib.File.new_for_uri (u);
                            if (f.query_exists () && is_audio_file (f.query_info ("standard::*," + GLib.FileAttribute.STANDARD_CONTENT_TYPE, GLib.FileQueryInfoFlags.NONE))) {
                                tracks_str += @"$(u)\n";
                            }
                        }

                    } catch (Error e) {
                        warning (e.message);
                    }
                }
            }
        }
        
        return tracks_str;
    }
    
    public string files_to_str (GLib.File[] files) {
        var uris = "";
        foreach (GLib.File f in files) {
            try {
                if (!f.query_exists () || !is_audio_file (f.query_info ("standard::*," + GLib.FileAttribute.STANDARD_CONTENT_TYPE, GLib.FileQueryInfoFlags.NONE))) {
                    continue;
                }

                uris += f.get_uri ();
                uris += "\n";
            } catch (Error e) {
                warning (e.message);
            }
        }

        return uris;
    }

    public bool is_audio_file (GLib.FileInfo f_info) {
        string mime_type = f_info.get_content_type ();
        
        return mime_type != null
               ? mime_type.has_prefix ("audio/") && !mime_type.contains ("x-mpegurl") && !mime_type.contains ("x-scpls")
               : false;
    }
}
