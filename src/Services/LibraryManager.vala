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
        public signal bool add_view (CObjects.Media m, Enums.ViewMode view_mode);
        public signal void added_category (Structs.Iter iter);
        public signal void started_scan ();
        public signal void finished_scan (string msg);
        public signal void loaded_category (Enums.Category? category);
        public signal void prepare_scan ();
        public signal void progress_scan (double progress_val);
        public signal void cleared_library ();

        public Gee.HashMap<int, Structs.Album?> albums_hash;
        private Gee.HashMap<uint, CObjects.Media> media_hash;
        private Gee.HashMap<int, string> artists_hash;
        private Gee.ArrayList<string> genre_array;

        private Services.LibraryScanner lib_scanner;

        public bool loaded;

        public LibraryManager () {
            Tools.FileUtils.get_cache_directory ("covers");

            loaded = false;

            media_hash = new Gee.HashMap<uint, CObjects.Media> ();
            artists_hash = new Gee.HashMap<int, string> ();
            albums_hash = new Gee.HashMap<int, Structs.Album?> ();
            genre_array = new Gee.ArrayList<string> ();

        }

        public void add_track (CObjects.Media m) {
            lock (media_hash) {
                media_hash[m.tid] = m;
                add_view (m, Enums.ViewMode.COLUMN);
            }
        }

        public void add_artist (string artist_name, int artist_id) {
            lock (artists_hash) {
                if (!artists_hash.has_key (artist_id)) {
                    artists_hash[artist_id] = artist_name;
                    add_category (Enums.Category.ARTIST, artist_name, artist_id);
                }
            }
        }

        public CObjects.Media? get_media (uint tid) {
            if (!media_hash.has_key (tid)) {
                return null;
            }

            return media_hash[tid];
        }

        public string get_genre (int genre_i) {
            if (genre_i > genre_array.size) {
                return "";
            }

            return genre_array[genre_i - 1];
        }

        public void add_apa (int art_id, int alb_id) {
            lock (albums_hash) {
                albums_hash[alb_id].artist_id.add (art_id);
            }
        }

        public void add_album (Structs.Album a_struct) {
            if (!albums_hash.has_key (a_struct.album_id)) {
                lock (genre_array) {
                    if (!genre_array.contains (a_struct.genre)) {
                        genre_array.add (a_struct.genre);
                        add_category (Enums.Category.GENRE, a_struct.genre, genre_array.size);
                    }
                }
                albums_hash[a_struct.album_id] = a_struct;
                add_category (Enums.Category.ALBUM, a_struct.title, a_struct.album_id);
            }
        }

        public void load_library () {
            new Thread<void*> ("load_library", () => {
                var db_manager = new DataBaseManager ();

                if (!db_manager.check_db) {
                    return null;
                }

                lock (artists_hash) {
                    artists_hash = db_manager.get_artists ();
                }
                artists_hash.foreach ((art) => {
                    add_category (Enums.Category.ARTIST, art.value, art.key);
                    return true;
                });

                var apa_cache = db_manager.get_artists_per_albums ();

                db_manager.get_albums ().foreach ((entry) => {
                    if (apa_cache.has_key (entry.album_id)) {
                        var artists_string = "";

                        apa_cache[entry.album_id].foreach ((art_id) => {
                            if (artists_string != "") {
                                artists_string += "\n";
                            }

                            if (artists_hash.has_key (art_id)) {
                                artists_string += "<span size=\"large\"><b>%s</b></span>".printf (Markup.escape_text (artists_hash[art_id]));
                            }

                            return true;
                        });
                        entry.artist_id = apa_cache[entry.album_id];
                        entry.artists = artists_string;

                        add_album (entry);
                    }

                    return true;
                });

                var tracks_queue = db_manager.get_tracks (null);
                while (!tracks_queue.is_empty) {
                    var track = tracks_queue.poll ();
                    media_hash[track.tid] = track;
                    if (!add_view (track, Enums.ViewMode.COLUMN)) {
                        break;
                    }
                }

                loaded = true;

                return null;
            });
        }

        private void add_category (Enums.Category iter_category, string iter_name, int iter_id) {
            Structs.Iter new_iter = {};
            new_iter.category = iter_category;
            new_iter.name = iter_name;
            new_iter.id = iter_id;
            added_category (new_iter);
        }

        public void filter_library (Enums.Category category, int filter_id, Enums.ViewMode view_mode) {
            string[] albums_arr = {};
            bool filter_off = filter_id == 0;
            switch (category) {
                case Enums.Category.GENRE:
                    if (filter_off || (filter_id > 0 && genre_array.size >= filter_id)) {
                        var genre_str = filter_off ? "" : genre_array[filter_id - 1];
                        var hash_artistid = new Gee.HashSet<int> ();
                        albums_hash.values.foreach ((val) => {
                            if (filter_off || val.genre == genre_str) {
                                val.artist_id.foreach ((a_id) => {
                                    if (!hash_artistid.contains (a_id) && artists_hash.has_key (a_id)) {
                                        hash_artistid.add (a_id);
                                        add_category (Enums.Category.ARTIST, artists_hash[a_id], a_id);
                                    }
                                    return true;
                                });

                                add_category (Enums.Category.ALBUM, val.title, val.album_id);
                                if (!filter_off) {
                                    albums_arr += val.title;
                                }
                            }
                            return true;
                        });
                    }
                    break;
                case Enums.Category.ARTIST:
                    albums_hash.values.foreach ((val) => {
                        if (filter_off || val.artist_id.contains (filter_id)) {
                            add_category (Enums.Category.ALBUM, val.title, val.album_id);
                            if (!filter_off) {
                                albums_arr += val.title;
                            }
                        }
                        return true;
                    });

                    break;
                case Enums.Category.ALBUM:
                    if (!filter_off && albums_hash.has_key (filter_id)) {
                        albums_arr += albums_hash[filter_id].title;
                    }

                    break;
            }

            media_hash.values.foreach ((m) => {
                if (filter_off || m.album in albums_arr) {
                    if (category == Enums.Category.ARTIST && !filter_off && m.artist != artists_hash[filter_id]) {
                        return true;
                    }

                    if (!add_view (m, view_mode)) {
                        return false;
                    }
                }

                return true;
            });

            if (view_mode == Enums.ViewMode.COLUMN) {
                loaded_category (category);
            }
        }

        public void scan_library (string uri) {
            started_scan ();

            new Thread<void*> ("scan_directory", () => {
                uint total_m = 0;
                uint scan_m = 0;
                uint source_id = 0;

                lib_scanner = new Services.LibraryScanner ();
                lib_scanner.finished_scan.connect ((scan_time) => {
                    if (source_id > 0) {
                        GLib.Source.remove (source_id);
                        source_id = 0;
                    }

                    string msg = _("Added %lld tracks to the library,").printf (scan_m);
                    if (scan_time >= 0) {
                        msg += _(" passed %s").printf (Tools.TimeUtils.pretty_time_from_sec (scan_time));
                    }

                    finished_scan (msg);

                    lib_scanner = null;
                });
                lib_scanner.added_track.connect ((m) => {
                    scan_m++;
                    add_track (m);
                });
                lib_scanner.added_artist.connect (add_artist);
                lib_scanner.added_album.connect (add_album);
                lib_scanner.added_apa.connect (add_apa);
                lib_scanner.total_found.connect ((total_media) => {
                    total_m = total_media;
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
                });
                lib_scanner.start_scan (uri);

                return null;
            });
        }

        public void stop_scanner () {
            lib_scanner.stop_scan ();
        }

        public bool dirty_library () {
            return media_hash.size > 0 || artists_hash.size > 0 || albums_hash.size > 0 || genre_array.size > 0;
        }

        public void clear_library () {
            bool clear_ui = false;
            if (dirty_library ()) {
                clear_ui = true;
            }

            media_hash.clear ();
            artists_hash.clear ();
            albums_hash.clear ();
            genre_array.clear ();

            if (clear_ui) {
                cleared_library ();
            }
        }
    }
}
