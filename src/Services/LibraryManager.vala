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

        public bool library_not_empty {
            get {
                return media_hash.length > 0 || albums_hash.size > 0;
            }
        }

        private Services.DataBaseManager? db_manager = null;

        private GLib.HashTable<uint, CObjects.Media> media_hash;
        private Gee.HashMap<int, Structs.Album?> albums_hash;

        public LibraryManager () {
            Tools.FileUtils.get_cache_directory ("covers");
        }

        construct {
            db_manager = Services.DataBaseManager.get_instance ();

            media_hash = new GLib.HashTable<uint, CObjects.Media> ((k) => {return k;}, (k1, k2) => {return k1 == k2;});

            albums_hash = new Gee.HashMap<int, Structs.Album?> ();
        }

        public GLib.List<unowned CObjects.Media> get_track_list () {
            GLib.List<unowned CObjects.Media> track_list = media_hash.get_values ();
            track_list.sort ((m1, m2) => {
                var res = Tools.String.compare (m1.get_display_artist (), m2.get_display_artist ());
                if (res != 0) {return res;}

                if (m1.year != m2.year) {return m1.year > m2.year ? 1 : -1;}

                res = Tools.String.compare (m1.get_display_album (), m2.get_display_album ());
                if (res != 0) { return res;}

                if (m1.track != m2.track) {return m1.track > m2.track ? 1 : -1;}

                return Tools.String.compare (m1.get_display_title (), m2.get_display_title ());
            });

            return track_list;
        }

        public Gee.Collection<Structs.Album?> get_albums () {
            return albums_hash.values;
        }

        public bool in_library (uint tid) {
            return media_hash.contains (tid);
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
            if (!media_hash.contains (tid)) {
                return null;
            }

            return media_hash.get (tid);
        }

        public Gee.ArrayQueue<CObjects.Media> get_album_tracks (int album_id) {
            var tracks_queue = new Gee.ArrayQueue<CObjects.Media> ();
            if (db_manager != null) {
                db_manager.get_album_tracks (album_id).foreach ((tid) => {
                    if (media_hash.contains (tid)) {
                        tracks_queue.offer (media_hash.get (tid));
                    }

                    return true;
                });
            }

            return tracks_queue;
        }

        public void init_library () {
            if (db_manager == null) {
                return;
            }

            load_category (Enums.Category.GENRE);
            load_category (Enums.Category.ARTIST);
            load_albums (db_manager.get_albums ());
            
            media_hash = db_manager.get_tracks ();

            if (media_hash.length > 0) {
                library_loaded ();
            }
        }

        private void load_category (Enums.Category cat) {
            var list_store = new Objects.CategoryStore (cat, new Type[] {
                typeof (string),
                typeof (int),
            });

            db_manager.get_category_contents (cat.to_table_name ()).foreach ((entry) => {
                Gtk.TreeIter iter;
                list_store.insert_with_values (out iter, -1,
                                                0, Tools.String.get_simple_display_text (entry.v),
                                                1, entry.k, -1);
            });

            added_category (cat, list_store);
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

        public void import_folder (string folder_uri, string music_folder) {
            //  source_id = 0;

            //  scanner = new Services.ImportManager (music_folder);
            //  scanner.total_found.connect (on_total_found);
            //  scanner.added_track.connect (on_added_track);
            //  scanner.finished_scan.connect (on_finished_scan);

            //  scanner.start_scan (folder_uri);
        }


        public void clear_library () {
            media_hash.remove_all ();
            albums_hash.clear ();
        }
    }
}
