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
    public class DataBaseManager : GLib.Object {
        private Sqlite.Database? db;
        private string errormsg;

        public static DataBaseManager? to_read () {
            var db_manager = new DataBaseManager ();
            if (!GLib.FileUtils.test (db_manager.get_db_path (), GLib.FileTest.IS_REGULAR)) {
                return null;
            }

            if (!db_manager.open_database (Sqlite.OPEN_READONLY)) {
                return null;
            }

            return db_manager;
        }

        public static DataBaseManager? to_write () {
            var db_manager = new DataBaseManager ();

            if (!db_manager.open_database (Sqlite.OPEN_READWRITE)) {
                return null;
            }

            return db_manager;
        }

        private DataBaseManager () {
            errormsg = "";

            Tools.FileUtils.get_cache_directory ();
        }

        private bool open_database (int flag) {
            int res = Sqlite.Database.open_v2 (get_db_path (), out db, flag);
            if (res != Sqlite.OK) {
            	warning ("can't open db");
                return false;;
            }

            db.busy_timeout (1000);

            if (flag == Sqlite.OPEN_READONLY) {
                return true;
            }

            string q;
            q = """CREATE TABLE IF NOT EXISTS artists (
                ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                name        TEXT    NOT NULL,
                CONSTRAINT unique_artist UNIQUE (name)
            );""";

            if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                warning (errormsg);
            }

            q = """CREATE TABLE IF NOT EXISTS albums (
                ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                title       TEXT        NOT NULL,
                genre       TEXT        NULL,
                year        INT         NULL,
                CONSTRAINT unique_album UNIQUE (title, year)
            );""";

            if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                warning (errormsg);
            }

            // artists per album
            q = """CREATE TABLE IF NOT EXISTS artperalb (
                ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                album_id    INT         NOT NULL,
                artist_id   INT         NOT NULL,
                CONSTRAINT unique_iter UNIQUE (album_id, artist_id),
                FOREIGN KEY (album_id) REFERENCES albums (ID) ON DELETE CASCADE
                FOREIGN KEY (artist_id) REFERENCES artists (ID) ON DELETE CASCADE
            );""";

            if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                warning (errormsg);
            }

            q = """CREATE TABLE IF NOT EXISTS media (
                ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                album_id    INT         NOT NULL,
                artist_id   INT         NOT NULL,
                path        TEXT        NOT NULL,
                title       TEXT        NOT NULL,
                length      INT         NULL,
                track       INT         NULL,
                hits        INT         DEFAULT 0,
                last_access INTEGER     NOT NULL,
                CONSTRAINT unique_track UNIQUE (path),
                FOREIGN KEY (album_id) REFERENCES albums (ID) ON DELETE CASCADE
                FOREIGN KEY (artist_id) REFERENCES artists (ID) ON DELETE CASCADE
            );""";

            if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                warning (errormsg);
            }

            q = """CREATE TABLE IF NOT EXISTS playlists (
                ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                title       TEXT        NOT NULL,
                CONSTRAINT unique_title UNIQUE (title)
            );""";

            if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                warning (errormsg);
            }

            q = """INSERT OR IGNORE INTO playlists (title) VALUES ('""" + Constants.QUEUE + """');""";

            if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                warning (errormsg);
            }

            q = """CREATE TABLE IF NOT EXISTS playlist_tracks (
                ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                playlist_id INT         NOT NULL,
                track_id    INT         NOT NULL,
                number      INT         NOT NULL,
                CONSTRAINT unique_track UNIQUE (playlist_id, track_id),
                FOREIGN KEY (track_id) REFERENCES media (ID)
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
                try {
                    db_file.delete ();
                } catch (Error err) {
                    warning (err.message);
                }
            }
        }

        public int get_playlist_id (string playlist_name) {
            Sqlite.Statement stmt;

            string sql = """
                SELECT id FROM playlists WHERE title=$TITLE
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_text (stmt.bind_parameter_index ("$TITLE"), playlist_name);
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

        public Gee.HashMap<int, Structs.Playlist?> get_playlists () {
            var playlists_hash = new Gee.HashMap<int, Structs.Playlist?> ();

            Sqlite.Statement stmt;
            string sql = """
                SELECT playlists.id, playlists.title, playlist_tracks.track_id
                FROM playlists
                LEFT JOIN playlist_tracks
                ON playlists.id = playlist_tracks.playlist_id
                WHERE playlists.title != '""" + Constants.QUEUE + """'
                ORDER BY playlists.title, playlist_tracks.number;
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);

            while (stmt.step () == Sqlite.ROW) {
                var pid = stmt.column_int (0);
                var tid = (uint) stmt.column_int64 (2);
                if (!playlists_hash.has_key (pid)) {
                    Structs.Playlist new_pl = {};
                    new_pl.id = pid;
                    new_pl.name = stmt.column_text (1);
                    new_pl.type = Enums.SourceType.PLAYLIST;
                    new_pl.tracks = new Gee.ArrayList<uint> ();

                    playlists_hash[pid] = new_pl;
                }

                if (tid > 0) {
                    playlists_hash[pid].tracks.add (tid);
                }
            }

            stmt.reset ();
            return playlists_hash;
        }

        public Gee.ArrayList<uint>? get_automatic_playlist (int pid, int length) {
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

            var tracks_id = new Gee.ArrayList<uint> ();
            while (stmt.step () == Sqlite.ROW) {
                uint tid = (uint) stmt.column_int64 (0);

                tracks_id.add (tid);
            }

            stmt.reset ();
            return tracks_id;
        }

        public Gee.ArrayQueue<CObjects.Media> get_automatic_tracks (int pid, int length) {
            Sqlite.Statement stmt;

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
                    return new Gee.ArrayQueue<CObjects.Media> ();
            }

            string sql = """
                SELECT media.id, media.title, albums.genre, media.track, media.path, media.length, albums.title, albums.year, artists.name, media.hits
                FROM media
                INNER JOIN albums
                ON media.album_id = albums.id
                INNER JOIN artists
                ON media.artist_id = artists.id
            """;

            sql += query_str;
            sql += """LIMIT $LENGTH;""";

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$LENGTH"), length);
            assert (res == Sqlite.OK);

            return fill_model (stmt);
        }

        public Gee.ArrayQueue<CObjects.Media> get_playlist_tracks (int playlist_id) {
            Sqlite.Statement stmt;

            string sql = """
                SELECT media.id, media.title, albums.genre, media.track, media.path, media.length, albums.title, albums.year, artists.name, media.hits
                FROM playlist_tracks
                INNER JOIN media
                ON playlist_tracks.track_id = media.ID
                INNER JOIN albums
                ON media.album_id = albums.id
                INNER JOIN artists
                ON media.artist_id = artists.id
                WHERE playlist_tracks.playlist_id=$ID
                ORDER BY playlist_tracks.number;
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$ID"), playlist_id);
            assert (res == Sqlite.OK);

            return fill_model (stmt);
        }

        public int add_playlist (string playlist_name) {
            Sqlite.Statement stmt;

            string sql = """
                INSERT OR IGNORE INTO playlists (title) VALUES ($TITLE);
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_text (stmt.bind_parameter_index ("$TITLE"), playlist_name);
            assert (res == Sqlite.OK);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
                stmt.reset ();

                return 0;
            }

            stmt.reset ();

            return get_playlist_id (playlist_name);
        }

        public void update_playlist (int playlist_id, uint[] tracks_arr, bool rewrite) {
            Sqlite.Statement stmt;
            int nums = 1;
            if (rewrite) {
                if (!clear_playlist (playlist_id)) {
                    return;
                }
            } else {
                string sql = """
                    SELECT COUNT() FROM playlist_tracks WHERE playlist_id=$ID;
                """;

                int res = db.prepare_v2 (sql, sql.length, out stmt);
                assert (res == Sqlite.OK);
                res = stmt.bind_int (stmt.bind_parameter_index ("$ID"), playlist_id);
                assert (res == Sqlite.OK);

                if (stmt.step () == Sqlite.ROW) {
                    nums = stmt.column_int (0) + 1;
                } else {
                    warning ("Error: %d: %s", db.errcode (), db.errmsg ());
                    stmt.reset ();
                    return;
                }

                stmt.reset ();
            }

            string sql = """
                INSERT OR IGNORE INTO playlist_tracks (playlist_id, track_id, number) VALUES ($PLAYLIST, $TRACK, $NUM);
            """;

            foreach (var t in tracks_arr) {
                int res = db.prepare_v2 (sql, sql.length, out stmt);
                assert (res == Sqlite.OK);
                res = stmt.bind_int (stmt.bind_parameter_index ("$PLAYLIST"), playlist_id);
                assert (res == Sqlite.OK);
                res = stmt.bind_int (stmt.bind_parameter_index ("$TRACK"), (int) t);
                assert (res == Sqlite.OK);
                res = stmt.bind_int (stmt.bind_parameter_index ("$NUM"), nums);
                assert (res == Sqlite.OK);

                if (stmt.step () != Sqlite.DONE) {
                    warning ("Error: %d: %s", db.errcode (), db.errmsg ());
                } else {
                    nums++;
                }

                stmt.reset ();
            }
        }

        public void remove_from_playlist (int pid, uint tid) {
            Sqlite.Statement stmt;

            string sql = """
                DELETE FROM playlist_tracks WHERE playlist_id=$PID and track_id=$TID;
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$PID"), pid);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$TID"), (int) tid);
            assert (res == Sqlite.OK);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }

            stmt.reset ();
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
                return false;
            }

            stmt.reset ();
            return true;
        }

        public bool edit_playlist_name (int pid, string name) {
            Sqlite.Statement stmt;

            string sql = """
                UPDATE playlists SET title=$TITLE WHERE id=$ID;
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$ID"), pid);
            assert (res == Sqlite.OK);
            res = stmt.bind_text (stmt.bind_parameter_index ("$TITLE"), name);
            assert (res == Sqlite.OK);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
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
                return false;
            }

            stmt.reset ();
            return true;
        }

        public Gee.HashMap<int, string> get_artists () {
            var artists_hash = new Gee.HashMap<int, string> ();
            Sqlite.Statement stmt;
            string sql = """
                SELECT id, name FROM artists ORDER BY name;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);

            while (stmt.step () == Sqlite.ROW) {
                artists_hash[stmt.column_int (0)] = stmt.column_text (1);
            }

            stmt.reset ();
            return artists_hash;
        }

        public Gee.HashMap<uint, int> get_artists_hash () {
            var artists_hash = new Gee.HashMap<uint, int> ();
            Sqlite.Statement stmt;
            string sql = """
                SELECT id, name FROM artists;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);

            while (stmt.step () == Sqlite.ROW) {
                artists_hash[stmt.column_text (1).hash ()] = stmt.column_int (0);
            }

            stmt.reset ();
            return artists_hash;
        }

        public int insert_artist (string artist) {
            Sqlite.Statement stmt;
            string sql = """
                INSERT OR IGNORE INTO artists (name) VALUES ($NAME);
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_text (stmt.bind_parameter_index ("$NAME"), artist);
            assert (res == Sqlite.OK);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();

            sql = """
                SELECT id FROM artists WHERE name=$NAME;
            """;

            res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_text (stmt.bind_parameter_index ("$NAME"), artist);
            assert (res == Sqlite.OK);

            int artist_id = -1;
            if (stmt.step () == Sqlite.ROW) {
                artist_id = stmt.column_int (0);
            } else {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }

            stmt.reset ();
            return artist_id;
        }

        public Gee.HashMap<int, Gee.ArrayList<int>> get_artists_per_albums () {
            var return_hash = new Gee.HashMap<int, Gee.ArrayList<int>> ();
            Sqlite.Statement stmt;

            string sql = """
                SELECT album_id, artist_id FROM artperalb;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);

            while (stmt.step () == Sqlite.ROW) {
                var alb_id = stmt.column_int (0);
                if (return_hash.has_key (alb_id)) {
                    return_hash[alb_id].add (stmt.column_int (1));
                } else {
                    var new_array = new Gee.ArrayList<int> ();
                    new_array.add (stmt.column_int (1));
                    return_hash[alb_id] = new_array;
                }
            }

            stmt.reset ();
            return return_hash;
        }

        public void insert_artist_per_album (int artist_id, int album_id) {
            Sqlite.Statement stmt;

            string sql = """
                INSERT OR IGNORE INTO artperalb (artist_id, album_id) VALUES ($ARTIST_ID, $ALBUM_ID);
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$ALBUM_ID"), album_id);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$ARTIST_ID"), artist_id);
            assert (res == Sqlite.OK);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }

            stmt.reset ();
            return;
        }

        public Gee.ArrayList<Structs.Album?> get_albums () {
            var return_hash = new Gee.ArrayList<Structs.Album?> ();
            Sqlite.Statement stmt;

            string sql = """
                SELECT id, title, year, genre FROM albums ORDER BY title;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);

            while (stmt.step () == Sqlite.ROW) {
                Structs.Album album_struct = {};
                album_struct.album_id = stmt.column_int (0);
                album_struct.title = stmt.column_text (1);
                album_struct.year = (uint) stmt.column_int (2);
                album_struct.genre = stmt.column_text (3);

                return_hash.add (album_struct);
            }

            stmt.reset ();
            return return_hash;
        }

        public Gee.HashMap<uint, int> get_albums_hash () {
            var return_hash = new Gee.HashMap<uint, int>();
            Sqlite.Statement stmt;

            string sql = """
                SELECT id, title, year FROM albums;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);

            while (stmt.step () == Sqlite.ROW) {
                var hash_key = (stmt.column_int (2).to_string () + stmt.column_text (1)).hash ();
                return_hash[hash_key] = stmt.column_int (0);
            }

            stmt.reset ();
            return return_hash;
        }

        public int insert_album (CObjects.Media m) {
            Sqlite.Statement stmt;
            string sql = """
                INSERT OR IGNORE INTO albums (title, year, genre) VALUES ($TITLE, $YEAR, $GENRE);
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);

            res = stmt.bind_text (stmt.bind_parameter_index ("$TITLE"), m.album);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$YEAR"), (int) m.year);
            assert (res == Sqlite.OK);
            res = stmt.bind_text (stmt.bind_parameter_index ("$GENRE"), m.genre);
            assert (res == Sqlite.OK);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();

            sql = """
                SELECT id FROM albums WHERE year=$YEAR AND title=$TITLE;
            """;

            res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$YEAR"), (int) m.year);
            assert (res == Sqlite.OK);
            res = stmt.bind_text (stmt.bind_parameter_index ("$TITLE"), m.album);
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

        public CObjects.Media? get_track (string uri) {
            Sqlite.Statement stmt;

            string sql = """
                SELECT media.id, media.title, albums.genre, media.track, media.path, media.length, albums.title, albums.year, artists.name
                FROM media
                INNER JOIN albums
                ON media.album_id = albums.id
                INNER JOIN artists
                ON media.artist_id = artists.id
                WHERE media.path=$URI
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);

            res = stmt.bind_text (stmt.bind_parameter_index ("$URI"), uri);
            assert (res == Sqlite.OK);

            CObjects.Media? m = null;
            if (stmt.step () == Sqlite.ROW) {
                m = new CObjects.Media (stmt.column_text (4));
                m.tid = (uint) stmt.column_int64 (0);
                m.title = stmt.column_text (1);
                m.genre = stmt.column_text (2);
                m.track = (uint) stmt.column_int64 (3);
                m.length = (uint) stmt.column_int64 (5);
                m.album = stmt.column_text (6);
                m.year = (uint) stmt.column_int (7);
                m.artist = stmt.column_text (8);
            }

            stmt.reset ();
            return m;
        }

        public Gee.ArrayQueue<CObjects.Media> get_tracks (Enums.Category? category, string filter = "") {
            Sqlite.Statement stmt;

            string sql = """
                SELECT media.id, media.title, albums.genre, media.track, media.path, media.length, albums.title, albums.year, artists.name, media.hits
                FROM media
                INNER JOIN albums
                ON media.album_id = albums.id
                INNER JOIN artists
                ON media.artist_id = artists.id
            """;

            string param_name = "";
            if (category != null) {
                switch (category) {
                    case Enums.Category.GENRE:
                        sql += """WHERE albums.genre=$GENRE """;
                        param_name = "$GENRE";
                        break;
                    case Enums.Category.ALBUM:
                        sql += """WHERE media.album_id=$ALBUM """;
                        param_name = "$ALBUM";
                        break;
                    case Enums.Category.ARTIST:
                        sql += """WHERE media.artist_id=$ARTIST """;
                        param_name = "$ARTIST";
                        break;
                }
            }

            sql += """ORDER BY artists.name, albums.year, albums.title, media.track;""";

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);

            if (param_name != "" && filter != "") {
                if (category == Enums.Category.GENRE) {
                    res = stmt.bind_text (stmt.bind_parameter_index (param_name), filter);
                    assert (res == Sqlite.OK);
                } else {
                    res = stmt.bind_int (stmt.bind_parameter_index (param_name), int.parse (filter));
                    assert (res == Sqlite.OK);
                }
            }

            var tracks = fill_model (stmt);
            return tracks;
        }

        public CObjects.Media insert_track (CObjects.Media m, int album_id, int artist_id) {
            Sqlite.Statement stmt;
            string sql = """
                INSERT OR IGNORE INTO media (album_id, artist_id, title, track, path, length, last_access)
                VALUES ($ALBUM_ID, $ARTIST_ID, $TITLE, $TRACK, $URI, $LENGTH, $ACCESS_TIME);
            """;

            int res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);

            res = stmt.bind_int (stmt.bind_parameter_index ("$ALBUM_ID"), album_id);
            assert (res == Sqlite.OK);
            res = stmt.bind_int (stmt.bind_parameter_index ("$ARTIST_ID"), artist_id);
            assert (res == Sqlite.OK);
            res = stmt.bind_text (stmt.bind_parameter_index ("$TITLE"), m.title);
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
            }
            stmt.reset ();

            sql = """
                SELECT id FROM media WHERE path=$URI;
            """;

            res = db.prepare_v2 (sql, sql.length, out stmt);
            assert (res == Sqlite.OK);

            res = stmt.bind_text (stmt.bind_parameter_index ("$URI"), m.uri);
            assert (res == Sqlite.OK);

            if (stmt.step () == Sqlite.ROW) {
                m.tid = (uint) stmt.column_int64 (0);
            } else {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }

            stmt.reset ();
            return m;
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

        private Gee.ArrayQueue<CObjects.Media> fill_model (Sqlite.Statement stmt) {
            var tracks_queue = new Gee.ArrayQueue<CObjects.Media> ();

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

                tracks_queue.offer (m);
            }

            stmt.reset ();
            return tracks_queue;
        }
    }
}
