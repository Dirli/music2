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

    public bool save_current_playlist (string to_save) {
        string playlist_path = GLib.Path.build_path (GLib.Path.DIR_SEPARATOR_S,
                                                GLib.Environment.get_user_cache_dir (),
                                                Constants.APP_NAME,
                                                "cpl");

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

    public string get_m3u_content (CObjects.Media[] tracks) {
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

    public GLib.Array? get_playlist_m3u (string playlist_uri) {
        GLib.Array<string> tracks = new GLib.Array<string> ();

        var pl_file = GLib.File.new_for_uri (playlist_uri);
        if (!pl_file.query_exists ()) {
            warning ("The imported playlist doesn't exist!");
            return null;
        }

        try {
            string line;
            bool correct = false;
            var dis = new DataInputStream (pl_file.read ());
            while ((line = dis.read_line ()) != null) {
                if (!correct) {
                    if (line != "#EXTM3U") {
                        throw new IOError.INVALID_DATA ("The file does not meet the requirements");
                    } else {
                        correct = true;
                    }
                }

                if (line[0] != '#' && line.replace (" ", "").length > 0) {
                    tracks.append_val ("file://" + line.replace ("#", "%23").replace ("%", "%25"));
                }
            }
        } catch (Error e) {
            warning ("Could not load m3u file at %s: %s\n", pl_file.get_path (), e.message);
            return null;
        }

        return tracks;
    }

    public bool is_audio_file (string mime_type) {
        return mime_type.has_prefix ("audio/") && !mime_type.contains ("x-mpegurl") && !mime_type.contains ("x-scpls");
    }
}
