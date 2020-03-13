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
        public signal void filter_view (Enums.Category cat, int filter_id, Enums.ViewMode view_mode);

        private Widgets.ColumnsView columns_view;

        private LViews.GridView albums_view;
        private Views.AlbumView album_view;
        private Gtk.ListStore albums_store;

        public int active_album = -1;

        public MusicStack (Gtk.Window win, GLib.Settings settings_ui) {
            source_type = Enums.SourceType.LIBRARY;

            welcome_screen = new Granite.Widgets.Welcome (_("Get Some Tunes"), _("Add music to your library."));
            welcome_screen.append ("document-import", _("Import Music"), _("Import music from a source into your library."));
            welcome_screen.append ("folder-music", _("Change Music Folder"), _("Load music from a folder, a network or an external disk."));
            welcome_screen.activated.connect (on_welcome_activated);

            iter_hash = new Gee.HashMap<uint, Gtk.TreeIter?> ();

            columns_view = new Widgets.ColumnsView ();
            columns_view.filter_list.connect ((category, val) => {
                columns_view.clear_columns (category);
                list_store.clear ();
                iter_hash.clear ();
                filter_view (category, val, Enums.ViewMode.COLUMN);
            });

            var browser_pane = new Gtk.Paned (Gtk.Orientation.VERTICAL);
            browser_pane.expand = true;
            settings_ui.bind ("column-browser-height", browser_pane, "position", GLib.SettingsBindFlags.DEFAULT);

            browser_pane.pack1 (columns_view, false, false);
            browser_pane.pack2 (init_list_view (Enums.Hint.MUSIC), true, false);

            list_store.set_sort_column_id (Enums.ListColumn.ARTIST, Gtk.SortType.ASCENDING);
            list_store.set_sort_func (Enums.ListColumn.ARTIST, list_sort_func);

            albums_store = new Gtk.ListStore (2, typeof (Structs.Album), typeof (string));
            albums_store.set_sort_column_id (0, Gtk.SortType.ASCENDING);
            albums_store.set_sort_func (0, grid_sort_func);

            albums_view = new LViews.GridView ();
            albums_view.set_columns (-1);
            albums_view.set_model (albums_store);
            albums_view.selection_changed.connect (grid_selection_changed);

            var grid_scrolled = new Gtk.ScrolledWindow (null, null);
            grid_scrolled.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
            grid_scrolled.add (albums_view);

            album_view = new Views.AlbumView (win);
            album_view.selected_row.connect ((row_id) => {
                if (active_album > 0 && active_album == album_view.active_album_id) {
                    selected_row (row_id, Enums.SourceType.QUEUE);
                } else {
                    active_album = album_view.active_album_id;
                    selected_row (row_id, source_type);
                }
            });

            var grid_pane = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
            grid_pane.pack1 (grid_scrolled, true, false);
            grid_pane.pack2 (album_view, false, false);

            add_named (welcome_screen, "welcome");
            add_named (browser_pane, "listview");
            add_named (grid_pane, "gridview");
            show_welcome ();

            GLib.Idle.add (() => {
                grid_item_activated (null);
                return false;
            });
        }

        protected new void on_row_activated (Gtk.TreePath path, Gtk.TreeViewColumn column) {
            var filter = columns_view.get_filter ();
            active_album = -1;

            if (filter.field == Enums.Category.ALBUM) {
                if (filter.val > 0) {
                    active_album = filter.val;
                }
            }

            (this as Interfaces.StackWrapper).on_row_activated (path, column);
        }

        public new void select_run_row (uint? tid) {
            if (tid != null) {
                album_view.select_run_row (tid);

                (this as Interfaces.StackWrapper).select_run_row (tid);
            } else {
                //
            }
        }

        public new void remove_run_icon (uint tid) {
            (this as Interfaces.StackWrapper).remove_run_icon (tid);

            album_view.remove_run_icon (tid);
        }

        public void init_selections (Enums.Category? select_category) {
            columns_view.init_selections (select_category);
        }

        public void show_view (Enums.ViewMode view_mode) {
            set_visible_child_name (view_mode == Enums.ViewMode.COLUMN ? "listview" : "gridview");
        }

        public override void clear_stack () {
            show_welcome ();

            columns_view.clear_columns (null);
            list_store.clear ();
            iter_hash.clear ();
        }

        public Structs.Filter? get_filter (Enums.ViewMode view_mode) {
            if (view_mode == Enums.ViewMode.COLUMN) {
                return columns_view.get_filter ();
            } else if (view_mode == Enums.ViewMode.GRID) {
                GLib.List<Gtk.TreePath> path = albums_view.get_selected_items ();
                if (path != null) {
                    Gtk.TreeIter selected_iter;
                    if (albums_store.get_iter (out selected_iter, path.data)) {
                        Structs.Album? struct_album;
                        albums_store.@get (selected_iter, 0, out struct_album);

                        Structs.Filter f = {};
                        f.field = Enums.Category.ALBUM;
                        f.val = struct_album.album_id;

                        return f;
                    }
                }
            }

            return null;
        }

        public new bool add_iter (CObjects.Media m, Enums.ViewMode view_mode) {
            if (view_mode == Enums.ViewMode.COLUMN) {
                (this as Interfaces.StackWrapper).add_iter (m);
                return true;
            } else if (view_mode == Enums.ViewMode.GRID) {
                album_view.add_track (m);
                return true;
            }

            return false;
        }

        public void add_grid_item (Structs.Album a_iter) {
            string custom_tooltip = a_iter.artists;
            custom_tooltip += "\n<span size=\"large\">%u, %s</span>".printf (a_iter.year, Markup.escape_text (a_iter.genre));

            Gtk.TreeIter iter;
            albums_store.insert_with_values (out iter, -1,
                                             0, a_iter,
                                             1, custom_tooltip, -1);

        }

        public void add_column_item (Structs.Iter iter) {
            columns_view.add_column_item (iter);
        }

        private void on_welcome_activated (int index) {
            if (index == 0) {

            } else if (index == 1) {

            } else {

            }
        }

        private void grid_item_activated (Structs.Album? album_struct) {
            if (album_struct == null) {
                album_view.hide ();
                return;
            }

            if (album_view.active_album_id != album_struct.album_id) {
                album_view.set_album (album_struct);
                filter_view (Enums.Category.ALBUM, album_struct.album_id, Enums.ViewMode.GRID);
            }

            album_view.show_all ();
        }

        private void grid_selection_changed () {
            GLib.List<Gtk.TreePath> path = albums_view.get_selected_items ();
            if (path != null) {
                Gtk.TreeIter selected_iter;
                if (albums_store.get_iter (out selected_iter, path.data)) {
                    unowned Structs.Album? struct_album;
                    albums_store.@get (selected_iter, 0, out struct_album);
                    grid_item_activated (struct_album);

                    return;
                }
            }

            grid_item_activated (null);
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

        public int list_sort_func (Gtk.TreeModel store, Gtk.TreeIter a, Gtk.TreeIter b) {
            if (!(store as Gtk.ListStore).iter_is_valid (a) || !(store as Gtk.ListStore).iter_is_valid (b)) {
                return 0;
            }

            int sort_column_id;
            Gtk.SortType sort_direction;
            list_store.get_sort_column_id (out sort_column_id, out sort_direction);

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
    }
}
