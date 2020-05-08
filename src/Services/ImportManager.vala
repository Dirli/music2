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
    public class Services.ImportManager : Interfaces.Scanner {
        private DataBaseManager db_manager;

        private string base_folder;

        private Structs.ImportFile[] import_files;
        private Gee.HashMap<string, int> artists_exist;
        private Gee.HashMap<uint, int> albums_exist;
        private Gee.HashMap<uint, Gee.ArrayList<int>> apa_cache;

        public Gee.HashMap<uint, Structs.Album?> added_albums;
        public Gee.HashMap<string, int> added_artists;
        public Gee.ArrayList<CObjects.Media> added_tracks;

        public ImportManager (string music_folder) {
            base_folder = music_folder;
            added_albums = new Gee.HashMap<uint, Structs.Album?> ();
            added_artists = new Gee.HashMap<string, int> ();
            added_tracks = new Gee.ArrayList<CObjects.Media?> ();
            apa_cache = new Gee.HashMap<uint, Gee.ArrayList<int>> ();

            import_files = {};
        }

        public override void start_scan (string import_uri) {
            stop_flag = false;
            var start_time = new GLib.DateTime.now ();

            scan_import_folder (import_uri);

            if (import_files.length > 0) {
                total_found (import_files.length);
                db_manager = new DataBaseManager ();

                artists_exist = db_manager.get_artists_rev ();
                albums_exist = db_manager.get_albums_rev ();

                var lib_tagger = new Objects.LibraryTagger ();
                lib_tagger.init ();

                foreach (unowned Structs.ImportFile import_f in import_files) {
                    var copy_file = GLib.File.new_for_uri (import_f.uri);
                    var dest_file = GLib.File.new_for_path (base_folder + import_f.parents + "/" + copy_file.get_basename ());

                    if (!copy_media (copy_file, dest_file)) {
                        continue;
                    }

                    var m = lib_tagger.add_discover_uri (dest_file.get_uri ());
                    if (m == null) {
                        continue;
                    }

                    int art_id = artists_exist.has_key (m.artist) ? artists_exist[m.artist] : added_artists.has_key (m.artist) ? added_artists[m.artist] : 0;
                    if (art_id == 0) {
                        art_id = db_manager.insert_artist (m.artist);
                        added_artists[m.artist] = art_id;
                    }

                    var alb_hash = (m.year.to_string () + m.get_display_album ()).hash ();
                    int alb_id = albums_exist.has_key (alb_hash) ? albums_exist[alb_hash] : added_albums.has_key (alb_hash) ? added_albums[alb_hash].album_id : 0;
                    if (alb_id == 0) {
                        alb_id = db_manager.insert_album (m);
                        added_albums[alb_hash] = get_album_struct (m, alb_id);
                    } else {
                        if (albums_exist.has_key (alb_hash) && !added_albums.has_key (alb_hash)) {
                            added_albums[alb_hash] = get_album_struct (m, albums_exist[alb_hash]);
                        }
                    }

                    if (apa_cache.has_key (alb_hash) || !apa_cache[alb_hash].contains (art_id)) {
                        db_manager.insert_artist_per_album (art_id, alb_id);
                        apa_cache[alb_hash].add (art_id);
                    }

                    added_tracks.add (db_manager.insert_track (m, alb_id, art_id));
                    added_track ();
                    if (stop_flag) {
                        break;
                    }
                }
            }

            var finish_time = new GLib.DateTime.now ();
            finished_scan (finish_time.to_unix () - start_time.to_unix ());
        }

        private Structs.Album get_album_struct (CObjects.Media m, int album_id) {
            Structs.Album album_struct = {};

            album_struct.album_id = album_id;
            album_struct.title = m.album;
            album_struct.artists_id = "";
            album_struct.artists = "...";
            album_struct.year = m.year;
            album_struct.genre = m.genre;

            return album_struct;
        }

        private bool copy_media (GLib.File target_file, GLib.File dest_file) {
            try {
                var parent = dest_file.get_parent ();
                if (parent == null) {
                    return false;
                }

                if (!parent.query_exists ()) {
                    parent.make_directory_with_parents (null);
                }

                target_file.copy (dest_file, GLib.FileCopyFlags.NONE, null, null);
            } catch (GLib.Error e) {
                if (e.code != GLib.IOError.EXISTS) {
                    warning (e.message);
                }
                return false;
            }

            return true;
        }

        private void scan_import_folder (string uri, owned string parent_path = "") {
            GLib.File directory = GLib.File.new_for_uri (uri.replace ("#", "%23"));

            try {
                parent_path += "/" + directory.get_basename ();

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

                        if (symlink.query_file_type (0) == GLib.FileType.DIRECTORY) {
                            scan_import_folder (target, parent_path);
                        }

                        continue;
                    }

                    if (file_info.get_file_type () == GLib.FileType.DIRECTORY) {
                        scan_import_folder (directory.get_uri () + "/" + file_info.get_name (), parent_path);
                        continue;
                    }

                    string mime_type = file_info.get_content_type ();
                    if (Tools.FileUtils.is_audio_file (mime_type)) {
                        Structs.ImportFile i = {};
                        i.parents = parent_path;
                        i.uri = directory.get_uri () + "/" + file_info.get_name ().replace ("#", "%23").replace ("%", "%25");

                        import_files += i;
                    }
                }

                children.close ();
                children.dispose ();
            } catch (Error err) {
                warning ("%s\n%s", err.message, uri);
            }

            directory.dispose ();
        }
    }
}
