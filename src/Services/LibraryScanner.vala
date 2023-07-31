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
    public class Services.LibraryScanner : Interfaces.Scanner {
        public int64 start_time;
        public uint recorded_tracks;
        private string[] tracks_path;

        private Gee.HashMap<uint, int> artists_cache;
        private Gee.HashMap<uint, int> albums_cache;
        private Gee.HashMap<string, int> genres_cache;

        private Objects.LibraryTagger? lib_tagger;
        private Services.DataBaseManager? db_manager;

        public LibraryScanner () {
            db_manager = Services.DataBaseManager.get_instance ();
        }

        public override void start_scan (string uri) {
            if (db_manager == null) {
                return;
            }

            recorded_tracks = 0;
            stop_flag = false;

            artists_cache = new Gee.HashMap<uint, int> ();
            albums_cache = new Gee.HashMap<uint, int> ();

            genres_cache = new Gee.HashMap<string, int> ();

            var now_time = new GLib.DateTime.now ();
            start_time = now_time.to_unix ();

            scan_directory (uri);
            total_found (tracks_path.length);

            if (tracks_path.length > 0) {
                lib_tagger = new Objects.LibraryTagger ();
                lib_tagger.init ();

                foreach (string p in tracks_path) {
                    var t = lib_tagger.add_discover_uri (p);
                    if (t != null) {
                        add_track (t);
                    }

                    if (stop_flag) {
                        break;
                    }
                }
            }

            var t = new GLib.DateTime.now ();
            finished_scan (t.to_unix () - start_time);
        }

        private void scan_directory (string uri) {
            GLib.File directory = GLib.File.new_for_uri (uri.replace ("#", "%23"));

            try {
                var children = directory.enumerate_children (
                    "standard::*," + FileAttribute.STANDARD_CONTENT_TYPE + "," + FileAttribute.STANDARD_IS_HIDDEN + "," + FileAttribute.STANDARD_IS_SYMLINK + "," + FileAttribute.STANDARD_SYMLINK_TARGET,
                    GLib.FileQueryInfoFlags.NONE
                );
                GLib.FileInfo file_info = null;

                while ((file_info = children.next_file ()) != null) {
                    if (file_info.get_is_hidden ()) {
                        continue;
                    }

                    if (file_info.get_is_symlink ()) {
                        string target = file_info.get_symlink_target ();
                        var symlink = GLib.File.new_for_path (target);
                        var file_type = symlink.query_file_type (0);

                        if (file_type == GLib.FileType.DIRECTORY) {
                            scan_directory (target);
                        }

                    } else if (file_info.get_file_type () == GLib.FileType.DIRECTORY) {
                        scan_directory (directory.get_uri () + "/" + file_info.get_name ());
                    } else {
                        if (Tools.FileUtils.is_audio_file (file_info)) {
                            tracks_path += (directory.get_uri () + "/" + file_info.get_name ().replace ("#", "%23").replace ("%", "%25"));
                        }
                    }
                }

                children.close ();
                children.dispose ();
            } catch (Error err) {
                warning ("%s\n%s", err.message, uri);
            }

            directory.dispose ();
        }

        private void add_track (CObjects.Media m) {
            if (!genres_cache.has_key (m.genre)) {
                genres_cache[m.genre] = db_manager.insert_genre (m.genre);
            }
            int genre_id = genres_cache[m.genre];

            if (!artists_cache.has_key (m.artist.hash ())) {
                artists_cache[m.artist.hash ()] = db_manager.insert_artist (m.artist);
            }
            int art_id = artists_cache[m.artist.hash ()];

            var alb_hash = ("%u".printf (m.year) + m.album).hash ();
            if (!albums_cache.has_key (alb_hash)) {
                albums_cache[alb_hash] = db_manager.insert_album (m);
            }
            int alb_id = albums_cache[alb_hash];

            if (db_manager.insert_track (m, alb_id, art_id, genre_id)) {
                added_track (m, art_id, alb_id);
            }
        }
    }
}
