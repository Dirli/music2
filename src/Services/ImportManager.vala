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
        private string base_folder;

        private Structs.ImportFile[] import_files;

        public ImportManager (string music_folder) {
            base_folder = music_folder;

            import_files = {};
        }

        public override void start_scan (string import_uri) {
            stop_flag = false;
            var start_time = new GLib.DateTime.now ();

            scan_import_folder (import_uri);

            if (import_files.length > 0) {
                var db_manager = Services.DataBaseManager.get_instance ();
                if (db_manager == null) {
                    var finish_time = new GLib.DateTime.now ();
                    finished_scan (finish_time.to_unix () - start_time.to_unix ());
                    return;
                }

                total_found (import_files.length);

                var artists_cache = new Gee.HashMap<string, int> ();
                var genres_cache = new Gee.HashMap<string, int> ();
                var albums_cache = new Gee.HashMap<uint, int> ();

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

                    if (!genres_cache.has_key (m.genre)) {
                        genres_cache[m.genre] = db_manager.insert_genre (m.genre);
                    }
                    var genre_id = genres_cache[m.genre];

                    if (!artists_cache.has_key (m.artist)) {
                        artists_cache[m.artist] = db_manager.insert_artist (m.artist);
                    }
                    var art_id = artists_cache[m.artist];

                    var alb_hash = ("%u".printf (m.year) + m.get_display_album ()).hash ();
                    if (!albums_cache.has_key (alb_hash)) {
                        albums_cache[alb_hash] = db_manager.insert_album (m);
                    }
                    var alb_id = albums_cache[alb_hash];

                    if (db_manager.insert_track (m, alb_id, art_id, genre_id)) {
                        added_track (m, art_id, alb_id);
                    }

                    if (stop_flag) {
                        break;
                    }
                }
            }

            var finish_time = new GLib.DateTime.now ();
            finished_scan (finish_time.to_unix () - start_time.to_unix ());
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

                    if (Tools.FileUtils.is_audio_file (file_info)) {
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
