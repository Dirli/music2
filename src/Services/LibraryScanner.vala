namespace Music2 {
    public class Services.LibraryScanner : GLib.Object {
        public signal void finished_scan (int64 scan_time = -1);
        public signal void added_track (CObjects.Media m);
        public signal void added_artist (string artist_name, int artist_id);
        public signal void added_album (Structs.Album album);
        public signal void added_apa (int artist_id, int album_id);
        public signal void total_found (uint total);

        public int64 start_time;
        public uint total_media;
        public uint recorded_tracks;

        private Gee.HashMap<uint, int> artists_cache;
        private Gee.HashMap<uint, int> albums_cache;
        private Gee.HashMap<int, Gee.ArrayList<int>> apa_cache;

        private bool write_flag = false;
        private Gee.ArrayQueue<CObjects.Media> write_queue;

        private Objects.LibraryTagger? lib_tagger;
        private DataBaseManager? db_manager;

        public LibraryScanner () {
            total_media = 0;
            recorded_tracks = 0;
        }

        public void start_scan (string uri) {
            apa_cache = new Gee.HashMap<int, Gee.ArrayList<int>> ();
            artists_cache = new Gee.HashMap<uint, int> ();
            albums_cache = new Gee.HashMap<uint, int> ();

            var now_time = new GLib.DateTime.now ();
            start_time = now_time.to_unix ();

            scan_directory (uri, true);

            total_found (total_media);

            db_manager = DataBaseManager.instance;
            db_manager.reset_database ();

            lib_tagger = new Objects.LibraryTagger ();
            lib_tagger.init ();
            lib_tagger.discovered_new_item.connect (on_new_item);

            if (total_media > 0) {
                write_queue = new Gee.ArrayQueue<CObjects.Media> ();
                scan_directory (uri, false);
            } else {
                stop_scan ();
            }
        }

        public void stop_scan () {
            lib_tagger.stop_discovered ();
            lib_tagger.discovered_new_item.disconnect (on_new_item);

            GLib.Mutex mutex = GLib.Mutex ();
            mutex.lock ();
            write_queue.clear ();
            mutex.unlock ();

            lib_tagger = null;

            // db_manager = null;
            finished_scan ();
        }

        public void scan_directory (string uri, bool first_step) {
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
                            scan_directory (target, first_step);
                        }

                    } else if (file_info.get_file_type () == GLib.FileType.DIRECTORY) {
                        scan_directory (directory.get_uri () + "/" + file_info.get_name (), first_step);
                    } else {
                        string mime_type = file_info.get_content_type ();
                        if (Tools.FileUtils.is_audio_file (mime_type)) {
                            if (first_step) {
                                ++total_media;
                            } else {
                                lib_tagger.add_discover_uri (directory.get_uri () + "/" + file_info.get_name ()
                                    .replace ("#", "%23")
                                    .replace ("%", "%25"));
                            }
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

        private void on_new_item (CObjects.Media m) {
            write_queue.offer (m);

            if (!write_flag) {
                write_flag = true;
                run_write ();
                write_flag = false;
            }

            if (lib_tagger != null && lib_tagger.scaned_files == total_media) {
                lib_tagger.discovered_new_item.disconnect (on_new_item);
                lib_tagger = null;
            }
        }

        private void run_write () {
            while (!write_queue.is_empty) {
                CObjects.Media m = write_queue.poll ();
                int art_id;
                if (!artists_cache.has_key (m.artist.hash ())) {
                    art_id = db_manager.insert_artist (m.artist);
                    artists_cache[m.artist.hash ()] = art_id;
                    added_artist (m.artist, art_id);
                } else {
                    art_id = artists_cache[m.artist.hash ()];
                }

                int alb_id;
                var alb_hash = ("%u".printf (m.year) + m.album).hash ();
                if (!albums_cache.has_key (alb_hash)) {
                    alb_id = db_manager.insert_album (m);
                    albums_cache[alb_hash] = alb_id;
                    Structs.Album album_struct = {};
                    album_struct.album_id = alb_id;
                    album_struct.title = m.album;
                    var new_apa = new Gee.ArrayList<int> ();
                    new_apa.add (art_id);
                    album_struct.artist_id = new_apa;
                    album_struct.artists = "...";
                    album_struct.year = m.year;
                    album_struct.genre = m.genre;
                    added_album (album_struct);
                } else {
                    alb_id = albums_cache[alb_hash];
                }

                if (!apa_cache.has_key (alb_id) || !apa_cache[alb_id].contains (art_id)) {
                    db_manager.insert_artist_per_album (art_id, alb_id);
                    if (!apa_cache.has_key (alb_id)) {
                        var new_arr = new Gee.ArrayList<int> ();
                        new_arr.add (art_id);
                        apa_cache[alb_id] = new_arr;
                    } else {
                        apa_cache[alb_id].add (art_id);
                    }

                    added_apa (art_id, alb_id);
                }

                m = db_manager.insert_track (m, alb_id, art_id);
                added_track (m);
                recorded_tracks++;

                if (recorded_tracks == total_media) {
                    var now_time = new GLib.DateTime.now ();
                    finished_scan (now_time.to_unix () - start_time);
                    db_manager = null;
                }
            }
        }
    }
}
