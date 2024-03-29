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
    public class Services.DataBaseManager : GLib.Object {
        private Sqlite.Database? db;
        private string errormsg;

        private static Services.DataBaseManager instance;

        public static DataBaseManager? get_instance () {
            if (instance == null) {
                var db_manager = new Services.DataBaseManager ();

                if (!db_manager.open_database ()) {
                    return null;
                }

                instance = db_manager;
            }

            return instance;
        }


        private DataBaseManager () {
            errormsg = "";

            Tools.FileUtils.get_cache_directory ();
        }

        private bool open_database () {
            int res = Sqlite.Database.open (get_db_path (), out db);
            if (res != Sqlite.OK) {
                warning ("Can't open database: %d: %s\n", db.errcode (), db.errmsg ());

                return false;
            }

            string q;
            q = """CREATE TABLE IF NOT EXISTS artists (
                ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                name        TEXT        NOT NULL,
                CONSTRAINT unique_artist UNIQUE (name)
            );""";

            if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                warning (errormsg);
            }

            q = """CREATE TABLE IF NOT EXISTS genres (
                ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                name        TEXT        NOT NULL,
                CONSTRAINT unique_genre UNIQUE (name)
            );""";

            if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                warning (errormsg);
            }

            q = """CREATE TABLE IF NOT EXISTS albums (
                ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                name        TEXT        NOT NULL,
                year        INT         NULL,
                CONSTRAINT unique_album UNIQUE (name, year)
            );""";

            if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                warning (errormsg);
            }

            q = """CREATE TABLE IF NOT EXISTS media (
                ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                album_id    INT         NOT NULL,
                artist_id   INT         NOT NULL,
                path        TEXT        NOT NULL,
                tid         INTEGER     NOT NULL,
                title       TEXT        NOT NULL,
                length      INT         NULL,
                genre_id    INT         NULL,
                track       INT         NULL,
                hits        INT         DEFAULT 0,
                last_access INTEGER     NOT NULL,
                CONSTRAINT unique_track UNIQUE (path),
                FOREIGN KEY (album_id) REFERENCES albums (ID) ON DELETE CASCADE
                FOREIGN KEY (artist_id) REFERENCES artists (ID) ON DELETE CASCADE
                FOREIGN KEY (genre_id) REFERENCES genres (ID) ON DELETE CASCADE
            );""";

            if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                warning (errormsg);
            }

            q = """CREATE TABLE IF NOT EXISTS playlists (
                ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                name        TEXT        NOT NULL,
                CONSTRAINT unique_name UNIQUE (name)
            );""";

            if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                warning (errormsg);
            }

            q = """CREATE TABLE IF NOT EXISTS playlist_tracks (
                ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                playlist_id INT         NOT NULL,
                track_id    INT         NOT NULL,
                number      INT         NOT NULL,
                CONSTRAINT unique_track UNIQUE (playlist_id, track_id),
                FOREIGN KEY (track_id) REFERENCES media (tid)
                    ON DELETE CASCADE,
                FOREIGN KEY (playlist_id) REFERENCES playlists (ID)
                    ON DELETE CASCADE
            );""";

            if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                warning (errormsg);
            }

            return true;
        }

        public string get_db_path () {
            return GLib.Path.build_path (GLib.Path.DIR_SEPARATOR_S,
                                         GLib.Environment.get_user_cache_dir (),
                                         Constants.APP_NAME,
                                         Constants.DB_VERSION + "-database.db");
        }

        public void reset_database () {
            GLib.File db_file = GLib.File.new_for_path (get_db_path ());
            if (db_file.query_exists ()) {
                db = null;
                try {
                    db_file.delete ();
                } catch (Error err) {
                    warning (err.message);
                }
            }

            open_database ();
        }

        private int get_playlist_id (string playlist_name) {
            Sqlite.Statement stmt;
            string sql = """
                SELECT id
                FROM playlists
                WHERE name=$NAME;
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_text (stmt.bind_parameter_index ("$NAME"), playlist_name);
            assert (res == Sqlite.OK);

            int playlist_id = -1;
            if (stmt.step () == Sqlite.ROW) {
                playlist_id = stmt.column_int (0);
            } else {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }

            stmt.reset ();
            return playlist_id;
        }

        public Gee.HashMap<int, string> get_playlists () {
            Sqlite.Statement stmt;
            string sql = """
                SELECT id, name
                FROM playlists;
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);

            var playlists_hash = new Gee.HashMap<int, string> ();
            while (stmt.step () == Sqlite.ROW) {
                playlists_hash[stmt.column_int (0)] = stmt.column_text (1);
            }

            stmt.reset ();
            return playlists_hash;
        }

        public Gee.ArrayList<int> get_available_playlists (uint tid) {
            Sqlite.Statement stmt;
            string sql = """
                SELECT id
                FROM playlists
                WHERE id NOT IN (
                    SELECT DISTINCT playlist_id
                    FROM playlist_tracks
                    WHERE track_id=$TID
                    );
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$TID"), (int) tid);
            assert (res == Sqlite.OK);

            var playlists = new Gee.ArrayList<int> ();
            while (stmt.step () == Sqlite.ROW) {
                playlists.add (stmt.column_int (0));
            }

            stmt.reset ();
            return playlists;
        }

        public Gee.ArrayQueue<uint>? get_automatic_playlist (int pid, int length) {
            var query_str = "";
            switch (pid) {
                case Constants.NEVER_PLAYED_ID:
                    query_str = """ WHERE hits=0 """;
                    break;
                case Constants.FAVORITE_SONGS_ID:
                    query_str = """ WHERE hits>1 ORDER BY hits DESC """;
                    break;
                case Constants.RECENTLY_PLAYED_ID:
                    query_str = """ WHERE hits>0 ORDER BY last_access DESC """;
                    break;
                default:
                    return null;
            }

            string sql = """
                SELECT id
                FROM media
            """;

            sql += query_str;
            sql += """LIMIT $LENGTH;""";

            Sqlite.Statement stmt;
            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$LENGTH"), length);
            assert (res == Sqlite.OK);

            var tracks_id = new Gee.ArrayQueue<uint> ();
            while (stmt.step () == Sqlite.ROW) {
                uint tid = (uint) stmt.column_int64 (0);

                tracks_id.offer (tid);
            }

            stmt.reset ();
            return tracks_id;
        }

        public Gee.ArrayQueue<uint> get_playlist_tracks (int playlist_id) {
            Sqlite.Statement stmt;
            string sql = """
                SELECT track_id
                FROM playlist_tracks
                WHERE playlist_id=$ID
                ORDER BY number;
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$ID"), playlist_id);
            assert (res == Sqlite.OK);

            var tracks_queue = new Gee.ArrayQueue<uint> ();
            while (stmt.step () == Sqlite.ROW) {
                tracks_queue.offer ((uint) stmt.column_int64 (0));
            }

            stmt.reset ();
            return tracks_queue;
        }

        private int get_playlist_size (int pid) {
            Sqlite.Statement stmt;
            string sql = """
                SELECT COUNT()
                FROM playlist_tracks
                WHERE playlist_id=$PID;
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$PID"), pid);
            assert (res == Sqlite.OK);

            int playlist_size = 0;
            if (stmt.step () == Sqlite.ROW) {
                playlist_size = stmt.column_int (0);
            } else {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
                stmt.reset ();
                return -1;
            }

            stmt.reset ();
            return playlist_size;
        }

        public int add_playlist (string playlist_name) {
            Sqlite.Statement stmt;
            string sql = """
                INSERT OR IGNORE INTO playlists (name) VALUES ($NAME);
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_text (stmt.bind_parameter_index ("$NAME"), playlist_name);
            assert (res == Sqlite.OK);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
                stmt.reset ();
                return 0;
            }

            stmt.reset ();
            return get_playlist_id (playlist_name);
        }

        public bool add_to_playlist (int pid, uint tid) {
            var pl_size = get_playlist_size (pid);
            if (pl_size < 0) {
                return false;
            }

            Sqlite.Statement stmt;
            string sql = """
                INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, number) VALUES ($PLAYLIST, $TRACK, $NUM);
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$PLAYLIST"), pid);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$TRACK"), (int) tid);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$NUM"), ++pl_size);
            assert (res == Sqlite.OK);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
                stmt.reset ();
                return false;
            }

            stmt.reset ();
            return true;
        }

        public void update_playlist (int pid, Gee.ArrayQueue<uint> tracks) {
            if (!clear_playlist (pid) || tracks.size == 0) {
                return;
            }

            Sqlite.Statement stmt;
            string sql = """
                INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, number) VALUES ($PID, $TID, $NUM);
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);

            int nums = 1;
            tracks.foreach ((t) => {
                res = stmt.bind_int (stmt.bind_parameter_index ("$PID"), pid);
                assert (res == Sqlite.OK);
                res = stmt.bind_int (stmt.bind_parameter_index ("$TID"), (int) t);
                assert (res == Sqlite.OK);
                res = stmt.bind_int (stmt.bind_parameter_index ("$NUM"), nums);
                assert (res == Sqlite.OK);

                if (stmt.step () != Sqlite.DONE) {
                    warning ("Error: %d: %s", db.errcode (), db.errmsg ());
                } else {
                    nums++;
                }

                stmt.reset ();
                return true;
            });
        }

        public bool clear_playlist (int playlist_id) {
            Sqlite.Statement stmt;
            string sql = """
                DELETE FROM playlist_tracks WHERE playlist_id=$ID;
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$ID"), playlist_id);
            assert (res == Sqlite.OK);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
                stmt.reset ();
                return false;
            }

            stmt.reset ();
            return true;
        }

        public bool edit_playlist_name (int pid, string name) {
            Sqlite.Statement stmt;
            string sql = """
                UPDATE playlists SET name=$NAME WHERE id=$ID;
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$ID"), pid);
            assert (res == Sqlite.OK);
            res = stmt.bind_text (stmt.bind_parameter_index ("$NAME"), name);
            assert (res == Sqlite.OK);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
                stmt.reset ();
                return false;
            }

            stmt.reset ();
            return true;
        }

        public bool remove_playlist (int playlist_id) {
            Sqlite.Statement stmt;
            string sql = """
                DELETE FROM playlists WHERE id=$ID;
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$ID"), playlist_id);
            assert (res == Sqlite.OK);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
                stmt.reset ();
                return false;
            }

            stmt.reset ();
            return true;
        }

        public int insert_genre (string g) {
            return insert_val ("genres", g);
        }

        public int insert_artist (string a) {
            return insert_val ("artists", a);
        }

        private int insert_val (string t_name, string val) {
            Sqlite.Statement stmt;
            string sql = """
                INSERT OR IGNORE INTO """ + t_name + """ (name) VALUES ($NAME);
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_text (stmt.bind_parameter_index ("$NAME"), val);
            assert (res == Sqlite.OK);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();

            sql = """
                SELECT id FROM """ + t_name + """ WHERE name=$NAME;
            """;

            res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_text (stmt.bind_parameter_index ("$NAME"), val);
            assert (res == Sqlite.OK);

            int item_id = -1;
            if (stmt.step () == Sqlite.ROW) {
                item_id = stmt.column_int (0);
            } else {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }

            stmt.reset ();
            return item_id;
        }

        public GLib.List<Structs.KeyVal?> get_category_contents (string t_name) {
            Sqlite.Statement stmt;
            string sql = """
                SELECT id, name
                FROM """ + t_name + """
                ORDER BY name;
            """;
            
            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            
            var _list = new GLib.List<Structs.KeyVal?> ();
            while (stmt.step () == Sqlite.ROW) {
                Structs.KeyVal kv_struct = {};

                kv_struct.k = stmt.column_int (0);
                kv_struct.v = stmt.column_text (1);

                _list.append (kv_struct);
            }

            stmt.reset ();
            return _list;
        }

        public Gee.ArrayList<int> get_albums_id (string f_name, int fid) {
            Sqlite.Statement stmt;

            string sql = """
                SELECT DISTINCT album_id
                FROM media
                WHERE """ + f_name + """=$FID
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);

            res = stmt.bind_int (stmt.bind_parameter_index ("$FID"), fid);
            assert (res == Sqlite.OK);

            var a_array = new Gee.ArrayList<int> ();
            while (stmt.step () == Sqlite.ROW) {
                a_array.add (stmt.column_int (0));
            }

            stmt.reset ();
            return a_array;
        }

        public Gee.ArrayList<int> get_artists_id (int g_id) {
            Sqlite.Statement stmt;

            string sql = """
                SELECT DISTINCT artist_id
                FROM media
                WHERE genre_id=$GID
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$GID"), g_id);
            assert (res == Sqlite.OK);

            var a_array = new Gee.ArrayList<int> ();
            while (stmt.step () == Sqlite.ROW) {
                a_array.add (stmt.column_int (0));
            }

            stmt.reset ();
            return a_array;
        }

        public Gee.HashMap<int, string> get_artists_per_albums () {
            var return_hash = new Gee.HashMap<int, string> ();
            Sqlite.Statement stmt;

            string sql = """
                SELECT a.album_id, artists.name
                FROM (SELECT DISTINCT album_id, artist_id
                    FROM media
                    GROUP BY album_id) a
                INNER JOIN artists
                ON a.artist_id = artists.id;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);

            while (stmt.step () == Sqlite.ROW) {
                var alb_id = stmt.column_int (0);

                if (return_hash.has_key (alb_id)) {
                    return_hash[alb_id] = return_hash[alb_id] + ";" + stmt.column_text (1);
                } else {
                    return_hash[alb_id] = stmt.column_text (1);
                }
            }

            stmt.reset ();
            return return_hash;
        }

        public Gee.ArrayQueue<uint> get_album_tracks (int album_id) {
            Sqlite.Statement stmt;
            string sql = """
                SELECT tid
                FROM media
                WHERE album_id=$AID
                ORDER BY track, title;
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$AID"), album_id);
            assert (res == Sqlite.OK);

            var tracks_queue = new Gee.ArrayQueue<uint> ();
            while (stmt.step () == Sqlite.ROW) {
                tracks_queue.offer ((uint) stmt.column_int64 (0));
            }

            stmt.reset ();
            return tracks_queue;
        }

        public Gee.ArrayList<Structs.Album?> get_albums () {
            var return_hash = new Gee.ArrayList<Structs.Album?> ();
            Sqlite.Statement stmt;

            string sql = """
                SELECT id, name, year FROM albums ORDER BY name;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);

            while (stmt.step () == Sqlite.ROW) {
                Structs.Album album_struct = {};
                album_struct.album_id = stmt.column_int (0);
                album_struct.title = stmt.column_text (1);
                album_struct.year = (uint) stmt.column_int (2);

                return_hash.add (album_struct);
            }

            stmt.reset ();
            return return_hash;
        }

        public int insert_album (CObjects.Media m) {
            Sqlite.Statement stmt;
            string sql = """
                INSERT OR IGNORE INTO albums (name, year) VALUES ($NAME, $YEAR);
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);

            res = stmt.bind_text (stmt.bind_parameter_index ("$NAME"), m.album);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$YEAR"), (int) m.year);
            assert (res == Sqlite.OK);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();

            sql = """
                SELECT id FROM albums WHERE year=$YEAR AND name=$NAME;
            """;

            res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$YEAR"), (int) m.year);
            assert (res == Sqlite.OK);
            res = stmt.bind_text (stmt.bind_parameter_index ("$NAME"), m.album);
            assert (res == Sqlite.OK);

            int album_id = -1;
            if (stmt.step () == Sqlite.ROW) {
                album_id = stmt.column_int (0);
            } else {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }

            stmt.reset ();
            return album_id;
        }

        public GLib.HashTable<uint, CObjects.Media> get_tracks () {
            Sqlite.Statement stmt;

            string sql = """
                SELECT media.tid, media.title, genres.name, media.track, media.path, media.length, albums.name, albums.year, artists.name, media.hits
                FROM media
                INNER JOIN albums
                ON media.album_id = albums.id
                INNER JOIN artists
                ON media.artist_id = artists.id
                INNER JOIN genres
                ON media.genre_id = genres.id;
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);

            GLib.HashTable<uint, CObjects.Media> tracks_hash = new GLib.HashTable<uint, CObjects.Media> ((k) => {return k;}, (k1, k2) => {return k1 == k2;});
            while (stmt.step () == Sqlite.ROW) {
                var uri = stmt.column_text (4);
                if (uri == null) {
                    continue;
                }

                var m = new CObjects.Media (uri);
                m.tid = (uint) stmt.column_int64 (0);
                m.title = stmt.column_text (1) ?? "";
                m.genre = stmt.column_text (2) ?? "";
                m.track = (uint) stmt.column_int64 (3);
                m.length = (uint) stmt.column_int64 (5);
                m.album = stmt.column_text (6) ?? "";
                m.year = (uint) stmt.column_int (7);
                m.artist = stmt.column_text (8) ?? "";
                m.hits = (uint) stmt.column_int (9);

                tracks_hash.insert (m.tid, m);
            }

            stmt.reset ();
            return tracks_hash;
        }

        public bool insert_track (CObjects.Media m, int album_id, int artist_id, int genre_id) {
            Sqlite.Statement stmt;
            string sql = """
                INSERT OR IGNORE INTO media (tid, album_id, artist_id, title, track, path, length, genre_id, last_access)
                VALUES ($TID, $ALBUM_ID, $ARTIST_ID, $TITLE, $TRACK, $URI, $LENGTH, $GENRE_ID, $ACCESS_TIME);
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);

            res = stmt.bind_int64 (stmt.bind_parameter_index ("$TID"), (int64) m.tid);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$ALBUM_ID"), album_id);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$ARTIST_ID"), artist_id);
            assert (res == Sqlite.OK);
            res = stmt.bind_text (stmt.bind_parameter_index ("$TITLE"), m.title);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$GENRE_ID"), genre_id);
            assert (res == Sqlite.OK);
            res = stmt.bind_int64 (stmt.bind_parameter_index ("$TRACK"), (int64) m.track);
            assert (res == Sqlite.OK);
            res = stmt.bind_text (stmt.bind_parameter_index ("$URI"), m.uri);
            assert (res == Sqlite.OK);
            res = stmt.bind_int64 (stmt.bind_parameter_index ("$LENGTH"), (int64) m.length);
            assert (res == Sqlite.OK);

            var now = new GLib.DateTime.now_local ();
            res = stmt.bind_int64 (stmt.bind_parameter_index ("$ACCESS_TIME"), now.to_unix ());
            assert (res == Sqlite.OK);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
                stmt.reset ();

                return false;
            }

            stmt.reset ();

            return true;
        }

        public void update_playback_info (string uri, bool write_hit) {
            Sqlite.Statement stmt;
            string sql = """
                UPDATE media SET last_access=$ACCESS_TIME
            """;

            if (write_hit) {
                sql += """, hits=hits+1 """;
            }

            sql += """ WHERE path=$URI; """;

            var now = new GLib.DateTime.now_local ();

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);

            res = stmt.bind_int64 (stmt.bind_parameter_index ("$ACCESS_TIME"), now.to_unix ());
            assert (res == Sqlite.OK);
            res = stmt.bind_text (stmt.bind_parameter_index ("$URI"), uri);
            assert (res == Sqlite.OK);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }

            stmt.reset ();
        }

        // private Gee.ArrayQueue<CObjects.Media> fill_model (Sqlite.Statement stmt) {
        //     var tracks_queue = new Gee.ArrayQueue<CObjects.Media> ();
        //
        //     while (stmt.step () == Sqlite.ROW) {
        //         var uri = stmt.column_text (4);
        //         if (uri == null) {
        //             continue;
        //         }
        //         var m = new CObjects.Media (uri);
        //         m.tid = (uint) stmt.column_int64 (0);
        //         m.title = stmt.column_text (1) ?? "";
        //         m.genre = stmt.column_text (2) ?? "";
        //         m.track = (uint) stmt.column_int64 (3);
        //         m.length = (uint) stmt.column_int64 (5);
        //         m.album = stmt.column_text (6) ?? "";
        //         m.year = (uint) stmt.column_int (7);
        //         m.artist = stmt.column_text (8) ?? "";
        //         m.hits = (uint) stmt.column_int (9);
        //
        //         tracks_queue.offer (m);
        //     }
        //
        //     stmt.reset ();
        //     return tracks_queue;
        // }

        // public CObjects.Media? get_track (string uri) {
        //     Sqlite.Statement stmt;
        //
        //     string sql = """
        //         SELECT media.id, media.title, albums.genre, media.track, media.path, media.length, albums.title, albums.year, artists.name
        //         FROM media
        //         INNER JOIN albums
        //         ON media.album_id = albums.id
        //         INNER JOIN artists
        //         ON media.artist_id = artists.id
        //         WHERE media.path=$URI
        //     """;
        //
        //     int res = db.prepare_v2 (sql, sql.length, out stmt);
        //     assert (res == Sqlite.OK);
        //
        //     res = stmt.bind_text (stmt.bind_parameter_index ("$URI"), uri);
        //     assert (res == Sqlite.OK);
        //
        //     CObjects.Media? m = null;
        //     if (stmt.step () == Sqlite.ROW) {
        //         m = new CObjects.Media (stmt.column_text (4));
        //         m.tid = (uint) stmt.column_int64 (0);
        //         m.title = stmt.column_text (1);
        //         m.genre = stmt.column_text (2);
        //         m.track = (uint) stmt.column_int64 (3);
        //         m.length = (uint) stmt.column_int64 (5);
        //         m.album = stmt.column_text (6);
        //         m.year = (uint) stmt.column_int (7);
        //         m.artist = stmt.column_text (8);
        //     }
        //
        //     stmt.reset ();
        //     return m;
        // }
    }
}
