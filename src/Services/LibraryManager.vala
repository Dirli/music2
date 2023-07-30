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
    public class Services.LibraryManager : GLib.Object {
        public signal void library_loaded ();
        public signal void added_category (Enums.Category category, Gtk.ListStore store);
        public signal void finished_scan (string msg);
        public signal void prepare_scan ();
        public signal void progress_scan (double progress_val);

        private uint source_id = 0;
        private uint scan_m = 0;
        private uint total_m = 0;

        public bool library_not_empty {
            get {
                return media_hash.size > 0 || artists_hash.size > 0 || albums_hash.size > 0;
            }
        }

        public bool scans {
            get {
                return scanner != null;
            }
        }

        private Services.DataBaseManager? db_manager = null;

        public Gee.HashMap<uint, CObjects.Media> media_hash;
        public Gee.HashMap<int, Structs.Album?> albums_hash;
        public Gee.HashMap<int, string> artists_hash;
        public Gee.HashMap<int, string> genres_hash;

        private Interfaces.Scanner scanner = null;

        public LibraryManager () {
            Tools.FileUtils.get_cache_directory ("covers");
        }

        construct {
            db_manager = Services.DataBaseManager.get_instance ();

            media_hash = new Gee.HashMap<uint, CObjects.Media> ();
            artists_hash = new Gee.HashMap<int, string> ();
            genres_hash = new Gee.HashMap<int, string> ();
            albums_hash = new Gee.HashMap<int, Structs.Album?> ();
        }

        public Gee.Collection<CObjects.Media> get_track_list () {
            return media_hash.values;
        }
        public Gee.Collection<Structs.Album?> get_albums () {
            return albums_hash.values;
        }

        public bool in_library (uint tid) {
            return media_hash.has_key (tid);
        }

        public Gee.ArrayList<int>? get_filtered_category (Enums.Category c, Enums.Category f, int id) {
            if (db_manager != null) {
                if (c == Enums.Category.ARTIST) {
                    return db_manager.get_artists_id (id);
                } else if (c == Enums.Category.ALBUM) {
                    if (f == Enums.Category.GENRE) {
                        return db_manager.get_albums_id ("genre_id", id);
                    } else if (f == Enums.Category.ARTIST) {
                        return db_manager.get_albums_id ("artist_id", id);
                    }
                }
            }

            return null;
        }

        public Gee.HashMap<int, string> get_artists_per_albums () {
            return db_manager != null
                   ? db_manager.get_artists_per_albums ()
                   : new Gee.HashMap<int, string> ();
        }

        public CObjects.Media? get_media (uint tid) {
            if (!media_hash.has_key (tid)) {
                return null;
            }

            return media_hash[tid];
        }

        public Gee.ArrayQueue<CObjects.Media> get_album_tracks (int album_id) {
            var tracks_queue = new Gee.ArrayQueue<CObjects.Media> ();
            if (db_manager != null) {
                db_manager.get_album_tracks (album_id).foreach ((tid) => {
                    if (media_hash.has_key (tid)) {
                        tracks_queue.offer (media_hash[tid]);
                    }

                    return true;
                });
            }

            return tracks_queue;
        }

        public async void init_library () {
            if (db_manager == null) {
                return;
            }

            genres_hash = db_manager.get_genres_hash ();
            load_genres ();
            artists_hash = db_manager.get_artists_hash ();
            load_artists ();
            load_albums (db_manager.get_albums ());

            media_hash = db_manager.get_tracks ();

            if (media_hash.size > 0) {
                library_loaded ();
            }
        }

        private void load_genres () {
            var genre_store = new Objects.CategoryStore (Enums.Category.GENRE, new Type[] {
                typeof (string),
                typeof (int),
            });

            genres_hash.keys.foreach ((k) => {
                Gtk.TreeIter genre_iter;
                genre_store.insert_with_values (out genre_iter, -1,
                                                0, Tools.String.get_simple_display_text (genres_hash[k]),
                                                1, k, -1);

                return true;
            });

            added_category (Enums.Category.GENRE, genre_store);
        }

        private void load_artists () {
            var artists_store = new Objects.CategoryStore (Enums.Category.ARTIST, new Type[] {
                typeof (string),
                typeof (int),
            });

            artists_hash.keys.foreach ((k) => {
                string simple_artist = Tools.String.get_simple_display_text (artists_hash[k]);

                Gtk.TreeIter iter;
                artists_store.insert_with_values (out iter, -1,
                                                  0, simple_artist,
                                                  1, k, -1);

                return true;
            });

            added_category (Enums.Category.ARTIST, artists_store);
        }

        private void load_albums (Gee.ArrayList<Structs.Album?> albums) {
            var albums_store = new Objects.CategoryStore (Enums.Category.ALBUM, new Type[] {
                typeof (string),
                typeof (int),
            });

            albums.foreach ((entry) => {
                Gtk.TreeIter album_iter;
                albums_store.insert_with_values (out album_iter, -1,
                                                 0, entry.title,
                                                 1, entry.album_id, -1);

                albums_hash[entry.album_id] = entry;

                return true;
            });

            added_category (Enums.Category.ALBUM, albums_store);
        }

        public void scan_library (string uri) {
            source_id = 0;

            scanner = new Services.LibraryScanner ();
            scanner.total_found.connect (on_total_found);
            scanner.added_track.connect (on_added_track);
            scanner.finished_scan.connect (on_finished_scan);

            scanner.start_scan (uri);
        }

        public void import_folder (string folder_uri, string music_folder) {
            source_id = 0;

            scanner = new Services.ImportManager (music_folder);
            scanner.total_found.connect (on_total_found);
            scanner.added_track.connect (on_added_track);
            scanner.finished_scan.connect (on_finished_scan);

            scanner.start_scan (folder_uri);
        }

        private void on_added_track (CObjects.Media m, int artist_id, int album_id) {
            scan_m++;
        }

        private void on_total_found (uint total_media) {
            total_m = total_media;

            scan_m = 0;
            if (total_m > 0) {
                source_id = GLib.Timeout.add (1000, () => {
                    if (scan_m == 0) {
                        return true;
                    }

                    progress_scan ((double) scan_m / total_m);
                    return true;
                });
            }

            prepare_scan ();
        }

        private void on_finished_scan (int64 scan_time) {
            if (source_id > 0) {
                GLib.Source.remove (source_id);
                source_id = 0;
            }

            string msg = _("Added %lld tracks to the library,").printf (scan_m);
            if (scan_time >= 0) {
                msg += _(" passed %s").printf (Tools.TimeUtils.pretty_time_from_sec (scan_time));
            }

            finished_scan (msg);
            total_m = 0;
            scan_m = 0;

            scanner = null;
        }

        public void stop_scanner () {
            if (source_id > 0) {
                if (scanner != null) {
                    scanner.stop_scan ();
                } else {
                    GLib.Source.remove (source_id);
                    source_id = 0;
                }
            }
        }

        public void clear_library () {
            media_hash.clear ();
            artists_hash.clear ();
            genres_hash.clear ();
            albums_hash.clear ();
        }
    }
}
