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
    public class Widgets.MusicStack : Interfaces.StackWrapper {
        public signal void filter_categories (Enums.Category c, int id);
        public signal void selected_album (int id);
        public signal void welcome_activate (int i);
        public signal GLib.File choose_album_cover (string title, Gtk.FileChooserAction a, Gtk.FileFilter f);

        public int paned_position {
            get {
                var w = get_child_by_name ("listview");
                return w != null ? ((Gtk.Paned) w).get_position () : 200;
            }
            set {
                var w = get_child_by_name ("listview");
                if (w != null) {
                    ((Gtk.Paned) w).set_position (value);
                }
            }
        }

        private Gee.HashMap<int, Views.ColumnBrowser> categories_hash;
        private Structs.Filter? current_filter = null;
        private Gee.ArrayQueue<uint> filter_tracks;

        private Granite.Widgets.AlertView alert_page;

        private LViews.GridView albums_view;
        private Views.AlbumView album_view;

        public Gee.HashMap<uint, Gtk.TreeIter?> media_iter_hash;

        private Gtk.TreeModelFilter? list_filter = null;

        public MusicStack (Enums.ViewMode v) {
            Object (transition_type: Gtk.StackTransitionType.OVER_DOWN,
                    hint: Enums.Hint.MUSIC,
                    view_name: v == Enums.ViewMode.COLUMN ? "listview" : "gridview");
        }

        construct {
            media_iter_hash = new Gee.HashMap<uint, Gtk.TreeIter?> ();
            filter_tracks = new Gee.ArrayQueue<uint> ();

            var welcome_screen = new Granite.Widgets.Welcome (_("Get Some Tunes"), _("Add music to your library."));
            welcome_screen.append ("document-import", _("Import Music"), _("Import music from a source into your library."));
            welcome_screen.append ("folder-music", _("Change Music Folder"), _("Load music from a folder, a network or an external disk."));
            welcome_screen.append ("media-playback-start", _("Scan Music Folder"), _("Add tracks from music folder to your library."));
            welcome_screen.activated.connect (on_welcome_activated);

            alert_page = new Granite.Widgets.AlertView (_("Music folder is being scanned"),
                                                        _("Need to wait a bit while your music collection is being scanned."),
                                                        "tools-timer");

            var browser_pane = new Gtk.Paned (Gtk.Orientation.VERTICAL) {
                expand = true
            };

            browser_pane.pack1 (init_categories (), false, false);
            browser_pane.pack2 (init_list_view (), true, false);

            list_store = new Gtk.ListStore.newv (Enums.ListColumn.get_all ());

            albums_view = new LViews.GridView ();
            albums_view.set_columns (-1);
            albums_view.selection_changed.connect (grid_selection_changed);

            var grid_scrolled = new Gtk.ScrolledWindow (null, null);
            grid_scrolled.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
            grid_scrolled.add (albums_view);

            album_view = new Views.AlbumView ();
            album_view.selected_row.connect ((row_id) => {
                selected_row (row_id, hint);
            });
            album_view.choose_cover.connect (on_choose_cover);

            var grid_pane = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
            grid_pane.pack1 (grid_scrolled, true, false);
            grid_pane.pack2 (album_view, false, false);

            add_named (welcome_screen, "welcome");
            add_named (alert_page, "alert");
            add_named (browser_pane, "listview");
            add_named (grid_pane, "gridview");

            show_welcome ();
        }

        private Gtk.Grid init_categories () {
            categories_hash = new Gee.HashMap<int, Views.ColumnBrowser> ();

            var columns_view = new Gtk.Grid ();
            foreach (unowned Enums.Category category in Enums.Category.get_all ()) {
                if (category != Enums.Category.N_CATEGORIES) {
                    var column = new Views.ColumnBrowser (category);
                    column.set_size_request (60, 100);
                    column.hexpand = column.vexpand = true;

                    column.select_row.connect (on_select_row);
                    // column.activated_row.connect (() => {
                    //
                    // });

                    categories_hash[category] = column;
                    columns_view.attach (column, (int) category, 0);
                }
            }

            return columns_view;
        }

        public void init_selections (uint tid) {
            categories_hash.foreach ((entry) => {
                entry.value.init_box ();
                return true;
            });

            // select_run_row (tid);
        }

        private void on_welcome_activated (int index) {
            welcome_activate (index);
        }

        private void on_select_row (Enums.Category c, string val, int id) {
            filter_tracks.clear ();
            current_filter = null;

            if (id > -1) {
                current_filter = {};
                current_filter.str = val;
                current_filter.id = id;

                if (c == Enums.Category.GENRE) {
                    current_filter.column = Enums.ListColumn.GENRE;
                } else if (c == Enums.Category.ARTIST) {
                    current_filter.column = Enums.ListColumn.ARTIST;
                } else if (c == Enums.Category.ALBUM) {
                    current_filter.column = Enums.ListColumn.ALBUM;
                }
            }

            if (c < Enums.Category.ALBUM) {
                filter_categories (c, id);
            }

            if (list_filter != null) {
                list_filter.refilter ();
            }
        }

        private void on_choose_cover () {
            var image_filter = new Gtk.FileFilter ();
            image_filter.set_filter_name (_("Image files"));
            image_filter.add_mime_type ("image/*");

            var f = choose_album_cover (_("Choose cover"), Gtk.FileChooserAction.OPEN, image_filter);
            if (f != null) {
                album_view.set_new_cover (f);
            }
        }

        public Gee.ArrayQueue<uint> get_filter_tracks () {
            if (get_visible_child_name () == "gridview") {
                return album_view.get_tracks ();
            }

            return filter_tracks;
        }

        protected override uint get_selected_tid (Gtk.TreePath filter_path) {
            if (list_filter != null) {
                Gtk.TreeIter filter_iter;
                if (list_filter.get_iter (out filter_iter, filter_path)) {
                    Gtk.TreeIter child_iter;
                    list_filter.convert_iter_to_child_iter (out child_iter, filter_iter);
                    uint tid;
                    list_store.@get (child_iter, Enums.ListColumn.TRACKID, out tid, -1);
                    return tid;
                }
            }

            return 0;
        }

        public new void select_run_row (uint tid) {
            if (media_iter_hash.has_key (tid)) {
                album_view.select_run_row (media_iter_hash[tid]);

                base.select_run_row (media_iter_hash[tid]);
            } else {
                Gtk.TreeIter first_iter;
                if (list_store.get_iter_first (out first_iter)) {
                    var first_path = list_store.get_path (first_iter);
                    if (first_path != null) {
                        list_view.set_cursor (first_path, null, false);
                    }
                }
            }
        }

        public new void remove_run_icon (uint tid) {
            if (media_iter_hash.has_key (tid)) {
                base.remove_run_icon (media_iter_hash[tid]);
            }

            album_view.unselect_rows ();
        }

        public new void scroll_to_current (uint tid) {
            if (media_iter_hash.has_key (tid)) {
                base.scroll_to_current (media_iter_hash[tid]);
            }
        }

        public void add_tracks (Gee.Collection<CObjects.Media> tracks) {
            tracks.foreach ((m) => {
                Gtk.TreeIter iter;
                list_store.insert_with_values (out iter, -1,
                    Enums.ListColumn.TRACKID, m.tid,
                    Enums.ListColumn.TRACK, m.track,
                    Enums.ListColumn.ALBUM, m.get_display_album (),
                    Enums.ListColumn.LENGTH, m.length,
                    Enums.ListColumn.YEAR, m.year,
                    Enums.ListColumn.GENRE, m.get_display_genre (),
                    Enums.ListColumn.TITLE, m.get_display_title (),
                    Enums.ListColumn.ARTIST, GLib.Markup.escape_text (m.get_display_artist ()), -1);

                media_iter_hash[m.tid] = iter;

                return true;
            });

            list_store.set_sort_column_id ((int) Enums.ListColumn.ARTIST, Gtk.SortType.ASCENDING);
            list_store.set_sort_func ((int) Enums.ListColumn.ARTIST, media_sort_func);

            list_filter = new Gtk.TreeModelFilter (list_store, null);
            list_filter.set_visible_func (row_visible_cb);
            list_view.set_model (list_filter);
        }

        public void add_album_grid (Gee.Collection<Structs.Album?> albums, Gee.HashMap<int, string> artists) {
            album_view.hide ();

            var albums_store = new Gtk.ListStore (2, typeof (Structs.Album), typeof (string));

            albums.foreach ((album) => {
                var custom_tooltip = artists.has_key (album.album_id) ? artists[album.album_id] : "";
                custom_tooltip += "\n<span size=\"large\">%u</span>".printf (album.year);

                Gtk.TreeIter grid_iter;
                albums_store.insert_with_values (out grid_iter, -1,
                                                 0, album,
                                                 1, custom_tooltip, -1);

                return true;
            });

            albums_store.set_sort_func (0, grid_sort_func);
            albums_store.set_sort_column_id (0, Gtk.SortType.ASCENDING);

            albums_view.set_model (albums_store);
        }

        public void add_album_tracks (Gee.ArrayQueue<CObjects.Media>? tracks) {
            var track_list = album_view.get_model ();
            if (track_list == null) {
                return;
            }

            Mutex mutex = Mutex ();
            mutex.lock ();
            var album_store = (Gtk.ListStore) track_list;
            tracks.foreach ((m) => {
                Gtk.TreeIter iter;
                album_store.insert_with_values (out iter, -1,
                    Enums.ListColumn.TRACKID, m.tid,
                    Enums.ListColumn.TITLE, m.get_display_title (),
                    Enums.ListColumn.LENGTH, m.length,
                    Enums.ListColumn.ARTIST, GLib.Markup.escape_text (m.get_display_artist ()), -1);

                return true;
            });
            mutex.unlock ();

            album_view.show_all ();
        }

        public void add_column_item (Enums.Category cat, Gtk.ListStore store) {
            if (categories_hash.has_key (cat)) {
                ((Objects.CategoryStore) store).add_sorting ();
                categories_hash[cat].set_model (store);
            }
        }

        public void filter_category (Enums.Category c, Gee.ArrayList<int> vals) {
            categories_hash[c].filter_list (vals);
        }

        public void show_view (Enums.ViewMode view_mode) {
            set_visible_child_name (view_mode == Enums.ViewMode.COLUMN ? "listview" : "gridview");
        }

        private void grid_selection_changed () {
            GLib.List<Gtk.TreePath> path = albums_view.get_selected_items ();
            var albums_store = albums_view.get_model ();
            if (path != null && albums_store != null) {
                Gtk.TreeIter selected_iter;
                if (albums_store.get_iter (out selected_iter, path.data)) {
                    unowned Structs.Album? struct_album;
                    albums_store.@get (selected_iter, 0, out struct_album, -1);

                    if (album_view.set_album (struct_album)) {
                        selected_album (struct_album.album_id);
                    }

                    return;
                }
            }

            album_view.hide ();
        }

        public override void clear_stack () {
            show_welcome ();

            list_view.set_model (null);
            list_filter = null;

            media_iter_hash.clear ();

            categories_hash.foreach ((entry) => {
                entry.value.clear_box ();
                return true;
            });

            album_view.clear ();
        }

        public bool row_visible_cb (Gtk.TreeModel m, Gtk.TreeIter iter) {
            if (current_filter == null || current_filter.str == "") {
                uint tid;
                m.@get (iter, Enums.ListColumn.TRACKID, out tid, -1);

                filter_tracks.offer (tid);

                return true;
            }

            string iter_value;
            uint tid;
            m.@get (iter, current_filter.column, out iter_value, Enums.ListColumn.TRACKID, out tid, -1);

            if (current_filter.str == iter_value) {
                // The check looks redundant, but for now I won’t delete it completely
                // if (!filter_tracks.contains (tid)) {
                    filter_tracks.offer (tid);
                // }

                return true;
            }

            return false;
        }

        public int media_sort_func (Gtk.TreeModel s, Gtk.TreeIter a, Gtk.TreeIter b) {
            var l_store = s as Gtk.ListStore;

            int sort_column_id;
            Gtk.SortType sort_direction;
            l_store.get_sort_column_id (out sort_column_id, out sort_direction);

            if (sort_column_id < 1) {return 0;}

            int rv = 0;
            rv = sort_column_id == Enums.ListColumn.ARTIST ? compare_artists (s, a, b) :
                 sort_column_id == Enums.ListColumn.ALBUM ? compare_albums (s, a, b) :
                 compare_column_values (s, a, b, (Enums.ListColumn) sort_column_id);

            if (sort_direction == Gtk.SortType.DESCENDING) {
                rv = (rv > 0) ? -1 : 1;
            }

            return rv;
        }

        private int grid_sort_func (Gtk.TreeModel s, Gtk.TreeIter a, Gtk.TreeIter b) {
            Structs.Album? struct_a;
            s.@get (a, 0, out struct_a, -1);
            Structs.Album? struct_b;
            s.@get (b, 0, out struct_b, -1);

            int rv = 0;
            if (struct_a != null && struct_b != null) {
                rv = Tools.String.compare (struct_a.title, struct_b.title);
            }

            return rv;
        }

        private int compare_artists (Gtk.TreeModel store, Gtk.TreeIter a, Gtk.TreeIter b) {
            string artist_name_a, artist_name_b;
            string album_name_a, album_name_b;
            uint album_year_a, album_year_b;
            uint track_number_a, track_number_b;

            store.@get (a,
                        Enums.ListColumn.ARTIST, out artist_name_a,
                        Enums.ListColumn.YEAR, out album_year_a,
                        Enums.ListColumn.ALBUM, out album_name_a,
                        Enums.ListColumn.TRACK, out track_number_a,
                        -1);

            store.@get (b,
                        Enums.ListColumn.ARTIST, out artist_name_b,
                        Enums.ListColumn.YEAR, out album_year_b,
                        Enums.ListColumn.ALBUM, out album_name_b,
                        Enums.ListColumn.TRACK, out track_number_b,
                        -1);

            int res = Tools.String.compare (artist_name_a, artist_name_b);
            if (res != 0) {
                return res;
            }

            if (album_year_a != album_year_b) {
                return album_year_a > album_year_b ? 1 : -1;
            }

            res = Tools.String.compare (album_name_a, album_name_b);
            if (res != 0) {return res;}

            if (track_number_a != track_number_b) {
                return track_number_a > track_number_b ? 1 : -1;
            }

            return res;
        }

        private int compare_albums (Gtk.TreeModel store, Gtk.TreeIter a, Gtk.TreeIter b) {
            string album_name_a, album_name_b;
            uint album_year_a, album_year_b;
            uint track_number_a, track_number_b;

            store.@get (a,
                        Enums.ListColumn.YEAR, out album_year_a,
                        Enums.ListColumn.ALBUM, out album_name_a,
                        Enums.ListColumn.TRACK, out track_number_a,
                        -1);

            store.@get (b,
                        Enums.ListColumn.YEAR, out album_year_b,
                        Enums.ListColumn.ALBUM, out album_name_b,
                        Enums.ListColumn.TRACK, out track_number_b,
                        -1);

            int res = Tools.String.compare (album_name_a, album_name_b);
            if (res != 0) {
                return res;
            }

            if (album_year_a != album_year_b) {
                return album_year_a > album_year_b ? 1 : -1;
            }

            if (track_number_a != track_number_b) {
                return track_number_a > track_number_b ? 1 : -1;
            }

            return res;
        }

        private int compare_column_values (Gtk.TreeModel store, Gtk.TreeIter a, Gtk.TreeIter b, Enums.ListColumn col_id) {
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
    }
}
