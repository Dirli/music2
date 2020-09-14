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
        public signal void added_category (Enums.Category category, Gtk.ListStore store);
        public signal void started_scan ();
        public signal void finished_scan (string msg);
        public signal void prepare_scan ();
        public signal void progress_scan (double progress_val);
        public signal void cleared_library ();

        private uint source_id = 0;
        private uint scan_m = 0;
        private uint total_m = 0;

        public bool loaded = false;

        public Gee.HashMap<uint, CObjects.Media> media_hash;
        public Gee.HashMap<uint, Gtk.TreeIter?> media_iter_hash;
        public Gtk.ListStore media_store;

        public Gtk.ListStore albums_grid_store;

        public Gee.HashMap<int, Gtk.TreeIter?> albums_hash;
        public Objects.CategoryStore albums_store;

        public Gee.HashMap<int, Gtk.TreeIter?> artists_hash;
        public Objects.CategoryStore artists_store;

        public Gee.ArrayList<string> genre_array;
        public Objects.CategoryStore genre_store;

        private Interfaces.Scanner scanner;

        public LibraryManager () {
            Tools.FileUtils.get_cache_directory ("covers");

            media_hash = new Gee.HashMap<uint, CObjects.Media> ();

            media_store = new Gtk.ListStore.newv (Enums.ListColumn.get_all ());
            media_store.set_sort_column_id ((int) Enums.ListColumn.ARTIST, Gtk.SortType.ASCENDING);
            media_store.set_sort_func ((int) Enums.ListColumn.ARTIST, media_sort_func);

            media_iter_hash = new Gee.HashMap<uint, Gtk.TreeIter?> ();

            albums_grid_store = new Gtk.ListStore (2, typeof (Structs.Album), typeof (string));
            albums_grid_store.set_sort_column_id (0, Gtk.SortType.ASCENDING);
            albums_grid_store.set_sort_func (0, grid_sort_func);

            artists_hash = new Gee.HashMap<int, Gtk.TreeIter?> ();
            albums_hash = new Gee.HashMap<int, Gtk.TreeIter?> ();
            genre_array = new Gee.ArrayList<string> ();
        }

        public void init_stores () {
            artists_store = new Objects.CategoryStore (Enums.Category.ARTIST, new Type[] {
                typeof (string),
                typeof (int),
            });
            added_category (Enums.Category.ARTIST, artists_store);

            albums_store = new Objects.CategoryStore (Enums.Category.ALBUM, new Type[] {
                typeof (string),
                typeof (int),
                typeof (int),
                typeof (string),
            });
            added_category (Enums.Category.ALBUM, albums_store);

            genre_store = new Objects.CategoryStore (Enums.Category.GENRE, new Type[] {
                typeof (string),
                typeof (int),
            });
            added_category (Enums.Category.GENRE, genre_store);
        }

        public void add_track (CObjects.Media m) {
            lock (media_store) {
                Gtk.TreeIter iter;
                media_store.insert_with_values (out iter, -1,
                    (int) Enums.ListColumn.TRACKID, m.tid,
                    (int) Enums.ListColumn.TRACK, m.track,
                    (int) Enums.ListColumn.ALBUM, m.get_display_album (),
                    (int) Enums.ListColumn.LENGTH, m.length,
                    (int) Enums.ListColumn.GENRE, m.get_display_genre (),
                    (int) Enums.ListColumn.TITLE, m.get_display_title (),
                    (int) Enums.ListColumn.ARTIST, GLib.Markup.escape_text (m.get_display_artist ()), -1);

                media_hash[m.tid] = m;
                media_iter_hash[m.tid] = iter;
            }
        }

        public void add_artist (string artist_name, int artist_id) {
            if (!artists_hash.has_key (artist_id)) {
                lock (artists_store) {
                    Gtk.TreeIter iter;
                    string simple_artist = Tools.String.get_simple_display_text (artist_name);
                    artists_store.insert_with_values (out iter, -1, 0, simple_artist, 1, artist_id, -1);
                    artists_hash[artist_id] = iter;
                }
            }
        }

        public CObjects.Media? get_media (uint tid) {
            if (!media_hash.has_key (tid)) {
                return null;
            }

            return media_hash[tid];
        }

        public Gtk.TreeIter? get_media_iter (uint tid) {
            if (!media_iter_hash.has_key (tid)) {
                return null;
            }

            return media_iter_hash[tid];
        }

        public void add_album (Structs.Album a_struct) {
            if (!albums_hash.has_key (a_struct.album_id)) {
                if (!genre_array.contains (a_struct.genre)) {
                    lock (genre_store) {
                        genre_array.add (a_struct.genre);
                        Gtk.TreeIter genre_iter;
                        genre_store.insert_with_values (out genre_iter, -1,
                                                        0, Tools.String.get_simple_display_text (a_struct.genre),
                                                        1, genre_array.size, -1);
                    }
                }

                var genre_id = genre_array.index_of (a_struct.genre) + 1;
                lock (albums_store) {
                    Gtk.TreeIter album_iter;
                    albums_store.insert_with_values (out album_iter, -1,
                                                     0, a_struct.title,
                                                     1, a_struct.album_id,
                                                     2, genre_id,
                                                     3, a_struct.artists_id, -1);

                     albums_hash[a_struct.album_id] = album_iter;
                }

                string custom_tooltip = a_struct.artists + "\n<span size=\"large\">%u, %s</span>".printf (a_struct.year, Markup.escape_text (a_struct.genre));
                lock (albums_grid_store) {
                    Gtk.TreeIter grid_iter;
                    albums_grid_store.insert_with_values (out grid_iter, -1,
                                                          0, a_struct,
                                                          1, custom_tooltip, -1);
                }
            }
        }

        public void init_library () {
            var db_manager = new DataBaseManager ();

            if (!db_manager.check_db) {
                return;
            }

            clear_stores ();


            var artists_map = db_manager.get_artists ();
            artists_map.keys.foreach ((k) => {
                add_artist (artists_map[k], k);
                return true;
            });

            var apa_cache = db_manager.get_artists_per_albums ();
            var albums = db_manager.get_albums ();
            albums.foreach ((entry) => {
                if (apa_cache.has_key (entry.album_id)) {
                    var artists_string = "";
                    var artists_id = "";

                    apa_cache[entry.album_id].foreach ((art_id) => {
                        if (artists_string != "") {
                            artists_string += "\n";
                        }

                        if (artists_id != "") {
                            artists_id += ";";
                        }

                        artists_id += art_id.to_string ();

                        if (artists_hash.has_key (art_id)) {
                            lock (artists_store) {
                                string s;

                                artists_store.@get (artists_hash[art_id], 0, out s, -1);
                                if (s != null) {
                                    artists_string += "<span size=\"large\"><b>%s</b></span>".printf (Markup.escape_text (s));
                                }
                            }
                        }

                        return true;
                    });

                    entry.artists_id = artists_id;
                    entry.artists = artists_string;

                    add_album (entry);
                }

                return true;
            });

            var tracks_queue = db_manager.get_tracks (null);
            tracks_queue.foreach ((m) => {
                add_track (m);
                return true;
            });

            loaded = true;
        }

        public void scan_library (string uri) {
            started_scan ();

            source_id = 0;

            scanner = new Services.LibraryScanner ();
            scanner.total_found.connect (on_total_found);
            scanner.added_track.connect (on_added_track);
            scanner.finished_scan.connect ((scan_time) => {
                ((Services.LibraryScanner) scanner).apa_cache.foreach ((entry) => {
                    var artists_str = "";
                    if (albums_hash.has_key (entry.key)) {
                        entry.value.foreach ((artist_id) => {
                            if (artists_str != "") {
                                artists_str += ";";
                            }

                            artists_str += artist_id.to_string ();
                            return true;
                        });
                        if (artists_str != "") {
                            albums_store.@set (albums_hash[entry.key], 3, artists_str, -1);
                        }
                    }
                    return true;
                });

                on_finished_scan (scan_time);
            });

            scanner.start_scan (uri);
        }

        public void import_folder (string folder_uri, string music_folder) {
            started_scan ();

            source_id = 0;

            scanner = new Services.ImportManager (music_folder);
            scanner.total_found.connect (on_total_found);
            scanner.added_track.connect (on_added_track);
            scanner.finished_scan.connect (on_finished_scan);

            scanner.start_scan (folder_uri);
        }

        private void on_added_track (CObjects.Media m, int artist_id, int album_id) {
            scan_m++;

            add_artist (m.artist, artist_id);

            Structs.Album album_struct = get_album_struct (m, album_id, artist_id);
            add_album (album_struct);

            add_track (m);
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

        private Structs.Album get_album_struct (CObjects.Media m, int album_id, int artist_id) {
            Structs.Album album_struct = {};

            album_struct.album_id = album_id;
            album_struct.title = m.album;
            album_struct.artists_id = artist_id.to_string ();
            album_struct.artists = "...";
            album_struct.year = m.year;
            album_struct.genre = m.genre;

            return album_struct;
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

        private int sort_column_func (Gtk.TreeModel store, Gtk.TreeIter a, Gtk.TreeIter b, Enums.ListColumn col_id) {
            GLib.Value val_a;
            store.get_value (a, col_id, out val_a);
            GLib.Value val_b;
            store.get_value (b, col_id, out val_b);

            var col_type = col_id.get_data_type ();
            if (col_type == GLib.Type.STRING) {
                return Tools.String.compare (val_a.get_string (), val_b.get_string ());
            } else if (col_type == GLib.Type.UINT) {
                uint uint_a = val_a.get_uint ();
                uint uint_b = val_b.get_uint ();
                return uint_a == uint_b ? 0 : uint_a > uint_b ? 1 : -1;
            }

            return 0;
        }

        public int media_sort_func (Gtk.TreeModel store, Gtk.TreeIter a, Gtk.TreeIter b) {
            var l_store = store as Gtk.ListStore;
            if (l_store != null && !l_store.iter_is_valid (a) || !l_store.iter_is_valid (b)) {
                return 0;
            }

            int sort_column_id;
            Gtk.SortType sort_direction;
            l_store.get_sort_column_id (out sort_column_id, out sort_direction);

            if (sort_column_id < 1) {return 0;}

            int rv = 0;
            rv = sort_column_func (store, a, b, (Enums.ListColumn) sort_column_id);

            if (sort_direction == Gtk.SortType.DESCENDING) {
                rv = (rv > 0) ? -1 : 1;
            }

            return rv;
        }

        private int grid_sort_func (Gtk.TreeModel store, Gtk.TreeIter a, Gtk.TreeIter b) {
            int rv = 0;

            Structs.Album? struct_a;
            store.@get (a, 0, out struct_a, -1);

            Structs.Album? struct_b;
            store.@get (b, 0, out struct_b, -1);

            if (struct_a != null && struct_b != null) {
                rv = Tools.String.compare (struct_a.title, struct_b.title);
            }

            return rv;
        }

        public bool dirty_library () {
            return media_hash.size > 0 || artists_hash.size > 0 || albums_hash.size > 0;
        }

        private void clear_stores () {
            media_store.clear ();

            artists_store.clear ();
            genre_store.clear ();
            albums_store.clear ();

            albums_grid_store.clear ();
        }

        public void clear_library () {
            bool clear_ui = false;
            if (dirty_library ()) {
                clear_ui = true;
            }

            media_hash.clear ();
            media_iter_hash.clear ();
            artists_hash.clear ();
            albums_hash.clear ();
            genre_array.clear ();

            clear_stores ();

            if (clear_ui) {
                cleared_library ();
            }
        }
    }
}
